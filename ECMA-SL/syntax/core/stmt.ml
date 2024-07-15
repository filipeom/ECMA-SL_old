open EslBase
open Source

type t = t' Source.t

and t' =
  | Skip
  | Merge
  | Debug of t
  | Block of t list
  | Print of Expr.t
  | Return of Expr.t
  | Assign of Id.t * Expr.t
  | AssignCall of Id.t * Expr.t * Expr.t list
  | AssignECall of Id.t * Id.t * Expr.t list
  | AssignNewObj of Id.t
  | AssignObjToList of Id.t * Expr.t
  | AssignObjFields of Id.t * Expr.t
  | AssignInObjCheck of Id.t * Expr.t * Expr.t
  | FieldLookup of Id.t * Expr.t * Expr.t
  | FieldAssign of Expr.t * Expr.t * Expr.t
  | FieldDelete of Expr.t * Expr.t
  | If of Expr.t * t * t option
  | While of Expr.t * t
  | Switch of Expr.t * (Smtml.Value.t, t) Hashtbl.t * t option
  | Fail of Expr.t
  | Assert of Expr.t

let default () : t = Skip @> none

let rec pp (ppf : Fmt.t) (s : t) : unit =
  let open Fmt in
  let pp_return ppf e = if Expr.isvoid e then () else fmt ppf " %a" Expr.pp e in
  match s.it with
  | Skip -> fmt ppf "skip"
  | Merge -> fmt ppf "merge"
  | Debug s' -> fmt ppf "# %a" pp s'
  | Block ss ->
    fmt ppf "{@\n@[<v 2>  %a@]@\n}"
      (pp_print_list ~pp_sep:(fun ppf () -> fmt ppf ";@\n") pp)
      ss
  | Print e -> fmt ppf "print %a" Expr.pp e
  | Return e -> fmt ppf "return%a" pp_return e
  | Assign (x, e) -> fmt ppf "%a := %a" Id.pp x Expr.pp e
  | AssignCall (x, fe, es) ->
    fmt ppf "%a := %a(%a)" Id.pp x Expr.pp fe (pp_lst !>", " Expr.pp) es
  | AssignECall (x, fn, es) ->
    fmt ppf "%a := extern %a(%a)" Id.pp x Id.pp fn (pp_lst !>", " Expr.pp) es
  | AssignNewObj x -> fmt ppf "%a := {}" Id.pp x
  | AssignObjToList (x, e) -> fmt ppf "%a := obj_to_list %a" Id.pp x Expr.pp e
  | AssignObjFields (x, e) -> fmt ppf "%a := obj_fields %a" Id.pp x Expr.pp e
  | AssignInObjCheck (x, e1, e2) ->
    fmt ppf "%a := %a in_obj %a" Id.pp x Expr.pp e1 Expr.pp e2
  | FieldLookup (x, oe, fe) ->
    fmt ppf "%a := %a[%a]" Id.pp x Expr.pp oe Expr.pp fe
  | FieldAssign (oe, fe, e) ->
    fmt ppf "%a[%a] := %a" Expr.pp oe Expr.pp fe Expr.pp e
  | FieldDelete (oe, fe) -> fmt ppf "delete %a[%a]" Expr.pp oe Expr.pp fe
  | If (e, s1, s2) ->
    let pp_else ppf v = fmt ppf " else %a" pp v in
    fmt ppf "if (%a) %a%a" Expr.pp e pp s1 (pp_opt pp_else) s2
  | While (e, s') -> fmt ppf "while (%a) %a" Expr.pp e pp s'
  | Switch (e, css, dflt) ->
    let pp_case ppf (v, s) = fmt ppf "\ncase %a: %a" Value.pp v pp s in
    let pp_default ppf s = fmt ppf "\ndefault: %a" pp s in
    fmt ppf "switch (%a) {%a%a\n}" Expr.pp e (pp_hashtbl !>"" pp_case) css
      (pp_opt pp_default) dflt
  | Fail e -> fmt ppf "fail %a" Expr.pp e
  | Assert e -> fmt ppf "assert %a" Expr.pp e

let pp_simple (ppf : Fmt.t) (s : t) : unit =
  let open Fmt in
  match s.it with
  | Block _ -> fmt ppf "block { ... }"
  | If (e, _, _) -> fmt ppf "if (%a) { ..." Expr.pp e
  | While (e, _) -> fmt ppf "while (%a) { ..." Expr.pp e
  | _ -> pp ppf s

let str ?(simple : bool = false) (s : t) : string =
  Fmt.str "%a" (if simple then pp_simple else pp) s
