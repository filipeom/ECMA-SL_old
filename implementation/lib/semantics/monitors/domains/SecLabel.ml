exception Except of string

type t =
  | AssignLab of (string * Expr.t)
  | EmptyLab
  | BranchLab of (Expr.t * Stmt.t)
  | MergeLab
  | AssignCallLab of ((Expr.t list)* string * string)
  | ReturnLab of Expr.t
  | FieldAssignLab of (Loc.t * Field.t * Expr.t * Expr.t * Expr.t)
  | FieldLookupLab of (string * Loc.t * Field.t * Expr.t * Expr.t)
  | FieldDeleteLab of (Loc.t * Field.t * Expr.t * Expr.t)
  (* Direct Security Level Upgrades *)
  | UpgVarLab of (string * SecLevel.t)
  | UpgPropExistsLab of (Loc.t * string * Expr.t * Expr.t * SecLevel.t)
  | UpgPropValLab of (Loc.t * string * Expr.t * Expr.t * SecLevel.t)
  | UpgStructExistsLab of (Loc.t * Expr.t * SecLevel.t)
  | UpgStructValLab of (Loc.t * Expr.t * SecLevel.t)



let str (label :t) : string =
  match label with
  | EmptyLab ->
    "EmptyLab"
  | MergeLab ->
    "MergeLab"
  | ReturnLab e ->
    "RetLab ("^ (Expr.str e)^ ")"
  | AssignLab (st,exp) ->
    "AsgnLab ("^ (Expr.str exp) ^", "^st ^")"
  | BranchLab (exp, stmt) ->
    "BranchLab (" ^(Expr.str exp) ^"),{ "^(Stmt.str stmt)^"}"
  | AssignCallLab (exp,x,f) ->
    "AssignCallLab ("^(String.concat "; " (List.map Expr.str exp))^", "^ x^")"
  | UpgVarLab (x, lvl) ->
    "UpgVarLab"
  | UpgPropValLab (loc, x, e_o, e_f, lvl) ->
    "UpgPropLab"
  | UpgStructValLab (loc, e_o, lvl) ->
    "UpgStructLab"
  | UpgStructExistsLab (loc, e_o, lvl) ->
    "UpgStructLab"
  | _ ->
    "Missing str"



let interceptor (func : string) (vs : Val.t list) (es : Expr.t list) : t option =
  match (func, vs, es) with
  | ("upgVar",[Val.Str x; Val.Str lev_str], [Expr.Val (Str x'); Expr.Val (Str lev_str')])
    when x = x' && lev_str = lev_str' ->  Some (UpgVarLab (x,SecLevel.parse_lvl lev_str))

  | ("upgPropExists",[Val.Loc loc; Val.Str x; Val.Str lev_str], [e_o; e_f; Expr.Val (Str lev_str')])
    when lev_str = lev_str' -> Some (UpgPropExistsLab (loc,x, e_o, e_f,(SecLevel.parse_lvl lev_str)))
  | ("upgPropExists",[Val.Loc loc; Val.Str x; Val.Str lev_str], [e_o; e_f; _])-> raise (Except "Level is not a literal ") (*Gerar uma exception*)

  | ("upgPropVal", [Val.Loc loc; Val.Str x;  Val.Str lev_str], [e_o; e_f; Expr.Val (Str lev_str')])
    when lev_str = lev_str'-> Some (UpgPropValLab (loc,x,  e_o, e_f, (SecLevel.parse_lvl lev_str)))
  | ("upgPropVal", [Val.Loc loc; Val.Str x;  Val.Str lev_str], [e_o; e_f; _])-> raise (Except "Level is not a literal ")

  | ("upgStructExists",[Val.Loc loc; Val.Str lev_str], [e_o; Expr.Val (Str lev_str')])
    when lev_str = lev_str' -> Some (UpgStructExistsLab (loc, e_o, (SecLevel.parse_lvl lev_str)))
  | ("upgStructExists",[Val.Loc loc; Val.Str lev_str], [e_o; _])-> raise (Except "Level is not a literal ")

  | ("upgStructVal",[Val.Loc loc; Val.Str lev_str], [e_o; Expr.Val (Str lev_str')])
    when lev_str = lev_str' -> Some (UpgStructValLab (loc, e_o, (SecLevel.parse_lvl lev_str)))
  | ("upgStructVal",[Val.Loc loc; Val.Str lev_str], [e_o; _])-> raise (Except "Level is not a literal ")

  | _ -> None

(*Ver tese andre para checkar todas a labels*)
