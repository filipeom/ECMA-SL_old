open Bos
open Ecma_sl
open Syntax.Result
module Env = Symbolic.P.Env
module Value = Symbolic.P.Value
module Choice = Symbolic.P.Choice
module Thread = Choice_monad.Thread
module Translator = Value_translator
module Extern_func = Symbolic.P.Extern_func

let ext_esl = ".esl"
let ext_cesl = ".cesl"
let ext_js = ".js"

type options =
  { filename : Fpath.t
  ; entry_func : string
  ; workspace : Fpath.t
  }

let options filename entry_func workspace = { filename; entry_func; workspace }

let dispatch_file_ext on_plus on_core on_js (file : Fpath.t) =
  if Fpath.has_ext ext_esl file then on_plus file
  else if Fpath.has_ext ext_cesl file then on_core file
  else if Fpath.has_ext ext_js file then on_js file
  else Error (`Msg (Fmt.asprintf "%a :unreconized file type" Fpath.pp file))

let prog_of_plus file =
  let open Parsing_utils in
  let file = Fpath.to_string file in
  Ok
    ( load_file file
    |> parse_eprog ~file
    |> resolve_eprog_imports
    |> apply_eprog_macros
    |> Compiler.compile_prog )

let prog_of_core file =
  let file = Fpath.to_string file in
  Ok (Parsing_utils.load_file file |> Parsing_utils.parse_prog ~file)

let prog_of_js file =
  let js2ecma_sl file output =
    Cmd.(v "js2ecma-sl" % "-s" % "-c" % "-i" % p file % "-o" % p output)
  in
  let ast_file = Fpath.(file -+ "_ast.cesl") in
  let* () = OS.Cmd.run (js2ecma_sl file ast_file) in
  let* ast = OS.File.read ast_file in
  let* es6 = OS.File.read (Fpath.v (Option.get (Share.get_es6 ()))) in
  let program = String.concat ";\n" [ ast; es6 ] in
  let* () = OS.File.delete ast_file in
  Ok (Parsing_utils.parse_prog program)

let link_env ~extern prog =
  Env.Build.empty ()
  |> Env.Build.add_functions prog
  |> Env.Build.add_extern_functions extern

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
  let (next_int, _) = Utils.make_counter 0 1 in
  fun ?(witness :
         [> `Abort of string | `Assert_failure of Extern_func.value ] option )
    thread ->
    let pc = Thread.pc thread in
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
    let* () = OS.File.writef Fpath.(f + ".pc") "%a" Term.pp_list pc in
    let* () = OS.File.writef Fpath.(f + ".smtml") "%a" Term.pp_smt pc in
    match witness with
    | None -> Ok ()
    | Some witness ->
      OS.File.writef
        Fpath.(f + "_sink.json")
        "%a"
        (Yojson.pretty_print ~std:true)
        (err_to_json witness)

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
  let rpath = Fpath.(workspace / "report.json") in
  OS.File.writef rpath "%a" (Yojson.pretty_print ~std:true) json

let run ~workspace filename entry_func =
  let open Syntax.Result in
  let* prog = dispatch_file_ext prog_of_plus prog_of_core prog_of_js filename in
  let env = link_env ~extern:Symbolic_extern.api prog in
  let start = Stdlib.Sys.time () in
  let thread = Choice_monad.Thread.create () in
  let result = Symbolic_interpreter.main env entry_func in
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
        | Error (`Msg msg) -> Log.warn "%s" msg
        | Ok () -> () );
        Ok witness )
      results
  in
  Log.debug "  exec time : %fs@." exec_time;
  Log.debug "solver time : %fs@." solv_time;
  write_report ~workspace filename exec_time solv_time solv_cnt problems

let main (copts : Options.Common.t) opt =
  Options.Common.set copts;
  Ecma_sl.Config.Common.warns := true;
  match run ~workspace:opt.workspace opt.filename opt.entry_func with
  | Error (`Msg s) ->
    Log.warn "%s@." s;
    1
  | Ok () -> 0
