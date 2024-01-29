open Bos_setup
open Ecma_sl
open Syntax.Result
module Env = Symbolic.P.Env
module Value = Symbolic.P.Value
module Choice = Symbolic.P.Choice
module Thread = Choice_monad.Thread
module Translator = Value_translator
module Extern_func = Symbolic.P.Extern_func
module SMap = Stdlib.Map.Make (Stdlib.String)
module Optimizer = Choice_monad.Optimizer

let ( let/ ) = Choice.bind
let print_time = false
let print_pc = false

let list_iter ~f lst =
  let exception E of Rresult.R.msg in
  try
    List.iter
      (fun v -> match f v with Error s -> raise (E s) | Ok () -> ())
      lst;
    Ok ()
  with E s -> Error s

let fresh : string -> string =
  let counter = ref (-1) in
  fun x ->
    incr counter;
    Fmt.sprintf "%s_%d" x !counter

let symbolic_api_funcs =
  let open Value in
  let open Extern_func in
  let str_symbol (x : value) =
    Choice.return (Ok (Symbolic (Type.StrType, x)))
  in
  let int_symbol (x : value) = Choice.return (Ok (Value.int_symbol x)) in
  let flt_symbol (x : value) =
    Choice.return (Ok (Symbolic (Type.FltType, x)))
  in
  let bool_symbol (x : value) =
    Choice.return (Ok (Symbolic (Type.BoolType, x)))
  in
  let is_symbolic (n : value) =
    Choice.return (Ok (Val (Val.Bool (Value.is_symbolic n))))
  in
  let is_number (n : value) =
    let is_number =
      match Value_typing.type_of n with
      | Some Type.IntType | Some Type.FltType -> true
      | _ -> false
    in
    Choice.return (Ok (Val (Val.Bool is_number)))
  in
  let is_sat (e : value) =
    let/ b = Choice.check e in
    Choice.return (Ok (Val (Val.Bool b)))
  in
  let is_exec_sat (e : value) =
    (* TODO: more fine-grained exploit analysis *)
    let i = Value.int_symbol_s (fresh "i") in
    let len = Value.int_symbol_s (fresh "len") in
    let sub = TriOpt (Operator.StringSubstr, e, i, len) in
    let query = BinOpt (Operator.Eq, sub, Val (Val.Str "; touch success #")) in
    let/ b = Choice.check_add_true query in
    Choice.return (Ok (Val (Val.Bool b)))
  in
  let is_eval_sat (e : value) =
    (* TODO: more fine-grained exploit analysis *)
    let i = Value.int_symbol_s (fresh "i") in
    let len = Value.int_symbol_s (fresh "len") in
    let sub = TriOpt (Operator.StringSubstr, e, i, len) in
    let query =
      BinOpt (Operator.Eq, sub, Val (Val.Str ";console.log('success')//"))
    in
    let/ b = Choice.check_add_true query in
    Choice.return (Ok (Val (Val.Bool b)))
  in
  let abort (e : value) =
    let e' = Format.asprintf "%a" Value.Pp.pp e in
    Log.warn "      abort : %s@." e';
    Choice.return @@ Error (Format.asprintf {|{ "abort" : %S }|} e')
  in
  let assume (e : value) thread =
    let e' = Translator.translate e in
    [ (Ok (Val (Val.Symbol "undefined")), Thread.add_pc thread e') ]
  in
  let evaluate (e : value) thread =
    let e' = Translator.translate e in
    let pc = Thread.pc thread in
    let solver = Thread.solver thread in
    assert (Solver.check solver (e' :: pc));
    let v = Solver.get_value solver e' in
    [ (Ok (Translator.expr_of_value v.e), thread) ]
  in
  let optimize target opt e pc =
    Optimizer.push opt;
    Optimizer.add opt pc;
    let v = target opt e in
    Optimizer.pop opt;
    v
  in
  let maximize (e : value) thread =
    let e' = Translator.translate e in
    let pc = Thread.pc thread in
    let opt = Thread.optimizer thread in
    let v = optimize Optimizer.maximize opt e' pc in
    match v with
    | Some v -> [ (Ok (Translator.expr_of_value (Val v)), thread) ]
    | None ->
      (* TODO: Error here *)
      assert false
  in
  let minimize (e : value) thread =
    let e' = Translator.translate e in
    let pc = Thread.pc thread in
    let opt = Thread.optimizer thread in
    let v = optimize Optimizer.minimize opt e' pc in
    match v with
    | Some v -> [ (Ok (Translator.expr_of_value (Val v)), thread) ]
    | None ->
      (* TODO: Error here *)
      assert false
  in
  SMap.of_seq
    (Array.to_seq
       [| ("str_symbol", Extern_func (Func (Arg Res), str_symbol))
        ; ("int_symbol", Extern_func (Func (Arg Res), int_symbol))
        ; ("flt_symbol", Extern_func (Func (Arg Res), flt_symbol))
        ; ("bool_symbol", Extern_func (Func (Arg Res), bool_symbol))
        ; ("is_symbolic", Extern_func (Func (Arg Res), is_symbolic))
        ; ("is_number", Extern_func (Func (Arg Res), is_number))
        ; ("is_sat", Extern_func (Func (Arg Res), is_sat))
        ; ("is_exec_sat", Extern_func (Func (Arg Res), is_exec_sat))
        ; ("is_eval_sat", Extern_func (Func (Arg Res), is_eval_sat))
        ; ("abort", Extern_func (Func (Arg Res), abort))
        ; ("assume", Extern_func (Func (Arg Res), assume))
        ; ("evaluate", Extern_func (Func (Arg Res), evaluate))
        ; ("maximize", Extern_func (Func (Arg Res), maximize))
        ; ("minimize", Extern_func (Func (Arg Res), minimize))
       |] )

(* Examples *)
let extern_functions =
  let open Extern_func in
  let hello () =
    Fmt.printf "Hello world@.";
    Choice.return (Ok (Value.Val (Val.Symbol "undefined")))
  in
  let print (v : Value.value) =
    Fmt.printf "extern print: %a@." Value.Pp.pp v;
    Choice.return (Ok (Value.Val (Val.Symbol "undefined")))
  in
  SMap.of_seq
    (Array.to_seq
       [| ("hello", Extern_func (Func (UArg Res), hello))
        ; ("value", Extern_func (Func (Arg Res), print))
       |] )

let plus_ext = ".esl"
let core_ext = ".cesl"
let js_ext = ".js"

let dispatch_file_ext on_plus on_core on_js file =
  if Filename.check_suffix file plus_ext then Ok (on_plus file)
  else if Filename.check_suffix file core_ext then Ok (on_core file)
  else if Filename.check_suffix file js_ext then on_js file
  else Error (`Msg (file ^ " :unreconized file type"))

let prog_of_plus file =
  let open Parsing_utils in
  load_file file
  |> parse_eprog ~file
  |> resolve_eprog_imports
  |> apply_eprog_macros
  |> Compiler.compile_prog

let prog_of_core file =
  Parsing_utils.load_file file |> Parsing_utils.parse_prog ~file

let js2ecma_sl file output =
  Cmd.(v "js2ecma-sl" % "-c" % "-i" % p file % "-o" % p output)

let prog_of_js file =
  let* file = OS.File.must_exist (Fpath.v file) in
  let ast_file = Fpath.(file -+ "_ast.cesl") in
  let* () = OS.Cmd.run (js2ecma_sl file ast_file) in
  let ast_chan = open_in @@ Fpath.to_string ast_file in
  let interp_chan = open_in (Option.get (Share.get_es6 ())) in
  Fun.protect
    ~finally:(fun () ->
      close_in ast_chan;
      close_in interp_chan )
    (fun () ->
      let ast_str = In_channel.input_all ast_chan in
      let interp = In_channel.input_all interp_chan in
      let program = String.concat ~sep:";\n" [ ast_str; interp ] in
      let* () = OS.File.delete ast_file in
      Ok (Parsing_utils.parse_prog program) )

let link_env prog =
  Env.Build.empty ()
  |> Env.Build.add_functions prog
  |> Env.Build.add_extern_functions extern_functions
  |> Env.Build.add_extern_functions symbolic_api_funcs

let serialize =
  let counter = ref 0 in
  fun ?(witness : string option) thread ->
    let pc = Thread.pc thread in
    let solver = Thread.solver thread in
    assert (Solver.check solver pc);
    let model = Solver.model solver in
    let testcase =
      Option.fold model ~none:"" ~some:(fun m ->
          let open Encoding in
          Fmt.asprintf "module.exports.symbolic_map = @[<h 2>{%a@\n}@]"
            (Fmt.pp_print_list
               ~pp_sep:(fun fmt () -> Fmt.fprintf fmt "@\n")
               (fun fmt (s, v) ->
                 Fmt.fprintf fmt {|"%a" : %a|} Symbol.pp s Value.pp v ) )
            (Model.get_bindings m) )
    in
    let str_pc = Fmt.asprintf "%a" Encoding.Expr.pp_list pc in
    let smt_query = Fmt.asprintf "%a" Encoding.Expr.pp_smt pc in
    let prefix =
      incr counter;
      let fname = if Option.is_some witness then "witness" else "testecase" in
      let fname = Fmt.sprintf "%s-%i" fname !counter in
      Filename.concat (Filename.concat !Config.workspace "test-suite") fname
    in
    Io.write_file (Fmt.sprintf "%s.js" prefix) testcase;
    Io.write_file (Fmt.sprintf "%s.pc" prefix) str_pc;
    Io.write_file (Fmt.sprintf "%s.smt2" prefix) smt_query;
    Option.iter
      (fun sink -> Io.write_file (Fmt.sprintf "%s_sink.json" prefix) sink)
      witness

let run env entry_func =
  let testsuite_path = Filename.concat !Config.workspace "test-suite" in
  Io.safe_mkdir testsuite_path;
  let start = Stdlib.Sys.time () in
  let thread = Choice_monad.Thread.create () in
  let result = Symbolic_interpreter.main env entry_func in
  let results = Choice.run result thread in
  List.iter
    (fun (ret, thread) ->
      let witness = match ret with Ok _ -> None | Error err -> Some err in
      serialize ?witness thread;
      if print_pc then
        Fmt.printf "  path cond : %a@." Encoding.Expr.pp_list (Thread.pc thread)
      )
    results;
  if print_time then (
    Fmt.printf "  exec time : %fs@." (Stdlib.Sys.time () -. start);
    Fmt.printf "solver time : %fs@." !Solver.solver_time;
    Fmt.printf "  mean time : %fms@."
      (1000. *. !Solver.solver_time /. float !Solver.solver_count) )

let main (copts : Options.common_options) file target workspace =
  Log.on_debug := copts.debug;
  Config.workspace := workspace;
  (let* prog = dispatch_file_ext prog_of_plus prog_of_core prog_of_js file in
   let env = link_env prog in
   run env target;
   Ok 0 )
  |> Logs.on_error_msg ~use:(fun () -> 1)

let node test witness = Cmd.(v "node" % test % p witness)

type observable =
  | Stdout of string
  | File of string

let observable_effects = [ Stdout "success"; File "success" ]

let execute_witness env (test : string) (witness : Fpath.t) =
  let open OS in
  Logs.app (fun m -> m " running : %s" @@ Fpath.to_string witness);
  let cmd = node test witness in
  let* (out, status) = Cmd.(run_out ~env ~err:err_run_out cmd |> out_string) in
  match status with
  | (_, `Exited 0) ->
    Ok
      (List.find_opt
         (fun effect ->
           match effect with
           | Stdout sub -> String.find_sub ~sub out |> Option.is_some
           | File file -> Sys.file_exists file )
         observable_effects )
  | _ -> Error (`Msg (Fmt.sprintf "unexpected node failure: %s" out))

let validate (copts : Options.common_options) filename suite_path =
  if copts.debug then Logs.set_level (Some Logs.Debug);
  Logs.app (fun m -> m "validating : %s..." filename);
  let node_loc = List.nth Share.nodejs_location 0 in
  let node_path = Printf.sprintf ".:%s" node_loc in
  let env = String.Map.of_list [ ("NODE_PATH", node_path) ] in
  (let* witnesses = OS.Path.matches Fpath.(v suite_path / "witness-$(n).js") in
   let* () =
     list_iter witnesses ~f:(fun witness ->
         let* effect = execute_witness env filename witness in
         match effect with
         | Some (Stdout msg) ->
           Logs.app (fun m -> m " status : true (\"%s\" in output)" msg);
           Ok ()
         | Some (File file) ->
           let* () = OS.Path.delete @@ Fpath.v file in
           Logs.app (fun m -> m " status : true (created file \"%s\")" file);
           Ok ()
         | None ->
           Logs.app (fun m -> m " status : false (no side effect)");
           Ok () )
   in
   Ok 0 )
  |> Logs.on_error_msg ~use:(fun () -> 1)
