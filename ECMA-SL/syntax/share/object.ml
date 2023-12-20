type 'a t = (string, 'a) Hashtbl.t

let create () : 'a t = Hashtbl.create !Config.default_hashtbl_sz
let clone (obj : 'a t) = Hashtbl.copy obj

let fld_list (obj : 'a t) : (string * 'a) list =
  let _to_fld_lst_f fn fv acc = (fn, fv) :: acc in
  Hashtbl.fold _to_fld_lst_f obj []

let flds (obj : 'a t) : string list =
  let _fld_names_lst_f fn _ acc = fn :: acc in
  Hashtbl.fold _fld_names_lst_f obj []

let get (obj : 'a t) (fn : string) : 'a option = Hashtbl.find_opt obj fn
let set (obj : 'a t) (fn : string) (fv : 'a) : unit = Hashtbl.replace obj fn fv
let delete (obj : 'a t) (fn : string) : unit = Hashtbl.remove obj fn

let str (obj : 'a t) (printer : 'a -> string) : string =
  let _fld_str fn fv = Printf.sprintf "\"%s\": %s" fn (printer fv) in
  let _obj_str_f fn fv acc = _fld_str fn fv :: acc in
  let obj_str = Hashtbl.fold _obj_str_f obj [] |> String.concat ", " in
  "{ " ^ obj_str ^ " }"

let to_json (obj : 'a t) (printer : 'a -> string) : string =
  let _fld_str fn fv = Printf.sprintf "\"%s\": %s" fn (printer fv) in
  let _obj_str_f fn fv acc = _fld_str fn fv :: acc in
  let obj_str = Hashtbl.fold _obj_str_f obj [] |> String.concat ", " in
  "{ " ^ obj_str ^ " }"
