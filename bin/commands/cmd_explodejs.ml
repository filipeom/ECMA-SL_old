
let main () (opt : Cmd_symbolic.options) =
  let n = Cmd_symbolic.main () opt in
  if n <> 0 then n
  else
    let filename = opt.filename in
    let testsuite = Fpath.(opt.workspace / "test-suite") in
    Cmd_replay.main () { filename; testsuite }
