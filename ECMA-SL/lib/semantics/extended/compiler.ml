open Val
open Expr
open Operators
open EOper
open E_Pat
open E_Pat_v
open E_Expr
open E_Stmt
open Source

let make_fresh_var_generator (pref : string) : unit -> string =
  let next, _ = Counter.count 0 1 in
  fun () ->
    let x = next () in
    pref ^ string_of_int x

let __INTERNAL_ESL_GLOBAL__ = "___internal_esl_global"
let __MAIN_FUNC__ = "main"
let generate_fresh_var = make_fresh_var_generator "__v"

(*
  C(e1) = stmts_1, e_1'
  C(e2) = stmts_2, e_2'
  x fresh
------------------------
C(e1 &&& e2) =
    stmts_1;
    /* outer_if */
    if (e_1' = false) {
    	x := false
    } else {
        stmts_2;
        /* inner_if */
        if (e_2' = false) {
        	x := false
        } else {
        	x := true
        }
    }, x

*)
let compile_sc_and (x : string) (stmts_1 : Stmt.t list) (e1' : Expr.t)
    (stmts_2 : Stmt.t list) (e2' : Expr.t) (at : region) : Stmt.t list * Expr.t
    =
  let inner_if =
    Stmt.If
      ( Expr.BinOpt (Eq, e2', Expr.Val (Val.Bool false)),
        Stmt.Assign (x, Expr.Val (Val.Bool false)) @@ at,
        Some (Stmt.Assign (x, Expr.Val (Val.Bool true)) @@ at) )
    @@ at
  in

  let outer_if =
    Stmt.If
      ( Expr.BinOpt (Eq, e1', Expr.Val (Val.Bool false)),
        Stmt.Assign (x, Expr.Val (Val.Bool false)) @@ at,
        Some (Stmt.Block (stmts_2 @ [ inner_if ]) @@ at) )
    @@ at
  in
  (stmts_1 @ [ outer_if ], Expr.Var x)

(*
  C(e1) = stmts_1, e_1'
  C(e2) = stmts_2, e_2'
  x fresh
------------------------
C(e1 ||| e2) =
    stmts_1;
    if (e_1' = true) {
    	x := true
    } else {
        stmts_2;
        if (e_2' = true) {
        	x := true
        } else {
        	x := false
        }
    }, x
*)
let compile_sc_or (x : string) (stmts_1 : Stmt.t list) (e1' : Expr.t)
    (stmts_2 : Stmt.t list) (e2' : Expr.t) (at : region) : Stmt.t list * Expr.t
    =
  let inner_if =
    Stmt.If
      ( Expr.BinOpt (Eq, e2', Expr.Val (Val.Bool true)),
        Stmt.Assign (x, Expr.Val (Val.Bool true)) @@ at,
        Some (Stmt.Assign (x, Expr.Val (Val.Bool false)) @@ at) )
    @@ at
  in

  let outer_if =
    Stmt.If
      ( Expr.BinOpt (Eq, e1', Expr.Val (Val.Bool true)),
        Stmt.Assign (x, Expr.Val (Val.Bool true)) @@ at,
        Some (Stmt.Block (stmts_2 @ [ inner_if ]) @@ at) )
    @@ at
  in

  (stmts_1 @ [ outer_if ], Expr.Var x)

let compile_binopt (binop : Operators.bopt)
    ((stmts_1, e1) : Stmt.t list * Expr.t)
    ((stmts_2, e2) : Stmt.t list * Expr.t) (at : region) : Stmt.t list * Expr.t
    =
  let var = generate_fresh_var () in
  ( stmts_1 @ stmts_2 @ [ Stmt.Assign (var, Expr.BinOpt (binop, e1, e2)) @@ at ],
    Expr.Var var )

let compile_triopt (triop : topt) ((stmts_1, e1) : Stmt.t list * Expr.t)
    ((stmts_2, e2) : Stmt.t list * Expr.t)
    ((stmts_3, e3) : Stmt.t list * Expr.t) (at : region) : Stmt.t list * Expr.t
    =
  let var = generate_fresh_var () in
  ( stmts_1 @ stmts_2 @ stmts_3
    @ [ Stmt.Assign (var, Expr.TriOpt (triop, e1, e2, e3)) @@ at ],
    Expr.Var var )

(*
 y fresh
-------------------------
C_e(|x|) =
   y := ___internal_esl_global["x"], y
*)
let compile_gvar (x : string) (at : region) : Stmt.t list * Expr.t =
  let y = generate_fresh_var () in
  let var =
    match x with
    (* Keep this in sync with Heap.ml function "str_with_global" *)
    | "global" -> Common.global_var_compiled
    | _ -> x
  in
  let f_lookup =
    Stmt.FieldLookup
      (y, Expr.Var __INTERNAL_ESL_GLOBAL__, Expr.Val (Val.Str var))
    @@ at
  in
  ([ f_lookup ], Expr.Var y)

(*
C_e(e) = stmts_e, x_e
----------------------
C(|x| := e) =
  stmts_e;
  ___internal_esl_global["x"] := x_e
*)
let compile_glob_assign (x : string) (stmts_e : Stmt.t list) (e : Expr.t)
    (at : region) : Stmt.t list =
  let var =
    match x with
    (* Keep this in sync with Heap.ml function "str_with_global" *)
    | "global" -> Common.global_var_compiled
    | _ -> x
  in
  let f_asgn =
    Stmt.FieldAssign
      (Expr.Var __INTERNAL_ESL_GLOBAL__, Expr.Val (Val.Str var), e)
    @@ at
  in
  stmts_e @ [ f_asgn ]

(*
  C(x := lambda_{id_x} (xs) [ys] {s}) := x := {"id_x"}@(ys)
*)
let compile_lambda_call (x : string) (f : string) (ys : string list)
    (at : region) : Stmt.t list =
  let e =
    Expr.Curry (Expr.Val (Val.Str f), List.map (fun v -> Expr.Var v) ys)
  in
  [ Stmt.Assign (x, e) @@ at ]

(*
C_e(e_f) = stmts_f, e_f'
C_e(e_i) = stmts_i, e_i' | i = 1, ..., n
x fresh
----------------------
C(e_f@(e1, ..., en)) =
   stmts_f;
   stmts_1;
   ...
   stmts_n;
   x := e_f'@(e1', ..., en'),
      x
*)
let compile_curry ((stmts_f, e_f) : Stmt.t list * Expr.t)
    (args : (Stmt.t list * Expr.t) list) (at : region) : Stmt.t list * Expr.t =
  let x = generate_fresh_var () in
  let stmtss, es = List.split args in
  let stmts = List.concat stmtss in
  let stmts' = stmts_f @ stmts in
  let e_call = Expr.Curry (e_f, es) in
  let asgn = Stmt.Assign (x, e_call) @@ at in
  (stmts' @ [ asgn ], Expr.Var x)

(*
C(e) = stmts, e'
C(e_i) = stmts_i, e_i' | i=1, ..., n
C(s_i) = stmts_i' | i=1, ..., n
C(s') = stmts'
x_done fresh
-------------------------------------------------------------
   C(switch(e) { case e1: s1  case en: sn default: s'}) =
     stmts
      stmts_1
      if (e' = e_1') {
        stmts_1'
      } else {
        stmts_2
        if (e' = e_2') {
          stmts_2'
        } else {
          ...
          stmts'
        }
      }

   Compilation 2:
     stmts
      stmts_1
      if (e' = e_1' && ! x_done) {
        x_done := true;
        stmts_1'
      }
      stmts_2
      if (e' = e_2' && ! x_done) {
         x_done := true;
        stmts_2'
      }
      ...
      if (! x_done) {
        stmts'
      }
*)
let compile_switch (ret_e : Stmt.t list * Expr.t)
    (ret_cases : (Stmt.t list * Expr.t * Stmt.t list) list)
    (ret_so : Stmt.t list) (at : region) : Stmt.t list =
  let stmts, e' = ret_e in
  let stmts'' =
    List.fold_right
      (fun (s_i, e_i', s_i') s_else ->
        let g_i = Expr.BinOpt (Eq, e_i', e') in
        let stmt_if =
          Stmt.If (g_i, Stmt.Block s_i' @@ at, Some (Stmt.Block s_else @@ at))
          @@ at
        in
        s_i @ [ stmt_if ])
      ret_cases ret_so
  in
  stmts @ stmts''

let compile_fail (ret_e : Stmt.t list * Expr.t) (at : region) : Stmt.t list =
  let stmts_expr, expr' = ret_e in
  stmts_expr @ [ Stmt.Fail expr' @@ at ]

let compile_throw (ret_e : Stmt.t list * Expr.t) (at : region) : Stmt.t list =
  let stmts_expr, e' = ret_e in
  let ret_stmt =
    Stmt.Return (Expr.NOpt (TupleExpr, [ Expr.Val (Val.Bool true); e' ])) @@ at
  in
  stmts_expr @ [ ret_stmt ]

let compile_return (ret_e : Stmt.t list * Expr.t) (at : region) : Stmt.t list =
  let stmts_expr, e' = ret_e in
  let ret_stmt =
    Stmt.Return (Expr.NOpt (TupleExpr, [ Expr.Val (Val.Bool false); e' ])) @@ at
  in
  stmts_expr @ [ ret_stmt ]

(*
C_e(e) = stmts', x'
C_e(e_i) = stmts_i, x_i
x fresh
-----------------------------------------
C_s({e}(e1, ..., en)) =
 	stmts';
    stmts_1;
    ...
    stmts_n;
    x := x' (___internal_esl_global, x_1, ..., x_n)
    if (first(x)) {
      return x
    } else {
      x := second(x)
    }, x


C_s({e}(e1, ..., en) catch g) =
 	stmts';
    stmts_1;
    ...
    stmts_n;
    x := x' (___internal_esl_global, x_1, ..., x_n)
    if (first(x)) {
      x := "g" (___internal_esl_global, second(x))
      if (first(x)) {
        return x
      } else {
        x := second (x)
      }
    } else {
      x := second(x)
    }, x


*)
let build_if_throw_basic (x : string) (s_then : Stmt.t) (at : region) : Stmt.t =
  let guard = Expr.UnOpt (First, Expr.Var x) in
  let s_else = Stmt.Assign (x, Expr.UnOpt (Second, Expr.Var x)) @@ at in
  Stmt.If (guard, s_then, Some s_else) @@ at

let build_if_throw (x : string) (g : string option) (at : region) : Stmt.t =
  match g with
  | None -> build_if_throw_basic x (Stmt.Return (Expr.Var x) @@ at) at
  | Some g ->
      let args =
        [ Expr.Var __INTERNAL_ESL_GLOBAL__; Expr.UnOpt (Second, Expr.Var x) ]
      in
      let call_stmt = Stmt.AssignCall (x, Expr.Val (Val.Str g), args) @@ at in
      let inner_if =
        build_if_throw_basic x (Stmt.Return (Expr.Var x) @@ at) at
      in
      build_if_throw_basic x (Stmt.Block [ call_stmt; inner_if ] @@ at) at

let compile_call (ret_f : Stmt.t list * Expr.t)
    (ret_args : (Stmt.t list * Expr.t) list) (g : string option) (at : region) :
    Stmt.t list * Expr.t =
  let x = generate_fresh_var () in
  let fname_stmts, fname_expr = ret_f in
  let fargs_stmts_exprs = ret_args in
  let fargs_stmts, fargs_exprs = List.split fargs_stmts_exprs in
  let fargs_exprs' = Expr.Var __INTERNAL_ESL_GLOBAL__ :: fargs_exprs in
  let stmt_if = build_if_throw x g at in
  ( fname_stmts @ List.concat fargs_stmts
    @ [ Stmt.AssignCall (x, fname_expr, fargs_exprs') @@ at; stmt_if ],
    Expr.Var x )

(*
C(e_i) = stmts_i, x_i ,e_i|i=1^n = es
x fresh
------------------------------
 C(extern f(es)) =
     stmts_i |i=1^n
     x := extern f(x_i|i=1^n), x
*)

let compile_e_call (f : string) (ret_args : (Stmt.t list * Expr.t) list)
    (at : region) : Stmt.t list * Expr.t =
  let x = generate_fresh_var () in
  let fargs_stmts, fargs_exprs = List.split ret_args in
  ( List.concat fargs_stmts @ [ Stmt.AssignECall (x, f, fargs_exprs) @@ at ],
    Expr.Var x )

let compile_const (c : const) : Stmt.t list * Expr.t =
  match c with
  | MAX_VALUE -> ([], Expr.Val (Val.Flt Float.max_float))
  | MIN_VALUE -> ([], Expr.Val (Val.Flt 5e-324))
  | PI -> ([], Expr.Val (Val.Flt Float.pi))

let rec compile_ebinopt (binop : EOper.bopt) (e_e1 : E_Expr.t) (e_e2 : E_Expr.t)
    (at : region) : Stmt.t list * Expr.t =
  let x = generate_fresh_var () in
  let stmts_1, e1 = compile_expr at e_e1 in
  let stmts_2, e2 = compile_expr at e_e2 in
  match binop with
  | SCLogAnd -> compile_sc_and x stmts_1 e1 stmts_2 e2 at
  | SCLogOr -> compile_sc_or x stmts_1 e1 stmts_2 e2 at

and compile_unopt (op : uopt) (expr : E_Expr.t) (at : region) :
    Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_expr, expr' = compile_expr at expr in
  match op with
  | ObjToList ->
      (stmts_expr @ [ Stmt.AssignObjToList (var, expr') @@ at ], Expr.Var var)
  | _ ->
      ( stmts_expr @ [ Stmt.Assign (var, Expr.UnOpt (op, expr')) @@ at ],
        Expr.Var var )

and compile_nopt (nop : nopt) (e_exprs : E_Expr.t list) (at : region) :
    Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_exprs = List.map (compile_expr at) e_exprs in
  let stmts, exprs = List.split stmts_exprs in
  ( List.concat stmts @ [ Stmt.Assign (var, Expr.NOpt (nop, exprs)) @@ at ],
    Expr.Var var )

and compile_newobj (e_fes : (string * E_Expr.t) list) (at : region) :
    Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let newObj = Stmt.AssignNewObj var @@ at in
  let stmts =
    List.map
      (fun (pn, e) ->
        let stmts, e' = compile_expr at e in
        stmts
        @ [ Stmt.FieldAssign (Expr.Var var, Expr.Val (Val.Str pn), e') @@ at ])
      e_fes
  in
  (newObj :: List.concat stmts, Expr.Var var)

and compile_lookup (expr : E_Expr.t) (field : E_Expr.t) (at : region) :
    Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_expr, expr' = compile_expr at expr in
  let stmts_field, field' = compile_expr at field in
  ( stmts_expr @ stmts_field @ [ Stmt.FieldLookup (var, expr', field') @@ at ],
    Expr.Var var )

and compile_assign (lval : string) (rval : E_Expr.t) (at : region) : Stmt.t list
    =
  let stmts, rval' = compile_expr at rval in
  stmts @ [ Stmt.Assign (lval, rval') @@ at ]

and compile_block (e_stmts : E_Stmt.t list) : Stmt.t list =
  let stmts_lists = List.map compile_stmt e_stmts in
  List.concat stmts_lists

and compile_if (expr : E_Expr.t) (stmt1 : E_Stmt.t) (stmt2 : E_Stmt.t option)
    (at : region) : Stmt.t list =
  let stmts_expr, expr' = compile_expr at expr in
  let stmts_s1 = Stmt.Block (compile_stmt stmt1) @@ stmt1.at in
  let stmts_s2 =
    match stmt2 with
    | None -> None
    | Some s2 -> Some (Stmt.Block (compile_stmt s2) @@ s2.at)
  in
  stmts_expr @ [ Stmt.If (expr', stmts_s1, stmts_s2) @@ at ]

and compile_while (expr : E_Expr.t) (stmt : E_Stmt.t) (at : region) :
    Stmt.t list =
  let stmts_expr, expr' = compile_expr at expr in
  let stmts_stmt = compile_stmt stmt in
  stmts_expr
  @ [
      Stmt.While (expr', Stmt.Block (stmts_stmt @ stmts_expr) @@ stmt.at) @@ at;
    ]

and compile_fieldassign (e_eo : E_Expr.t) (e_f : E_Expr.t) (e_ev : E_Expr.t)
    (at : region) : Stmt.t list =
  let stmts_eo, expr_eo = compile_expr at e_eo in
  let stmts_f, expr_f = compile_expr at e_f in
  let stmts_ev, expr_ev = compile_expr at e_ev in
  stmts_eo @ stmts_f @ stmts_ev
  @ [ Stmt.FieldAssign (expr_eo, expr_f, expr_ev) @@ at ]

and compile_fielddelete (expr : E_Expr.t) (field : E_Expr.t) (at : region) :
    Stmt.t list =
  let stmts_expr, expr' = compile_expr at expr in
  let stmts_field, field' = compile_expr at field in
  stmts_expr @ stmts_field @ [ Stmt.FieldDelete (expr', field') @@ at ]

and compile_exprstmt (expr : E_Expr.t) (at : region) : Stmt.t list =
  let stmts_expr, _ = compile_expr at expr in
  stmts_expr

and compile_repeatuntil (stmt : E_Stmt.t) (expr : E_Expr.t) (at : region) :
    Stmt.t list =
  let stmts_stmt = compile_stmt stmt in
  let stmts_expr, expr' = compile_expr at expr in
  let not_expr = Expr.UnOpt (Not, expr') in
  let stmts = stmts_stmt @ stmts_expr in
  stmts @ [ Stmt.While (not_expr, Stmt.Block stmts @@ stmt.at) @@ at ]

and compile_patv (expr : Expr.t) (pname : string) (pat_v : E_Pat_v.t)
    (var_b : string) (at : region) : string list * Stmt.t list * Stmt.t list =
  match pat_v with
  | PatVar v ->
      ([], [], [ Stmt.FieldLookup (v, expr, Expr.Val (Val.Str pname)) @@ at ])
  | PatVal v ->
      let b = generate_fresh_var () in
      let w = generate_fresh_var () in
      let stmt = Stmt.FieldLookup (w, expr, Expr.Val (Val.Str pname)) @@ at in
      let stmt_assign =
        Stmt.Assign (b, Expr.BinOpt (Eq, Expr.Var w, Expr.Val v)) @@ at
      in
      ([ b ], [ stmt; stmt_assign ], [])
  | PatNone ->
      let stmt = Stmt.Assign (var_b, Expr.UnOpt (Not, Expr.Var var_b)) @@ at in
      ([], [ stmt ], [])

and compile_pn_pat (expr : Expr.t) ((pn, patv) : string * E_Pat_v.t)
    (at : region) : string list * Stmt.t list * Stmt.t list =
  let fresh_b = generate_fresh_var () in
  let in_stmt =
    Stmt.AssignInObjCheck (fresh_b, Expr.Val (Val.Str pn), expr) @@ at
  in
  let bs, stmts, stmts' = compile_patv expr pn patv fresh_b at in
  (fresh_b :: bs, in_stmt :: stmts, stmts')

and compile_pat (expr : Expr.t) (e_pat : E_Pat.t) (at : region) :
    string list * Stmt.t list * Stmt.t list =
  match e_pat with
  | DefaultPat -> ([], [], [])
  | ObjPat (pn_pats, _) ->
      let bs, pre_stmts, in_stmts =
        List.fold_left
          (fun (bs, pre_stmts, in_stmts) pn_pat ->
            let bs', pre_stmts', in_stmts' = compile_pn_pat expr pn_pat at in
            (bs @ bs', pre_stmts @ pre_stmts', in_stmts @ in_stmts'))
          ([], [], []) pn_pats
      in
      (bs, pre_stmts, in_stmts)

and compile_pats_stmts (at : region) (expr : Expr.t)
    ((pat, stmt) : E_Pat.t * E_Stmt.t) : Stmt.t list * Expr.t * Stmt.t list =
  let bs, pre_pat_stmts, in_pat_stmts = compile_pat expr pat at in
  let stmts = compile_stmt stmt in
  let and_bs =
    Expr.NOpt
      (NAry_And, Expr.Val (Val.Bool true) :: List.map (fun b -> Expr.Var b) bs)
  in
  let if_stmt = in_pat_stmts @ stmts in
  (pre_pat_stmts, and_bs, if_stmt)

and compile_matchwith (expr : E_Expr.t) (pats_stmts : (E_Pat.t * E_Stmt.t) list)
    (at : region) : Stmt.t list =
  let stmts_expr, expr' = compile_expr at expr in
  let pat_stmts_bs_stmts_list =
    List.rev (List.map (compile_pats_stmts at expr') pats_stmts)
  in
  let chained_ifs =
    match pat_stmts_bs_stmts_list with
    | [] -> []
    | (pat_stmts, bs_expr, stmts) :: rest ->
        let last_if =
          pat_stmts @ [ Stmt.If (bs_expr, Stmt.Block stmts @@ at, None) @@ at ]
        in
        List.fold_left
          (fun acc (ps, be, ss) ->
            ps
            @ [
                Stmt.If (be, Stmt.Block ss @@ at, Some (Stmt.Block acc @@ at))
                @@ at;
              ])
          last_if rest
  in
  stmts_expr @ chained_ifs

and compile_expr (at : region) (e_expr : E_Expr.t) : Stmt.t list * Expr.t =
  match e_expr with
  | Val x -> ([], Expr.Val x)
  | Var x -> ([], Expr.Var x)
  | GVar x -> compile_gvar x at
  | Const c -> compile_const c
  | Symbolic (t, x) ->
      let stmts, x' = compile_expr at x in
      (stmts, Expr.Symbolic (t, x'))
  | BinOpt (op, e1, e2) ->
      let stmts_1, e1' = compile_expr at e1 in
      let stmts_2, e2' = compile_expr at e2 in
      compile_binopt op (stmts_1, e1') (stmts_2, e2') at
  | TriOpt (op, e1, e2, e3) ->
      let stmts_1, e1' = compile_expr at e1 in
      let stmts_2, e2' = compile_expr at e2 in
      let stmts_3, e3' = compile_expr at e3 in
      compile_triopt op (stmts_1, e1') (stmts_2, e2') (stmts_3, e3') at
  | EBinOpt (e_op, e_e1, e_e2) -> compile_ebinopt e_op e_e1 e_e2 at
  | UnOpt (op, e_e) -> compile_unopt op e_e at
  | NOpt (op, e_es) -> compile_nopt op e_es at
  | NewObj e_fes -> compile_newobj e_fes at
  | Lookup (e_e, e_f) -> compile_lookup e_e e_f at
  | Curry (f, es) ->
      let f' = compile_expr at f and es' = List.map (compile_expr at) es in
      compile_curry f' es' at
  | Call (f, e_es, g) ->
      let ret_f = compile_expr at f in
      let ret_es = List.map (compile_expr at) e_es in
      compile_call ret_f ret_es g at
  | ECall (f, es) ->
      let ret_es = List.map (compile_expr at) es in
      compile_e_call f ret_es at

and compile_print (e : E_Expr.t) (at : region) : Stmt.t list =
  let stmts_expr, e' = compile_expr at e in
  stmts_expr @ [ Stmt.Print e' @@ at ]

and compile_assume (e : E_Expr.t) (at : region) : Stmt.t list =
  let stmts, e' = compile_expr at e in
  stmts @ [ Stmt.Assume e' @@ at ]

and compile_assert (e : E_Expr.t) (at : region) : Stmt.t list =
  let stmts, e' = compile_expr at e in
  stmts @ [ Stmt.Assert e' @@ at ]

and compile_stmt (e_stmt : E_Stmt.t) : Stmt.t list =
  let compile_cases =
    List.map (fun (e, s) ->
        let stmts_e, e' = compile_expr e_stmt.at e in
        let stmts_s = compile_stmt s in
        (stmts_e, e', stmts_s))
  in

  match e_stmt.it with
  | Skip -> [ Stmt.Skip @@ e_stmt.at ]
  | Print e -> compile_print e e_stmt.at
  | Wrapper (_, s) -> compile_stmt s
  | Assign (lval, rval) -> compile_assign lval rval e_stmt.at
  | GlobAssign (x, e) ->
      let stmts_e, e' = compile_expr e_stmt.at e in
      compile_glob_assign x stmts_e e' e_stmt.at
  | Block e_stmts -> compile_block e_stmts
  | If (e_e, e_s1, e_s2, _, _) -> compile_if e_e e_s1 e_s2 e_stmt.at
  | EIf (ifs, final_else) ->
      let acc =
        Option.map_default (fun (s, _) -> compile_stmt s) [] final_else
      in
      let ifs' = List.rev ifs in
      List.fold_left
        (fun acc (e, s, _) ->
          let stmts_e, e' = compile_expr s.at e in
          let stmts_s = compile_stmt s in
          stmts_e
          @ [
              Stmt.If
                ( e',
                  Stmt.Block stmts_s @@ s.at,
                  (* FIXME: at from final_else *)
                  Some (Stmt.Block acc @@ no_region) )
              @@ e_stmt.at;
            ])
        acc ifs'
  | While (e_exp, e_s) -> compile_while e_exp e_s e_stmt.at
  | ForEach (x, e_e, e_s, _, _) ->
      let len_str = generate_fresh_var () in
      let idx_str = generate_fresh_var () in
      let e_test = E_Expr.BinOpt (Gt, Var len_str, Var idx_str) in
      let stmt_inc =
        Stmt.Assign (idx_str, Expr.BinOpt (Plus, Var idx_str, Val (Int 1)))
        @@ e_stmt.at
      in
      let stmts_e_test, e_test' = compile_expr e_stmt.at e_test in
      let stmts_e, e_e' = compile_expr e_stmt.at e_e in
      let stmts_before =
        (Stmt.Assign (idx_str, Val (Int 0)) @@ e_stmt.at)
        :: [ Stmt.Assign (len_str, Expr.UnOpt (ListLen, e_e')) @@ e_stmt.at ]
      in
      let stmt_assign_x =
        Stmt.Assign (x, Expr.BinOpt (Lnth, e_e', Var idx_str)) @@ e_stmt.at
      in
      let stmts_s = compile_stmt e_s in
      stmts_e @ stmts_before @ stmts_e_test
      @ [
          Stmt.While
            ( e_test',
              Stmt.Block
                ((stmt_assign_x :: stmts_s) @ (stmt_inc :: stmts_e_test))
              @@ e_s.at )
          @@ e_stmt.at;
        ]
  | FieldAssign (e_eo, e_f, e_ev) -> compile_fieldassign e_eo e_f e_ev e_stmt.at
  | FieldDelete (e_e, e_f) -> compile_fielddelete e_e e_f e_stmt.at
  | ExprStmt e_e -> compile_exprstmt e_e e_stmt.at
  | RepeatUntil (e_s, e_e, _) -> compile_repeatuntil e_s e_e e_stmt.at
  | MatchWith (e_e, e_pats_e_stmts) ->
      compile_matchwith e_e e_pats_e_stmts e_stmt.at
  | Assume e_e -> compile_assume e_e e_stmt.at
  | Assert e_e -> compile_assert e_e e_stmt.at
  | Lambda (x, f, xs, ys, s) ->
      let ret = compile_lambda_call x f ys e_stmt.at in
      ret
  | MacroApply (_, _) ->
      invalid_arg "Macros are not valid compilable statements."
  | Throw e_e ->
      let ret_e = compile_expr e_stmt.at e_e in
      compile_throw ret_e e_stmt.at
  | Fail e_e ->
      let ret_e = compile_expr e_stmt.at e_e in
      compile_fail ret_e e_stmt.at
  | Switch (e, cases, so, _) ->
      let ret_e = compile_expr e_stmt.at e in
      let ret_cases = compile_cases cases in
      let ret_so = Option.map_default compile_stmt [] so in
      compile_switch ret_e ret_cases ret_so e_stmt.at
  | Return e_e ->
      let ret_e = compile_expr e_stmt.at e_e in
      compile_return ret_e e_stmt.at

(*
C(s) = s', _
---------------------------------------
C_f(function f (x1, ..., xn) { s }) =
   function f (___internal_esl_global, x1, ..., xn) { s' }


C(s) = s', _
---------------------------------------
C_f(function main () { s }) =
   function f () {
      ___internal_esl_global := {};
      s'
   }
*)
let compile_func (e_func : E_Func.t) : Func.t =
  let fname = E_Func.get_name e_func in
  let fparams = E_Func.get_params e_func in
  let fbody = E_Func.get_body e_func in
  let stmt_list = compile_stmt fbody in
  if fname = __MAIN_FUNC__ then
    let asgn_new_obj = Stmt.AssignNewObj __INTERNAL_ESL_GLOBAL__ @@ no_region in
    let stmt_list' = asgn_new_obj :: stmt_list in
    Func.create fname fparams (Stmt.Block stmt_list' @@ no_region)
  else
    let fparams' = __INTERNAL_ESL_GLOBAL__ :: fparams in
    Func.create fname fparams' (Stmt.Block stmt_list @@ no_region)

let compile_lambda
    ((f_id, params, params', s) : string * string list * string list * E_Stmt.t)
    : Func.t =
  let stmt_list = compile_stmt s in
  let params'' = params @ [ __INTERNAL_ESL_GLOBAL__ ] @ params' in
  Func.create f_id params'' (Stmt.Block stmt_list @@ no_region)

let compile_prog (e_prog : E_Prog.t) : Prog.t =
  let funcs =
    List.fold_left
      (fun acc func -> acc @ [ compile_func func ])
      [] (E_Prog.get_funcs e_prog)
  in
  let lambdas = E_Prog.lambdas e_prog in
  let lambda_funcs = List.map compile_lambda lambdas in
  Prog.create (lambda_funcs @ funcs)
