open Ecma_sl

type options =
  { input : string
  ; output : string option
  ; untyped : bool
  }

let run_type_checker (prog : EProg.t) : EProg.t =
  if !Config.Tesl.untyped || true then prog
  else
    let terrs = T_Checker.type_program prog in
    if terrs = [] then prog
    else (
      Format.eprintf "%s" (T_Checker.terrs_str terrs);
      raise (Cmd.Command_error Cmd.Error) )

let run_compiler (file : string) : Prog.t =
  Parsing_utils.load_file file
  |> Parsing_utils.parse_eprog ~file
  |> Parsing_utils.resolve_eprog_imports
  |> Parsing_utils.apply_eprog_macros
  |> run_type_checker
  |> Compiler.compile_prog

let run (opts : options) : unit =
  ignore (Cmd.test_file_ext [ Enums.Lang.ESL ] opts.input);
  let prog = run_compiler opts.input in
  match opts.output with
  | None -> print_endline (Prog.str prog)
  | Some output_file' -> Io.write_file output_file' (Prog.str prog)

let main (copts : Options.Common.t) (opts : options) : int =
  Options.Common.set copts;
  Config.Tesl.untyped := opts.untyped;
  Cmd.eval_cmd (fun () -> run opts)
