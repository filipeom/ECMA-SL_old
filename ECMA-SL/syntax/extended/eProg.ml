type t =
  { file : string
  ; imports : string list
  ; tdefs : (string, EType.t) Hashtbl.t
  ; funcs : (string, EFunc.t) Hashtbl.t
  ; macros : (string, EMacro.t) Hashtbl.t
  }

let default () : t =
  { file = ""
  ; imports = []
  ; tdefs = Hashtbl.create !Config.default_hashtbl_sz
  ; funcs = Hashtbl.create !Config.default_hashtbl_sz
  ; macros = Hashtbl.create !Config.default_hashtbl_sz
  }

module Parser = struct
  let parse_tdef ((tn, t) : string * EType.t) (p : t) : unit =
    match Hashtbl.find_opt p.tdefs tn with
    | None -> Hashtbl.replace p.tdefs tn t
    | Some _ -> failwith "TEMP: Replace by Eslerr.Compile.DuplicateTdef"

  let parse_func (f : EFunc.t) (p : t) : unit =
    match Hashtbl.find_opt p.funcs (EFunc.name f) with
    | None -> Hashtbl.replace p.funcs (EFunc.name f) f
    | Some _ -> failwith "TEMP: Replace by Eslerr.Compile.DuplicateFunc"

  let parse_macro (m : EMacro.t) (p : t) : unit =
    match Hashtbl.find_opt p.macros (EMacro.name m) with
    | None -> Hashtbl.replace p.macros (EMacro.name m) m
    | Some _ -> failwith "TEMP: Replace by Eslerr.Compile.DuplicateMacro"

  let parse_prog (imports : string list) (el_parsers : (t -> unit) list) : t =
    let p = { (default ()) with imports } in
    List.iter (fun el_parser -> el_parser p) el_parsers;
    p
end

let create (file : string) (imports : string list)
  (tdefs : (string * EType.t) list) (funcs : EFunc.t list)
  (macros : EMacro.t list) : t =
  let p = { (default ()) with file; imports } in
  List.iter (fun tdef -> Parser.parse_tdef tdef p) tdefs;
  List.iter (fun f -> Parser.parse_func f p) funcs;
  List.iter (fun m -> Parser.parse_macro m p) macros;
  p

let file (p : t) : string = p.file
let imports (p : t) : string list = p.imports
let tdefs (p : t) : (string, EType.t) Hashtbl.t = p.tdefs
let funcs (p : t) : (string, EFunc.t) Hashtbl.t = p.funcs
let macros (p : t) : (string, EMacro.t) Hashtbl.t = p.macros

let pp (fmt : Fmt.t) (p : t) : unit =
  let open Fmt in
  let pp_import fmt import = fprintf fmt "import %s\n" import in
  let pp_tdef fmt tn t = fprintf fmt "typedef %s := %a\n" tn EType.pp t in
  let pp_func fmt _ f = fprintf fmt "\n%a\n" EFunc.pp f in
  let pp_macro fmt _ m = fprintf fmt "\n%a\n" EMacro.pp m in
  fprintf fmt "%a\n%a%a%a" (pp_lst "" pp_import) p.imports
    (pp_hashtbl "" pp_tdef) p.tdefs (pp_hashtbl "" pp_func) p.funcs
    (pp_hashtbl "" pp_macro) p.macros

let str (p : t) : string = Fmt.asprintf "%a" pp p

let tdefs_lst (p : t) : (string * EType.t) list =
  Hashtbl.fold (fun tn t acc -> (tn, t) :: acc) p.tdefs []

let funcs_lst (p : t) : EFunc.t list =
  Hashtbl.fold (fun _ f acc -> f :: acc) p.funcs []

let macros_lst (p : t) : EMacro.t list =
  Hashtbl.fold (fun _ m acc -> m :: acc) p.macros []

(* FIXME: Requires cleaning below *)
let apply_macros (prog : t) : t =
  let new_funcs =
    Hashtbl.fold
      (fun _ f ac -> EFunc.apply_macros f (Hashtbl.find_opt prog.macros) :: ac)
      prog.funcs []
  in
  let tdefs = tdefs_lst prog in
  create prog.file prog.imports tdefs new_funcs []

let lambdas (p : t) : (string * string list * string list * EStmt.t) list =
  Hashtbl.fold (fun _ f ac -> EFunc.lambdas f @ ac) p.funcs []
