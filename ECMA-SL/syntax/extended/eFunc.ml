open Source

type t = t' Source.phrase

and t' =
  { name : Id.t
  ; tparams : (Id.t * EType.t option) list
  ; treturn : EType.t option
  ; body : EStmt.t
  ; metadata : EFunc_metadata.t option
  }

let default () : t =
  { name = Id.default ()
  ; tparams = []
  ; treturn = None
  ; body = EStmt.default ()
  ; metadata = None
  }
  @> no_region

let create (name : Id.t) (tparams : (Id.t * EType.t option) list)
  (treturn : EType.t option) (body : EStmt.t)
  (metadata : EFunc_metadata.t option) : t' =
  { name; tparams; treturn; body; metadata }

let name (m : t) : Id.t = m.it.name
let name' (m : t) : string = m.it.name.it
let tparams (f : t) : (Id.t * EType.t option) list = f.it.tparams
let params (f : t) : Id.t list = List.map (fun (param, _) -> param) f.it.tparams

let params' (m : t) : string list =
  List.map (fun (param, _) -> param.it) m.it.tparams

let treturn (f : t) : EType.t option = f.it.treturn
let body (f : t) : EStmt.t = f.it.body
let metadata (f : t) : EFunc_metadata.t option = f.it.metadata

let pp_signature (fmt : Fmt.t) (f : t) : unit =
  let open Fmt in
  let open EType in
  let { name; tparams; treturn; _ } = f.it in
  let pp_param fmt (param, t) = fprintf fmt "%a%a" Id.pp param pp_tannot t in
  fprintf fmt "function %a(%a)%a" Id.pp name (pp_lst ", " pp_param) tparams
    pp_tannot treturn

let pp (fmt : Fmt.t) (f : t) : unit =
  Fmt.fprintf fmt "%a %a" pp_signature f EStmt.pp f.it.body

let pp_simple (fmt : Fmt.t) (f : t) : unit =
  Fmt.fprintf fmt "%a {..." pp_signature f

let str ?(simple : bool = false) (f : t) : string =
  if simple then Fmt.asprintf "%a" pp_simple f else Fmt.asprintf "%a" pp f

let apply_macros (find_macro_f : string -> EMacro.t option) (f : t) : t =
  let body = EStmt.map (EMacro.mapper find_macro_f) f.it.body in
  { f with it = { f.it with body } }

(* FIXME: Requires cleaning below *)
let lambdas (f : t) : (string * Id.t list * Id.t list * EStmt.t) list =
  EStmt.lambdas f.it.body
