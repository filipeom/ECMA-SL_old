open Bos
open Ecma_sl
open Ecma_sl.Syntax.Result
module PC = Choice_monad.PC
module Env = Symbolic.P.Env
module Value = Symbolic.P.Value
module Choice = Symbolic.P.Choice
module Thread = Choice_monad.Thread
module Translator = Value_translator
module Extern_func = Symbolic.P.Extern_func

module Options = struct
  type t =
    { input : Fpath.t
    ; target : string
    ; workspace : Fpath.t
    }

  let set (input : Fpath.t) (target : string) (workspace : Fpath.t) : t =
    { input; target; workspace }
end

let prog_of_core (file : Fpath.t) : Prog.t =
  let file' = Fpath.to_string file in
  Parsing.load_file file' |> Parsing.parse_prog ~file:file'

let prog_of_plus (file : Fpath.t) : Prog.t = Cmd_compile.compile true file

let prog_of_js (file : Fpath.t) : Prog.t =
  let ast_file = Fpath.v (Filename.temp_file "ecmasl" "ast.cesl") in
  Cmd_encode.encode None file (Some ast_file);
  let ast_file' = Fpath.to_string ast_file in
  let ast = Parsing.load_file ast_file' |> Parsing.parse_func ~file:ast_file' in
  let interp = Share.es6_sym_interp () |> Parsing.parse_prog in
  Hashtbl.replace (Prog.funcs interp) (Func.name' ast) ast;
  interp

let dispatch_file_ext (file : Fpath.t) : (Prog.t, 'a) result =
  if Fpath.has_ext ".cesl" file then Ok (prog_of_core file)
  else if Fpath.has_ext ".esl" file then Ok (prog_of_plus file)
  else if Fpath.has_ext ".js" file then Ok (prog_of_js file)
  else Error (`Msg (Fmt.asprintf "%a :unreconized file type" Fpath.pp file))

let link_env (prog : Prog.t) : Extern_func.extern_func Symbolic.Env.t =
  let env = Env.Build.empty () |> Env.Build.add_functions prog in
  Env.Build.add_extern_functions (Symbolic_extern.extern_cmds env) env
  |> Env.Build.add_extern_functions Symbolic_extern.concrete_api
  |> Env.Build.add_extern_functions Symbolic_extern.symbolic_api

let pp_model fmt v =
  let open Encoding in
  let pp_mapping fmt (s, v) =
    Fmt.fprintf fmt {|"%a" : %a|} Symbol.pp s Value.pp v
  in
  let pp_vars fmt v =
    Fmt.pp_print_list
      ~pp_sep:(fun fmt () -> Fmt.fprintf fmt "@\n, ")
      pp_mapping fmt v
  in
  Fmt.fprintf fmt "@[<v 2>module.exports.symbolic_map =@ { %a@\n}@]" pp_vars
    (Model.get_bindings v)

let err_to_json = function
  | `Abort msg -> `Assoc [ ("type", `String "Abort"); ("sink", `String msg) ]
  | `Assert_failure v ->
    let v = Fmt.asprintf "%a" Value.pp v in
    `Assoc [ ("type", `String "Assert failure"); ("sink", `String v) ]
  | `Failure msg ->
    `Assoc [ ("type", `String "Failure"); ("sink", `String msg) ]

let serialize_thread ~workspace =
  let module Term = Encoding.Expr in
  let (next_int, _) = Base.make_counter 0 1 in
  fun ?(witness :
         [> `Abort of string | `Assert_failure of Extern_func.value ] option )
    thread ->
    let pc = PC.to_list @@ Thread.pc thread in
    Log.debug "  path cond : %a@." Encoding.Expr.pp_list pc;
    let solver = Thread.solver thread in
    assert (Solver.check solver pc);
    let m = Solver.model solver in
    let f =
      Fmt.ksprintf
        Fpath.(add_seg (workspace / "test-suite"))
        (match witness with None -> "testcase-%d" | Some _ -> "witness-%d")
        (next_int ())
    in
    let* () = OS.File.writef Fpath.(f + ".js") "%a" (Fmt.pp_opt pp_model) m in
    OS.File.writef Fpath.(f + ".smtml") "%a" Term.pp_smt pc

let write_report ~workspace filename exec_time solver_time solver_count problems
    =
  let json : Yojson.t =
    `Assoc
      [ ("filename", `String (Fpath.to_string filename))
      ; ("execution_time", `Float exec_time)
      ; ("solver_time", `Float solver_time)
      ; ("solver_queries", `Int solver_count)
      ; ("num_problems", `Int (List.length problems))
      ; ("problems", `List (List.map err_to_json problems))
      ]
  in
  let rpath = Fpath.(workspace / "symbolic-execution.json") in
  OS.File.writef rpath "%a" (Yojson.pretty_print ~std:true) json

let execute (target : string) (workspace : Fpath.t) (input : Fpath.t) =
  let* prog = dispatch_file_ext input in
  let env = link_env prog in
  let start = Stdlib.Sys.time () in
  let thread = Choice_monad.Thread.create () in
  let result = Symbolic_interpreter.main env target in
  let results = Choice.run result thread in
  let exec_time = Stdlib.Sys.time () -. start in
  let solv_time = !Solver.solver_time in
  let solv_cnt = !Solver.solver_count in
  let testsuite = Fpath.(workspace / "test-suite") in
  let* _ = OS.Dir.create ~path:true testsuite in
  let* problems =
    list_filter_map
      ~f:(fun (ret, thread) ->
        let* witness =
          match ret with
          | Ok _ -> Ok None
          | Error (`Abort _ as err) | Error (`Assert_failure _ as err) ->
            Ok (Some err)
          | Error (`Failure msg) -> Error (`Msg msg)
        in
        ( match serialize_thread ~workspace ?witness thread with
        | Error (`Msg msg) -> Log.out "%s@." msg
        | Ok () -> () );
        Ok witness )
      results
  in
  let n = List.length problems in
  if n = 0 then Log.out "All Ok!@." else Log.out "Found %d problems!@." n;
  Log.debug "  exec time : %fs@." exec_time;
  Log.debug "solver time : %fs@." solv_time;
  write_report ~workspace input exec_time solv_time solv_cnt problems

let run () (opts : Options.t) : unit =
  match execute opts.target opts.workspace opts.input with
  | Ok () -> ()
  | Error (`Msg s) ->
    Log.err "%s@." s;
    raise Exec.(Command_error Failure)
