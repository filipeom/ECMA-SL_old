open EslBase
include Smtml.Value

let void : t = Unit
let null : t = Nothing
let undefined : t = App (`Op "symbol", [ Str "undefined" ])
let loc (l : Loc.t) : t = App (`Op "loc", [ Int l ]) [@@inline]
let symbol (s : string) : t = App (`Op "symbol", [ Str s ]) [@@inline]

let is_special_number (s : string) : bool =
  List.mem s [ "nan"; "inf"; "-inf" ]
  || String.contains s 'e'
  || String.contains s 'E'

let float_str (f : float) : string =
  let f_str = Fmt.str "%.17g" f in
  if is_special_number f_str || String.contains f_str '.' then f_str
  else f_str ^ ".0"

let pp_custom_val (pp_v : Fmt.t -> t -> unit) (ppf : Fmt.t) (v : t) : unit =
  match v with
  | Unit -> ()
  | Nothing -> Fmt.fmt ppf "null"
  | Int i -> Fmt.fmt ppf "%i" i
  | Real f -> Fmt.fmt ppf "%s" (float_str f)
  | Str s -> Fmt.fmt ppf "%S" s
  | True -> Fmt.fmt ppf "true"
  | False -> Fmt.fmt ppf "false"
  | List lst -> Fmt.(fmt ppf "[%a]" (pp_lst !>", " pp_v) lst)
  | App (`Op "loc", [ Int loc ]) -> Loc.pp ppf loc
  | App (`Op "symbol", [ Str s ]) -> Fmt.fmt ppf "'%s" s
  | App (`Op fn, fvs) -> Fmt.(fmt ppf "{%S}@(%a)" fn (pp_lst !>", " pp_v) fvs)
  | _ -> Log.fail "Val.pp_custom_val: unexpected value '%a'" pp v

let rec pp (ppf : Fmt.t) (v : t) : unit = pp_custom_val pp ppf v
let str (v : t) : string = Fmt.str "%a" pp v [@@inline]
