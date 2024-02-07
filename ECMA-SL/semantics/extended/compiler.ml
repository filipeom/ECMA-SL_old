open Source
open Operator

type c_expr = Stmt.t list * Expr.t
type c_stmt = Stmt.t list

let ( ?@ ) (e : Expr.t) : Id.t =
  match e.it with
  | Var x -> { it = x; at = e.at }
  | _ -> Eslerr.(internal __FUNCTION__ (Expecting "var expression"))

module Const = struct
  let original_main = "main"
  let esl_globals = "___internal_esl_global"
end

module Builder = struct
  let var_id = Utils.make_name_generator "__v"
  let etrue (x : 'a phrase) : Expr.t = Expr.Val (Val.Bool true) @> x.at
  let efalse (x : 'a phrase) : Expr.t = Expr.Val (Val.Bool false) @> x.at
  let global (x : 'a phrase) : Expr.t = Expr.Var Const.esl_globals @> x.at
  let var (at : region) : Expr.t = Expr.Var (var_id ()) @> at

  let block ?(at : region = no_region) (ss : Stmt.t list) : Stmt.t =
    Stmt.Block ss @> at

  let block_opt ?(at : region = no_region) (ss : Stmt.t list) : Stmt.t option =
    match ss with [] -> None | ss -> Some (Stmt.Block ss @> at)

  let throw_checker (res : Expr.t) (sthen : Stmt.t list) : Stmt.t =
    let iserror = Expr.UnOpt (TupleFirst, res) @> res.at in
    let value = Expr.UnOpt (TupleSecond, res) @> res.at in
    let selse = Stmt.Assign (?@res, value) @> res.at in
    Stmt.If (iserror, block sthen, block_opt [ selse ]) @> res.at

  let call_checker (res : Expr.t) (ferr : Id.t option) : Stmt.t =
    let sreturn = Stmt.Return res @> res.at in
    match ferr with
    | None -> throw_checker res [ sreturn ]
    | Some ferr' ->
      let res' = { res with at = ferr'.at } in
      let ferr'' = Expr.Val (Val.Str ferr'.it) @> ferr'.at in
      let err = Expr.(UnOpt (TupleSecond, res')) @> ferr'.at in
      let args = [ global ferr'; err ] in
      let sferr = Stmt.AssignCall (?@res', ferr'', args) @> ferr'.at in
      let sferr_checker = throw_checker res' [ sreturn ] in
      throw_checker res [ sferr; sferr_checker ]
end

module SwitchOptimizer = struct
  let is_optimizable (css : (EExpr.t * EStmt.t) list) : bool =
    match fst (List.split css) with
    | { it = EExpr.Val _; _ } :: { it = EExpr.Val _; _ } :: _ -> true
    | _ -> false

  let compile (at : region) (compile_stmt_f : EStmt.t -> c_stmt)
    (compile_rest_f : (EExpr.t * EStmt.t) list -> Stmt.t option) (e_e : Expr.t)
    (css : (EExpr.t * EStmt.t) list) : c_stmt =
    let rec hash_cases hashed_css = function
      | ({ it = EExpr.Val v; _ }, _) :: css' when Hashtbl.mem hashed_css v ->
        hash_cases hashed_css css'
      | ({ it = EExpr.Val v; _ }, s) :: css' ->
        Hashtbl.replace hashed_css v (Builder.block ~at:s.at (compile_stmt_f s));
        hash_cases hashed_css css'
      | css' -> css'
    in
    let hashed_css = Hashtbl.create !Config.default_hashtbl_sz in
    let css' = hash_cases hashed_css css in
    [ Stmt.Switch (e_e, hashed_css, compile_rest_f css') @> at ]
end

let compile_sc_and (res : Expr.t) (e1_s : Stmt.t list) (e1_e : Expr.t)
  (e2_s : Stmt.t list) (e2_e : Expr.t) : c_expr =
  let open Builder in
  let rtrue e = block [ Stmt.Assign (?@res, etrue e) @> e.at ] in
  let rfalse e = block [ Stmt.Assign (?@res, efalse e) @> e.at ] in
  let e1_test = Expr.BinOpt (Operator.Eq, e1_e, efalse e1_e) @> e1_e.at in
  let e2_test = Expr.BinOpt (Operator.Eq, e2_e, efalse e2_e) @> e2_e.at in
  let e2_if = Stmt.If (e2_test, rfalse e2_e, Some (rtrue e2_e)) @> e2_e.at in
  let e1_else = Builder.block_opt (e2_s @ [ e2_if ]) in
  let e1_if = Stmt.If (e1_test, rfalse e1_e, e1_else) @> e1_e.at in
  (e1_s @ [ e1_if ], res)

let compile_sc_or (res : Expr.t) (e1_s : Stmt.t list) (e1_e : Expr.t)
  (e2_s : Stmt.t list) (e2_e : Expr.t) : c_expr =
  let open Builder in
  let rtrue e = block [ Stmt.Assign (?@res, etrue e) @> e.at ] in
  let rfalse e = block [ Stmt.Assign (?@res, efalse e) @> e.at ] in
  let e1_test = Expr.BinOpt (Operator.Eq, e1_e, etrue e1_e) @> e1_e.at in
  let e2_test = Expr.BinOpt (Operator.Eq, e2_e, etrue e2_e) @> e2_e.at in
  let e2_if = Stmt.If (e2_test, rtrue e2_e, Some (rfalse e2_e)) @> e2_e.at in
  let e1_else = Builder.block_opt (e2_s @ [ e2_if ]) in
  let e1_if = Stmt.If (e1_test, rtrue e1_e, e1_else) @> e1_e.at in
  (e1_s @ [ e1_if ], res)

let rec compile_expr (e : EExpr.t) : c_expr =
  match e.it with
  | Val x -> ([], Expr.Val x @> e.at)
  | Var x -> ([], Expr.Var x @> e.at)
  | GVar x -> compile_gvar e x
  | Const c -> compile_const e.at c
  | UnOpt (op, e') -> compile_unopt e.at op e'
  | BinOpt (op, e1, e2) -> compile_binopt e.at op e1 e2
  | TriOpt (op, e1, e2, e3) -> compile_triopt e.at op e1 e2 e3
  | NOpt (op, es) -> compile_nopt e.at op es
  | Call (fe, es, ferr) -> compile_call e.at fe es ferr
  | ECall (fn, es) -> compile_ecall e.at fn es
  | NewObj flds -> compile_newobj e.at flds
  | Lookup (oe, fe) -> compile_lookup e.at oe fe
  | Curry (fe, es) -> compile_curry e.at fe es
  | Symbolic (t, e') -> compile_symbolic e.at t e'

and compile_gvar (e : EExpr.t) (x : Id.t') : c_expr =
  let res = Builder.var e.at in
  let global = Builder.global e in
  let entry = Expr.Val (Val.Str x) @> e.at in
  let sres = Stmt.FieldLookup (?@res, global, entry) @> e.at in
  ([ sres ], res)

and compile_const (at : region) (c : const) : c_expr =
  match c with
  | MAX_VALUE -> ([], Expr.Val (Val.Flt Float.max_float) @> at)
  | MIN_VALUE -> ([], Expr.Val (Val.Flt 5e-324) @> at)
  | PI -> ([], Expr.Val (Val.Flt Float.pi) @> at)

and compile_unopt (at : region) (op : unopt) (e : EExpr.t) : c_expr =
  let (e_s, e_e) = compile_expr e in
  let res = Builder.var at in
  let sres =
    match op with
    | ObjectToList -> Stmt.AssignObjToList (?@res, e_e) @> at
    | _ ->
      let unopt = Expr.UnOpt (op, e_e) @> at in
      Stmt.Assign (?@res, unopt) @> at
  in
  (e_s @ [ sres ], res)

and compile_binopt (at : region) (op : Operator.binopt) (e1 : EExpr.t)
  (e2 : EExpr.t) : c_expr =
  let (e1_s, e1_e) = compile_expr e1 in
  let (e2_s, e2_e) = compile_expr e2 in
  let res = Builder.var at in
  match op with
  | SCLogicalAnd -> compile_sc_and res e1_s e1_e e2_s e2_e
  | SCLogicalOr -> compile_sc_or res e1_s e1_e e2_s e2_e
  | _ ->
    let binopt = Expr.BinOpt (op, e1_e, e2_e) @> at in
    let sres = Stmt.Assign (?@res, binopt) @> at in
    (e1_s @ e2_s @ [ sres ], res)

and compile_triopt (at : region) (op : triopt) (e1 : EExpr.t) (e2 : EExpr.t)
  (e3 : EExpr.t) : c_expr =
  let (e1_s, e1_e) = compile_expr e1 in
  let (e2_s, e2_e) = compile_expr e2 in
  let (e3_s, e3_e) = compile_expr e3 in
  let res = Builder.var at in
  let triopt = Expr.TriOpt (op, e1_e, e2_e, e3_e) @> at in
  let sres = Stmt.Assign (?@res, triopt) @> at in
  (e1_s @ e2_s @ e3_s @ [ sres ], res)

and compile_nopt (at : region) (op : nopt) (es : EExpr.t list) : c_expr =
  let (es_s, es_e) = List.split (List.map compile_expr es) in
  let res = Builder.var at in
  let nopt = Expr.NOpt (op, es_e) @> at in
  let sres = Stmt.Assign (?@res, nopt) @> at in
  (List.concat es_s @ [ sres ], res)

and compile_call (at : region) (fe : EExpr.t) (es : EExpr.t list)
  (ferr : Id.t option) : c_expr =
  let (fe_s, fe_e) = compile_expr fe in
  let (es_s, es_e) = List.split (List.map compile_expr es) in
  let global = Builder.global fe in
  let res = Builder.var at in
  let sres = Stmt.AssignCall (?@res, fe_e, global :: es_e) @> at in
  let sthrow = Builder.call_checker res ferr in
  (fe_s @ List.concat es_s @ [ sres; sthrow ], res)

and compile_ecall (at : region) (fn : Id.t) (es : EExpr.t list) : c_expr =
  let (es_s, es_e) = List.split (List.map compile_expr es) in
  let res = Builder.var at in
  let sres = Stmt.AssignECall (?@res, fn, es_e) @> at in
  (List.concat es_s @ [ sres ], res)

and compile_newobj (at : region) (flds : (Id.t * EExpr.t) list) : c_expr =
  let build_fld res (fn, fe) =
    let (fe_s, fe_e) = compile_expr fe in
    let oe = { res with at = fn.at } in
    let fe = Expr.Val (Val.Str fn.it) @> fn.at in
    let sfassign = Stmt.FieldAssign (oe, fe, fe_e) @> fe_e.at in
    fe_s @ [ sfassign ]
  in
  let res = Builder.var at in
  let snewobj = Stmt.AssignNewObj ?@res @> at in
  let sflds = List.concat (List.map (build_fld res) flds) in
  (snewobj :: sflds, res)

and compile_lookup (at : region) (oe : EExpr.t) (fe : EExpr.t) : c_expr =
  let (oe_s, oe_e) = compile_expr oe in
  let (fe_s, fe_e) = compile_expr fe in
  let res = Builder.var at in
  let sres = Stmt.FieldLookup (?@res, oe_e, fe_e) @> at in
  (oe_s @ fe_s @ [ sres ], res)

and compile_curry (at : region) (fe : EExpr.t) (es : EExpr.t list) : c_expr =
  let (fe_s, fe_e) = compile_expr fe in
  let (es_s, es_e) = List.split (List.map compile_expr es) in
  let res = Builder.var at in
  let sres = Stmt.Assign (?@res, Expr.Curry (fe_e, es_e) @> at) @> at in
  (fe_s @ List.concat es_s @ [ sres ], res)

and compile_symbolic (at : region) (t : Type.t) (e : EExpr.t) : c_expr =
  let (e_s, e_e) = compile_expr e in
  let res = Builder.var at in
  let sres = Stmt.Assign (?@res, Expr.Symbolic (t, e_e) @> at) @> at in
  (e_s @ [ sres ], res)

let rec compile_stmt (s : EStmt.t) : c_stmt =
  match s.it with
  | Skip -> [ Stmt.Skip @> s.at ]
  | Debug s' -> compile_debug s.at s'
  | Block ss -> List.concat (List.map compile_stmt ss)
  | Print e -> compile_print s.at e
  | Return e -> compile_return s.at e
  | ExprStmt e -> fst (compile_expr e)
  | Assign (x, _, e) -> compile_assign s.at x e
  | GAssign (x, e) -> compile_gassign s.at x e
  | FieldAssign (oe, fe, e) -> compile_fieldassign s.at oe fe e
  | FieldDelete (oe, fe) -> compile_fielddelete s.at oe fe
  | If (ifcss, elsecs) -> compile_if ifcss elsecs
  | While (e, s') -> compile_while s.at e s'
  | ForEach (x, e, s', _, _) -> compile_foreach s.at x e s'
  | RepeatUntil (s', e, _) -> compile_repeatuntil s.at s' e
  | Switch (e, css, dflt, _) -> compile_switch s.at e css dflt
  | MatchWith (e, _, css) -> compile_matchwith e css
  | Lambda (x, lid, _, ctxvars, _) -> compile_lambdacall s.at x lid ctxvars
  | MacroApply (_, _) ->
    Eslerr.(internal __FUNCTION__ (UnexpectedEval (Some "MacroApply")))
  | Throw e -> compile_throw s.at e
  | Fail e -> compile_fail s.at e
  | Assert e -> compile_assert s.at e
  | Wrapper (_, s) -> compile_stmt s

and compile_debug (at : region) (s : EStmt.t) : c_stmt =
  match compile_stmt s with
  | [] -> Eslerr.(internal __FUNCTION__ (Expecting "non-empty statement list"))
  | s1_s :: ss_s -> (Stmt.Debug s1_s @> at) :: ss_s

and compile_print (at : region) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  e_s @ [ Stmt.Print e_e @> at ]

and compile_return (at : region) (e : EExpr.t) : c_stmt =
  let e' = if EExpr.isvoid e then EExpr.Val Val.Null @> at else e in
  let (e_s, e_e) = compile_expr e' in
  let err = Builder.efalse e' in
  let ret = Expr.NOpt (TupleExpr, [ err; e_e ]) @> e'.at in
  e_s @ [ Stmt.Return ret @> at ]

and compile_assign (at : region) (x : Id.t) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  e_s @ [ Stmt.Assign (x, e_e) @> at ]

and compile_gassign (at : region) (x : Id.t) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  let global = Builder.global e in
  let entry = Expr.Val (Val.Str x.it) @> x.at in
  e_s @ [ Stmt.FieldAssign (global, entry, e_e) @> at ]

and compile_fieldassign (at : region) (oe : EExpr.t) (fe : EExpr.t) (e : EExpr.t)
  : c_stmt =
  let (oe_s, oe_e) = compile_expr oe in
  let (fe_s, fe_e) = compile_expr fe in
  let (e_s, e_e) = compile_expr e in
  oe_s @ fe_s @ e_s @ [ Stmt.FieldAssign (oe_e, fe_e, e_e) @> at ]

and compile_fielddelete (at : region) (oe : EExpr.t) (fe : EExpr.t) : c_stmt =
  let (oe_s, oe_e) = compile_expr oe in
  let (fe_s, fe_e) = compile_expr fe in
  oe_s @ fe_s @ [ Stmt.FieldDelete (oe_e, fe_e) @> at ]

and compile_if (ifcss : (EExpr.t * EStmt.t * EStmt.metadata_t list) list)
  (elsecs : (EStmt.t * EStmt.metadata_t list) option) : c_stmt =
  let compile_ifcs_f (e, s, _) acc =
    let (e_s, e_e) = compile_expr e in
    let sblock = Builder.block ~at:s.at (compile_stmt s) in
    e_s @ [ Stmt.If (e_e, sblock, Builder.block_opt acc) @> e_e.at ]
  in
  List.fold_right compile_ifcs_f ifcss
    (Option.fold ~none:[] ~some:(fun (s, _) -> compile_stmt s) elsecs)

and compile_while (at : region) (e : EExpr.t) (s : EStmt.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  let sblock = Builder.block ~at:s.at (compile_stmt s @ e_s) in
  e_s @ [ Stmt.While (e_e, sblock) @> at ]

and compile_foreach (at : region) (x : Id.t) (e : EExpr.t) (s : EStmt.t) :
  c_stmt =
  let i = Builder.var x.at in
  let len = Builder.var e.at in
  let (i', len') = EExpr.(Var ?@i.it @> i.at, Var ?@len.it @> len.at) in
  let guard = EExpr.(BinOpt (Gt, len', i')) @> at in
  let (e_s, e_e) = compile_expr e in
  let (guard_s, guard_e) = compile_expr guard in
  let s_s = compile_stmt s in
  let inc = Expr.Val (Val.Int 1) @> at in
  let sinit = Stmt.Assign (?@i, Expr.Val (Int 0) @> at) @> at in
  let slen = Stmt.Assign (?@len, Expr.UnOpt (ListLen, e_e) @> at) @> at in
  let snth = Stmt.Assign (x, Expr.BinOpt (ListNth, e_e, i) @> at) @> at in
  let sinc = Stmt.Assign (?@i, Expr.BinOpt (Plus, i, inc) @> at) @> at in
  let sblock = Builder.block ~at:s.at ((snth :: s_s) @ (sinc :: guard_s)) in
  e_s @ [ sinit; slen ] @ guard_s @ [ Stmt.While (guard_e, sblock) @> at ]

and compile_repeatuntil (at : region) (s : EStmt.t) (e : EExpr.t option) :
  c_stmt =
  let e' = Option.value ~default:(EExpr.Val (Val.Bool false) @> at) e in
  let s_s = compile_stmt s in
  let (e_s, e_e) = compile_expr e' in
  let guard = Expr.UnOpt (LogicalNot, e_e) @> e'.at in
  let block = s_s @ e_s in
  block @ [ Stmt.While (guard, Builder.block ~at:s.at block) @> at ]

and compile_switch (at : region) (e : EExpr.t) (css : (EExpr.t * EStmt.t) list)
  (dflt : EStmt.t option) : c_stmt =
  let rec compile_switch' e_e = function
    | [] -> Option.fold dflt ~none:[] ~some:compile_stmt
    | css when SwitchOptimizer.is_optimizable css ->
      SwitchOptimizer.compile at compile_stmt (compile_rest_f e_e) e_e css
    | (ei, si) :: css' ->
      let (ei_s, ei_e) = compile_expr ei in
      let guard = Expr.BinOpt (Eq, e_e, ei_e) @> ei.at in
      let sblock = Builder.block ~at:si.at (compile_stmt si) in
      ei_s @ [ Stmt.If (guard, sblock, compile_rest_f e_e css') @> ei.at ]
  and compile_rest_f e_e css = Builder.block_opt (compile_switch' e_e css) in
  let (e_s, e_e) = compile_expr e in
  e_s @ compile_switch' e_e css

and compile_patv (e_e : Expr.t) (inobj : Expr.t) (pbn : Id.t) (pbv : EPat.pv) :
  c_stmt * Expr.t list * c_stmt =
  let pbn' = Expr.Val (Val.Str pbn.it) @> pbn.at in
  match pbv.it with
  | PatVar x -> ([], [], [ Stmt.FieldLookup (x @> pbv.at, e_e, pbn') @> pbn.at ])
  | PatVal v ->
    let fval = Builder.var pbn.at in
    let feq = Builder.var pbv.at in
    let fval_s = Stmt.FieldLookup (?@fval, e_e, pbn') @> pbn.at in
    let feq' = Expr.BinOpt (Eq, fval, Expr.Val v @> pbv.at) @> pbv.at in
    let feq_s = Stmt.Assign (?@feq, feq') @> pbv.at in
    ([ fval_s; feq_s ], [ feq ], [])
  | PatNone ->
    let fnone = Expr.UnOpt (LogicalNot, inobj) @> pbv.at in
    let fnone_s = Stmt.Assign (?@inobj, fnone) @> pbv.at in
    ([ fnone_s ], [], [])

and compile_pat (e_e : Expr.t) (pat : EPat.t) : c_stmt * Expr.t * c_stmt =
  let compile_pbs (pre_s, guards, pat_s) (pbn, pbv) =
    let pbn' = Expr.Val (Val.Str pbn.it) @> pbn.at in
    let inobj = Builder.var pbn.at in
    let sinobj = Stmt.AssignInObjCheck (?@inobj, pbn', e_e) @> pbn.at in
    let (pre_s', guards', pat_s') = compile_patv e_e inobj pbn pbv in
    (pre_s @ (sinobj :: pre_s'), guards @ (inobj :: guards'), pat_s @ pat_s')
  in
  let etrue = Expr.Val (Val.Bool true) @> pat.at in
  match pat.it with
  | DefaultPat -> ([], etrue, [])
  | ObjPat (pbs, _) ->
    let (pre_s, guards, pat_s) = List.fold_left compile_pbs ([], [], []) pbs in
    let guard = Expr.NOpt (NAryLogicalAnd, etrue :: guards) @> pat.at in
    (pre_s, guard, pat_s)

and compile_matchwith (e : EExpr.t) (css : (EPat.t * EStmt.t) list) : c_stmt =
  let rec compile_matchwith' e_e = function
    | [] -> []
    | (pat, s) :: css' ->
      let (pre_s, guard_e, pat_s) = compile_pat e_e pat in
      let sblock = Builder.block ~at:s.at (pat_s @ compile_stmt s) in
      let selse = Builder.block_opt (compile_matchwith' e_e css') in
      pre_s @ [ Stmt.If (guard_e, sblock, selse) @> pat.at ]
  in
  let (e_s, e_e) = compile_expr e in
  e_s @ compile_matchwith' e_e css

and compile_lambdacall (at : region) (x : Id.t) (id : string)
  (ctxvars : Id.t list) : c_stmt =
  let ctxvars' = List.map (fun x -> Expr.Var x.it @> x.at) ctxvars in
  let curry = Expr.Curry (Expr.Val (Val.Str id) @> at, ctxvars') @> at in
  [ Stmt.Assign (x, curry) @> at ]

and compile_throw (at : region) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  let err = Builder.etrue e in
  let ret = Expr.NOpt (TupleExpr, [ err; e_e ]) @> e.at in
  e_s @ [ Stmt.Return ret @> at ]

and compile_fail (at : region) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  e_s @ [ Stmt.Fail e_e @> at ]

and compile_assert (at : region) (e : EExpr.t) : c_stmt =
  let (e_s, e_e) = compile_expr e in
  e_s @ [ Stmt.Assert e_e @> at ]

let compile_func (f : EFunc.t) : Func.t =
  let (fn, pxs, s) = EFunc.(name f, params f, body f) in
  let global = Const.esl_globals @> fn.at in
  let s_s = compile_stmt s in
  if fn.it = Const.original_main then
    let s_s' = (Stmt.AssignNewObj global @> fn.at) :: s_s in
    Func.create fn pxs (Builder.block ~at:s.at s_s') @> f.at
  else
    let params' = global :: pxs in
    Func.create fn params' (Builder.block ~at:s.at s_s) @> f.at

let compile_lambda
  ((at, id, pxs, ctxvars, s) : region * string * Id.t list * Id.t list * EStmt.t)
  : Func.t =
  let global = Const.esl_globals @> at in
  let s_s = compile_stmt s in
  let params = ctxvars @ (global :: pxs) in
  Func.create (id @> at) params (Builder.block ~at:s.at s_s) @> at

let compile_prog (p : EProg.t) : Prog.t =
  let funcs_f acc f = acc @ [ compile_func f ] in
  let funcs = List.fold_left funcs_f [] (EProg.funcs_lst p) in
  let lambdas = List.map compile_lambda (EProg.lambdas p) in
  Prog.create (lambdas @ funcs)
