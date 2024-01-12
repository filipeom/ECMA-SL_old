let on_debug = ref false

let debug fmt =
  if !on_debug then Fmt.eprintf fmt
  else Fmt.ifprintf Fmt.err_formatter fmt

let err fmt = Fmt.eprintf fmt
