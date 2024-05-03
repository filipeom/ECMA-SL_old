open Ecma_sl
open Syntax.Result

module Options = struct
  let langs : Enums.Lang.t list = Enums.Lang.[ Auto; ESL; CESL; CESLUnattached ]

  type tracer =
    { mode : Enums.InterpTracer.t
    ; loc : bool
    ; depth : int
    }

  type instrument =
    { tracer : tracer
    ; debugger : bool
    ; profiler : Enums.InterpProfiler.t
    }

  let set_instrument (tracer_mode : Enums.InterpTracer.t) (tracer_loc : bool)
    (tracer_depth : int) (debugger : bool) (profiler : Enums.InterpProfiler.t) :
    instrument =
    let (mode, loc, depth) = (tracer_mode, tracer_loc, tracer_depth) in
    { tracer = { mode; loc; depth }; debugger; profiler }

  type config =
    { print_depth : int option
    ; resolve_exitval : bool
    ; show_exitval : bool
    ; instrument : instrument
    }

  let default_config () : config =
    let tracer = { mode = None; loc = false; depth = 0 } in
    { print_depth = None
    ; resolve_exitval = true
    ; show_exitval = false
    ; instrument = { tracer; debugger = false; profiler = None }
    }

  let set_config (print_depth : int option) (show_exitval : bool)
    (instrument : instrument) : config =
    let resolve_exitval = true in
    { print_depth; resolve_exitval; show_exitval; instrument }

  type t =
    { input : Fpath.t
    ; lang : Enums.Lang.t
    ; main : string
    ; untyped : bool
    ; config : config
    }

  let set (input : Fpath.t) (lang : Enums.Lang.t) (main : string)
    (untyped : bool) (config : config) : t =
    { input; lang; main; untyped; config }
end

module InterpreterInstrument = struct
  let tracer ({ mode; loc; depth } : Options.tracer) : (module Tracer.M) =
    Tracer.Config.trace_loc := loc;
    Tracer.Config.trace_depth := if depth > 0 then Some depth else None;
    match mode with
    | None -> (module Tracer.Disable : Tracer.M)
    | Call -> (module Tracer.Call : Tracer.M)
    | Step -> (module Tracer.Step : Tracer.M)
    | Full -> (module Tracer.Full : Tracer.M)
    | Core -> (module Tracer.Core : Tracer.M)

  let debugger (debugger : bool) : (module Debugger.M) =
    match debugger with
    | true -> (module Debugger.Enable : Debugger.M)
    | false -> (module Debugger.Disable : Debugger.M)

  let profiler (profiler : Enums.InterpProfiler.t) : (module Profiler.M) =
    match profiler with
    | None -> (module Profiler.Disable : Profiler.M)
    | Time -> (module Profiler.Time : Profiler.M)
    | Full -> (module Profiler.Full : Profiler.M)

  let monitor () : (module Monitor.M) = (module Monitor.Default : Monitor.M)

  let intrument (instrument : Options.instrument) : (module Instrument.M) =
    let module Tracer = (val tracer instrument.tracer) in
    let module Debugger = (val debugger instrument.debugger) in
    let module Profiler = (val profiler instrument.profiler) in
    let module Monitor = (val monitor ()) in
    (module Instrument.Default (Tracer) (Debugger) (Profiler) (Monitor))
end

let interpret_partial (entry : Interpreter.EntryPoint.t)
  (config : Options.config) (prog : Prog.t) : Val.t * Val.t Heap.t =
  let instrument = config.instrument in
  let module Instrument = (val InterpreterInstrument.intrument instrument) in
  let module Interpreter = Interpreter.M (Instrument) in
  Interpreter.Config.print_depth := config.print_depth;
  Interpreter.Config.resolve_exitval := config.resolve_exitval;
  Interpreter.Config.show_exitval := config.show_exitval;
  Interpreter.eval_partial entry prog

let interpret (entry : Interpreter.EntryPoint.t) (config : Options.config)
  (prog : Prog.t) : Val.t Result.t =
  Result.esl_exec @@ fun () ->
  let (retval, _) = interpret_partial entry config prog in
  Log.debug "Sucessfuly evaluated program with return '%a'." Val.pp retval;
  Ok retval

let interpret_cesl (entry : Interpreter.EntryPoint.t) (config : Options.config)
  (file : Fpath.t) : Val.t Result.t =
  let* p = Cmd_compile.load file in
  interpret entry config p

let interpret_esl (entry : Interpreter.EntryPoint.t) (config : Options.config)
  (untyped : bool) (file : Fpath.t) : Val.t Result.t =
  let* p = Cmd_compile.compile untyped file in
  interpret entry config p

let run () (opts : Options.t) : unit Result.t =
  let valid_langs = Enums.Lang.valid_langs Options.langs opts.lang in
  let entry = { Interpreter.EntryPoint.default with main = opts.main } in
  Syntax.Result.map ignore
  @@
  match Enums.Lang.resolve_file_lang valid_langs opts.input with
  | Some ESL -> interpret_esl entry opts.config opts.untyped opts.input
  | Some CESL -> interpret_cesl entry opts.config opts.input
  | Some CESLUnattached | _ ->
    let config = { opts.config with resolve_exitval = false } in
    interpret_cesl entry config opts.input
