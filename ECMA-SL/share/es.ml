let interpreters_location : string list = Es_site.Sites.interpreters
let nodejs_location : string list = Es_site.Sites.nodejs

let find file =
  List.find_map
    (fun dir ->
      let filename = Filename.concat dir file in
      if Sys.file_exists filename then Some filename else None )
    interpreters_location

let get_es6 () = find "es6.cesl"
let get_esl_symbolic () = find "esl_symbolic.js"
