open Fmt

let make_log ?(header : bool = true) ?(font : Font.t list = [ Font.Normal ])
  (fdesc : Unix.file_descr) (fmt : ('a, t, unit, unit) format4) : 'a =
  let reset = [ Font.Normal ] in
  let pp_font = Font.pp_font_safe ~fdesc:(Some fdesc) in
  let hdr = if header then "[ecma-sl] " else "" in
  let print_f fmt = eprintf "%a%s%t%a@." pp_font font hdr fmt pp_font reset in
  kdprintf print_f fmt

let conditional_log test logger fmt =
  if test then logger fmt else ifprintf std_formatter fmt

let log ?(test = true) ?(header = true) ?(font = [ Font.Normal ]) fmt =
  conditional_log test (make_log ~header ~font Unix.stdout) fmt

let elog ?(test = true) ?(header = true) ?(font = [ Font.Normal ]) fmt =
  conditional_log test (make_log ~header ~font Unix.stderr) fmt

let app fmt = log ~header:false fmt
let debug fmt = elog ~test:!Config.Common.debugs ~font:[ Font.Cyan ] fmt
let warn fmt = elog ~test:!Config.Common.warns ~font:[ Font.Yellow ] fmt
let err fmt = kasprintf failwith fmt
