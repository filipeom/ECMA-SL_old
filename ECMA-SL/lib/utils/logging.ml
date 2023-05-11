open Core

let print_endline (s : string lazy_t) : unit =
  if !Config.verbose then printf "[verb] %s\n" (Lazy.force s)

let set_silent () : unit = Config.verbose := false
let set_verbose () : unit = Config.verbose := true
