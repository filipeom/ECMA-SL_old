module Config = struct
  let log_warns : bool ref = ref true
  let log_debugs : bool ref = ref false
  let out_ppf : Fmt.t ref = ref Fmt.std_formatter
  let err_ppf : Fmt.t ref = ref Fmt.err_formatter
end

let stdout (fmt : ('a, Format.formatter, unit, unit) format4) =
  Fmt.(kdprintf (format !Config.out_ppf "%t") fmt)
[@@inline]

let stderr (fmt : ('a, Format.formatter, unit, unit) format4) =
  Fmt.(kdprintf (format !Config.err_ppf "%t") fmt)
[@@inline]

let fail (fmt : ('a, Format.formatter, unit, 'b) format4) : 'a =
  Fmt.kasprintf failwith fmt
[@@inline]

module EslLog = struct
  let mk ?(font : Font.t = [ Font.Normal ]) (ppf : Fmt.t)
    (fmt : ('a, Fmt.t, unit, unit) format4) : 'a =
    let pp_text ppf fmt = Fmt.format ppf "[ecma-sl] %t" fmt in
    let pp_log fmt = Fmt.format ppf "%a@." (Font.pp font pp_text) fmt in
    Fmt.(kdprintf pp_log fmt)

  let test (test : bool) ?(font : Font.t option) (ppf : Fmt.t)
    (fmt : ('a, Fmt.t, unit) format) =
    if test then (mk ?font ppf) fmt else Fmt.ifprintf ppf fmt
end

let esl (fmt : ('a, Fmt.t, unit, unit) format4) : 'a =
  EslLog.mk !Config.out_ppf fmt
[@@inline]

let error (fmt : ('a, Fmt.t, unit, unit) format4) : 'a =
  EslLog.mk ~font:[ Red ] !Config.err_ppf fmt
[@@inline]

let warn (fmt : ('a, Format.formatter, unit) format) : 'a =
  EslLog.test !Config.log_warns ~font:[ Yellow ] !Config.err_ppf fmt
[@@inline]

let debug (fmt : ('a, Format.formatter, unit) format) : 'a =
  EslLog.test !Config.log_debugs ~font:[ Cyan ] !Config.err_ppf fmt
[@@inline]

module Redirect = struct
  type mode =
    | Out
    | Err
    | All
    | Shared

  type t =
    { old_out : Fmt.t
    ; old_err : Fmt.t
    ; new_out : Buffer.t option
    ; new_err : Buffer.t option
    }

  let capture (log_ppf : Fmt.t ref) (new_ppf : Buffer.t) : Buffer.t =
    log_ppf := Fmt.formatter_of_buffer new_ppf;
    new_ppf

  let capture_to ~(out : Buffer.t option) ~(err : Buffer.t option) : t =
    let (old_out, old_err) = (!Config.out_ppf, !Config.err_ppf) in
    let new_out = Option.map (capture Config.out_ppf) out in
    let new_err = Option.map (capture Config.err_ppf) err in
    { old_out; old_err; new_out; new_err }

  let capture (mode : mode) : t =
    let buffer () = Some (Buffer.create 1024) in
    match mode with
    | Out -> capture_to ~out:(buffer ()) ~err:None
    | Err -> capture_to ~err:(buffer ()) ~out:None
    | All -> capture_to ~out:(buffer ()) ~err:(buffer ())
    | Shared ->
      let streams = capture_to ~out:(buffer ()) ~err:None in
      let old_err = !Config.err_ppf in
      Config.err_ppf := !Config.out_ppf;
      { streams with old_err; new_err = None }

  let pp_captured (ppf : Fmt.t) (streams : t) : unit =
    let log ppf buf = Fmt.pp_str ppf (Buffer.contents buf) in
    Option.fold ~none:() ~some:(log ppf) streams.new_out;
    Option.fold ~none:() ~some:(log ppf) streams.new_err

  let restore ?(log : bool = false) (streams : t) : unit =
    let log ppf buf = if log then Fmt.format ppf "%s@?" (Buffer.contents buf) in
    Config.out_ppf := streams.old_out;
    Config.err_ppf := streams.old_err;
    Option.fold ~none:() ~some:(log !Config.out_ppf) streams.new_out;
    Option.fold ~none:() ~some:(log !Config.err_ppf) streams.new_err
end
