open Source

type t =
  { file : string
  ; imports : Id.t list
  ; tdefs : (Id.t', EType.tdef) Hashtbl.t
  ; funcs : (Id.t', EFunc.t) Hashtbl.t
  ; macros : (Id.t', EMacro.t) Hashtbl.t
  }

let default () : t =
  { file = ""
  ; imports = []
  ; tdefs = Hashtbl.create !Config.default_hashtbl_sz
  ; funcs = Hashtbl.create !Config.default_hashtbl_sz
  ; macros = Hashtbl.create !Config.default_hashtbl_sz
  }

let create (file : string) (imports : Id.t list)
  (tdefs : (Id.t', EType.tdef) Hashtbl.t) (funcs : (Id.t', EFunc.t) Hashtbl.t)
  (macros : (Id.t', EMacro.t) Hashtbl.t) : t =
  { file; imports; tdefs; funcs; macros }

let file (p : t) : string = p.file
let imports (p : t) : Id.t list = p.imports
let tdefs (p : t) : (Id.t', EType.tdef) Hashtbl.t = p.tdefs
let funcs (p : t) : (Id.t', EFunc.t) Hashtbl.t = p.funcs
let macros (p : t) : (Id.t', EMacro.t) Hashtbl.t = p.macros

let pp (fmt : Fmt.t) (p : t) : unit =
  let open Fmt in
  let pp_import fmt import = fprintf fmt "import %a\n" Id.pp import in
  let pp_tdef fmt (_, t) = fprintf fmt "%a\n" EType.tdef_pp t in
  let pp_func fmt (_, f) = fprintf fmt "\n%a" EFunc.pp f in
  let pp_macro fmt (_, m) = fprintf fmt "\n%a" EMacro.pp m in
  fprintf fmt "%a\n%a%a%a" (pp_lst "" pp_import) p.imports
    (pp_hashtbl "" pp_tdef) p.tdefs (pp_hashtbl "\n" pp_func) p.funcs
    (pp_hashtbl "\n" pp_macro) p.macros

let str (p : t) : string = Fmt.asprintf "%a" pp p

let lambdas (p : t) : (region * string * Id.t list * Id.t list * EStmt.t) list =
  Hashtbl.fold (fun _ f acc -> EFunc.lambdas f @ acc) p.funcs []
