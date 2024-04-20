open Cmdliner

let doc = "Performs symbolic analysis on an ECMA-SL program"
let sdocs = Manpage.s_common_options

let description =
  "Given an JavaScript (.js), ECMA-SL (.esl), or Core ECMA-SL (.cesl) file, \
   runs the program using the ECMA-SL symbolic engine."

let man = [ `S Manpage.s_description; `P description ]
let man_xrefs = []

let options =
  Term.(
    const Cmd_symbolic.options
    $ Options.File.input
    $ Options.target_func
    $ Options.workspace_dir )

let term = Term.(const Cmd_symbolic.main $ options $ Options.Common.options)
