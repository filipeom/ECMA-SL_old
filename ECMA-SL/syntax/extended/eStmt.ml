open EslBase
open Source

type t = t' Source.phrase

and t' =
  | Skip
  | Debug of t
  | Block of t list
  | ExprStmt of EExpr.t
  | Print of EExpr.t
  | Return of EExpr.t
  | Assign of Id.t * EType.t option * EExpr.t
  | GAssign of Id.t * EExpr.t
  | FieldAssign of EExpr.t * EExpr.t * EExpr.t
  | FieldDelete of EExpr.t * EExpr.t
  | If of (EExpr.t * t * region) list * t option
  | While of EExpr.t * t
  | ForEach of Id.t * EExpr.t * t
  | RepeatUntil of t * (EExpr.t * region) option
  | Switch of EExpr.t * (EExpr.t * t) list * t option
  | MatchWith of EExpr.t * Id.t option * (EPat.t * t) list
  | Lambda of Id.t * string * Id.t list * Id.t list * t
  | MacroApply of Id.t * EExpr.t list
  | Throw of EExpr.t
  | Fail of EExpr.t
  | Assert of EExpr.t

let default () : t = Skip @> no_region

let rec pp (ppf : Fmt.t) (s : t) : unit =
  let open Fmt in
  let pp_return ppf e =
    if EExpr.isvoid e then () else format ppf " %a" EExpr.pp e
  in
  match s.it with
  | Skip -> format ppf "skip"
  | Debug s' -> format ppf "# %a" pp s'
  | Block ss -> format ppf "{\n%a\n}" (pp_lst !>";\n" pp) ss
  | ExprStmt e -> EExpr.pp ppf e
  | Print e -> format ppf "print %a" EExpr.pp e
  | Return e -> format ppf "return%a" pp_return e
  | Assign (x, tx, e) ->
    format ppf "%a%a := %a" Id.pp x EType.tannot_pp tx EExpr.pp e
  | GAssign (x, e) -> format ppf "|%a| := %a" Id.pp x EExpr.pp e
  | FieldAssign (oe, fe, e) ->
    format ppf "%a[%a] := %a" EExpr.pp oe EExpr.pp fe EExpr.pp e
  | FieldDelete (oe, fe) -> format ppf "delete %a[%a]" EExpr.pp oe EExpr.pp fe
  | If ([], _) -> Log.fail "expecting non-empty if cases"
  | If (ifcs :: elifcss, elsecs) ->
    let pp_case ppf (e, s) = format ppf "(%a) %a" EExpr.pp e pp s in
    let pp_if ppf (e, s, _) = format ppf "if %a" pp_case (e, s) in
    let pp_elif ppf (e, s, _) = format ppf " elif %a" pp_case (e, s) in
    let pp_else ppf s = format ppf " else %a" pp s in
    format ppf "%a%a%a" pp_if ifcs (pp_lst !>"" pp_elif) elifcss
      (pp_opt pp_else) elsecs
  | While (e, s') -> format ppf "while (%a) %a" EExpr.pp e pp s'
  | ForEach (x, e, s') ->
    format ppf "foreach (%a : %a) %a" Id.pp x EExpr.pp e pp s'
  | RepeatUntil (s', until) ->
    let pp_until ppf (e, _) = format ppf " until %a" EExpr.pp e in
    format ppf "repeat %a%a" pp s' (pp_opt pp_until) until
  | Switch (e, css, dflt) ->
    let pp_case ppf (e, s) = format ppf "\ncase %a: %a" EExpr.pp e pp s in
    let pp_default ppf s = format ppf "\nsdefault: %a" pp s in
    format ppf "switch (%a) {%a%a\n}" EExpr.pp e (pp_lst !>"" pp_case) css
      (pp_opt pp_default) dflt
  | MatchWith (e, dsc, css) ->
    let pp_discrim ppf dsc = format ppf ": %a" Id.pp dsc in
    let pp_case ppf (pat, s) = format ppf "\n| %a -> %a" EPat.pp pat pp s in
    format ppf "match %a%a with %a" EExpr.pp e (pp_opt pp_discrim) dsc
      (pp_lst !>"" pp_case) css
  | Lambda (x, _, pxs, ctxvars, s') ->
    format ppf "%a := lambda (%a) [%a] %a" Id.pp x (pp_lst !>", " Id.pp) pxs
      (pp_lst !>", " Id.pp) ctxvars pp s'
  | MacroApply (m, es) ->
    format ppf "@%a(%a)" Id.pp m (pp_lst !>", " EExpr.pp) es
  | Throw e -> format ppf "throw %a" EExpr.pp e
  | Fail e -> format ppf "fail %a" EExpr.pp e
  | Assert e -> format ppf "assert %a" EExpr.pp e

let str (s : t) : string = Fmt.str "%a" pp s

let rec map ?(emapper : EExpr.t -> EExpr.t = EExpr.Mapper.id) (mapper : t -> t)
  (s : t) : t =
  let map' = map ~emapper mapper in
  let mapper' s' = mapper (s' @> s.at) in
  let id_mapper (x : Id.t) =
    match (emapper (EExpr.Var x.it @> no_region)).it with
    | EExpr.Var y -> y @> x.at
    | _ -> Log.fail "expecting var in LHS"
  in
  mapper'
  @@
  match s.it with
  | Skip -> Skip
  | Debug s' -> Debug (map' s')
  | Block ss -> Block (List.map map' ss)
  | ExprStmt e -> ExprStmt (emapper e)
  | Print e -> Print (emapper e)
  | Return e -> Return (emapper e)
  | Assign (x, tx, e) -> Assign (id_mapper x, tx, emapper e)
  | GAssign (x, e) -> GAssign (id_mapper x, emapper e)
  | FieldAssign (oe, fe, e) -> FieldAssign (emapper oe, emapper fe, emapper e)
  | FieldDelete (oe, fe) -> FieldDelete (emapper oe, emapper fe)
  | If (ifcss, elsecs) ->
    let map_ifcs (e, s, at) = (emapper e, map' s, at) in
    let map_elsecs s = map' s in
    If (List.map map_ifcs ifcss, Option.map map_elsecs elsecs)
  | While (e, s') -> While (emapper e, map' s')
  | ForEach (x, e, s') -> ForEach (id_mapper x, emapper e, map' s')
  | RepeatUntil (s', until) ->
    let map_until (e, at) = (emapper e, at) in
    RepeatUntil (map' s', Option.map map_until until)
  | Switch (e, css, dflt) ->
    let map_cs (e, s) = (emapper e, map' s) in
    Switch (emapper e, List.map map_cs css, Option.map map' dflt)
  | MatchWith (e, dsc, css) ->
    let map_cs (pat, s) = (pat, map' s) in
    MatchWith (emapper e, Option.map id_mapper dsc, List.map map_cs css)
  | Lambda (x, id, pxs, ctxvars, s') -> Lambda (x, id, pxs, ctxvars, map' s')
  | MacroApply (m, es) -> MacroApply (m, List.map emapper es)
  | Throw e -> Throw (emapper e)
  | Fail e -> Fail (emapper e)
  | Assert e -> Assert (emapper e)

let rec to_list ?(recursion : bool = false) (to_list_f : t -> 'a list) (s : t) :
  'a list =
  let to_list_s = to_list ~recursion to_list_f in
  let to_list_ss stmts = List.concat (List.map to_list_s stmts) in
  let to_list_recursive () =
    match s.it with
    | Skip | ExprStmt _ | Print _ | Return _ | Assign _ | GAssign _
    | FieldAssign _ | FieldDelete _ | MacroApply _ | Throw _ | Fail _ | Assert _
      ->
      []
    | Debug s' -> to_list_s s'
    | Block ss -> to_list_ss ss
    | If (ifcss, elsecs) ->
      to_list_ss
        ( List.map (fun (_, s, _) -> s) ifcss
        @ Option.fold ~none:[] ~some:(fun s -> [ s ]) elsecs )
    | While (_, s') -> to_list_s s'
    | ForEach (_, _, s') -> to_list_s s'
    | RepeatUntil (s', _) -> to_list_s s'
    | Switch (_, css, dlft) ->
      to_list_ss
        ( List.map (fun (_, s) -> s) css
        @ Option.fold ~none:[] ~some:(fun s -> [ s ]) dlft )
    | MatchWith (_, _, css) -> to_list_ss (List.map (fun (_, s) -> s) css)
    | Lambda (_, _, _, _, s) -> to_list_s s
  in
  to_list_f s @ if not recursion then [] else to_list_recursive ()

module Mapper = struct
  let id (s : t) : t = s
end
