let make_fresh_var_generator (pref : string) : (unit -> string) =
  let count = ref 0 in
  fun () -> let x = !count in
    count := x+1; pref ^ (string_of_int x)


let generate_fresh_var = make_fresh_var_generator "__v"


let rec compile_binopt (binop : Oper.bopt) (e_e1 : E_Expr.t) (e_e2 : E_Expr.t) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_1, e1 = compile_expr e_e1 in
  let stmts_2, e2 = compile_expr e_e2 in
  stmts_1 @ stmts_2 @ [Stmt.Assign (var, Expr.BinOpt (binop, e1, e2))], Expr.Var var


and compile_unopt (op : Oper.uopt) (expr : E_Expr.t) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_expr, expr' = compile_expr expr in
  stmts_expr @ [Stmt.Assign (var, Expr.UnOpt (op, expr'))], Expr.Var var


and compile_nopt (nop : Oper.nopt) (e_exprs : E_Expr.t list) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_exprs = List.map compile_expr e_exprs in
  let stmts, exprs = List.split stmts_exprs in
  (List.concat stmts) @ [Stmt.Assign (var, Expr.NOpt (nop, exprs))], Expr.Var var


and compile_call (fname : E_Expr.t) (fargs : E_Expr.t list) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let fname_stmts, fname_expr = compile_expr fname in
  let fargs_stmts_exprs = List.map compile_expr fargs in
  let fargs_stmts, fargs_exprs = List.split fargs_stmts_exprs in
  fname_stmts @ List.concat fargs_stmts @ [Stmt.AssignCall (var, fname_expr, fargs_exprs)], Expr.Var var


and compile_newobj (e_fes : (string * E_Expr.t) list) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let newObj = Stmt.AssignNewObj var in
  let stmts = List.map (fun (pn, e) -> let stmts, e' = compile_expr e in
                         stmts @ [Stmt.FieldAssign(Expr.Var var, Expr.Val (Val.Str pn), e')]) e_fes in
  newObj :: List.concat stmts, Expr.Var var


and compile_access (expr : E_Expr.t) (field : E_Expr.t) : Stmt.t list * Expr.t =
  let var = generate_fresh_var () in
  let stmts_expr, expr' = compile_expr expr in
  let stmts_field, field' = compile_expr field in
  stmts_expr @ stmts_field @ [Stmt.AssignAccess (var, expr', field')], Expr.Var var


and compile_assign (var : string) (e_exp : E_Expr.t) : Stmt.t list =
  let stmts, aux_var = compile_expr e_exp in
  stmts @ [Stmt.Assign (var, aux_var)]


and compile_block (e_stmts : E_Stmt.t list) : Stmt.t list =
  let stmts_lists = List.map (compile_stmt) e_stmts in
  List.concat stmts_lists


and compile_if (expr : E_Expr.t) (stmt1 : E_Stmt.t) (stmt2 : E_Stmt.t option) : Stmt.t list =
  let stmts_expr, expr' = compile_expr expr in
  let stmts_s1 = Stmt.Block (compile_stmt stmt1) in
  let stmts_s2 = match stmt2 with
    | None    -> None
    | Some s2 -> Some (Stmt.Block (compile_stmt s2)) in
  stmts_expr @ [Stmt.If (expr', stmts_s1, stmts_s2)]


and compile_while (expr : E_Expr.t) (stmt : E_Stmt.t) : Stmt.t list =
  let stmts_expr, expr' = compile_expr expr in
  let stmts_stmt = compile_stmt stmt in
  stmts_expr @ [Stmt.While (expr', Stmt.Block (stmts_stmt @ stmts_expr))]


and compile_return (expr : E_Expr.t) : Stmt.t list =
  let stmts_expr, expr' = compile_expr expr in
  stmts_expr @ [Stmt.Return (expr')]


and compile_fieldassign (e_eo : E_Expr.t) (e_f : E_Expr.t) (e_ev : E_Expr.t) : Stmt.t list =
  let stmts_eo, expr_eo = compile_expr e_eo in
  let stmts_f, expr_f = compile_expr e_f in
  let stmts_ev, expr_ev = compile_expr e_ev in
  stmts_eo @ stmts_f @ stmts_ev @ [Stmt.FieldAssign (expr_eo, expr_f, expr_ev)]


and compile_fielddelete (expr : E_Expr.t) (field : E_Expr.t) : Stmt.t list =
  let stmts_expr, expr' = compile_expr expr in
  let stmts_field, field' = compile_expr field in
  stmts_expr @ stmts_field @ [Stmt.FieldDelete (expr', field')]


and compile_exprstmt (expr : E_Expr.t) : Stmt.t list =
  let stmts_expr, _ = compile_expr expr in
  stmts_expr


and compile_repeatuntil (stmt : E_Stmt.t) (expr : E_Expr.t) : Stmt.t list =
  let stmts_stmt = compile_stmt stmt in
  let stmts_expr, expr' = compile_expr expr in
  let stmts = stmts_stmt @ stmts_expr in
  stmts @ [Stmt.While (expr', Stmt.Block stmts)]


and compile_patv (expr: Expr.t) (pname : string) (pat_v : E_Pat_v.t) (var_b : string) : string list * Stmt.t list * Stmt.t list =
  match pat_v with
  | PatVar v -> ([], [], [Stmt.AssignAccess (v, expr, Expr.Val (Val.Str pname))])
  | PatVal v -> (let b = generate_fresh_var () in
                 let w = generate_fresh_var () in
                 let stmt = Stmt.AssignAccess (w, expr, Expr.Val (Val.Str pname)) in
                 let stmt_assign = Stmt.Assign (b, Expr.BinOpt (Oper.Equal, Expr.Var w, Expr.Val v)) in
                 [b], [stmt; stmt_assign], [])
  | PatNone  -> (let stmt = Stmt.Assign (var_b, Expr.UnOpt (Oper.Not, Expr.Var var_b)) in
                 [], [stmt], [])


and compile_pn_pat (expr: Expr.t) (pn, patv : string * E_Pat_v.t) : string list * Stmt.t list * Stmt.t list =
  let fresh_b = generate_fresh_var () in
  let in_stmt = Stmt.AssignInObjCheck (fresh_b, Expr.Val (Val.Str pn), expr) in
  let bs, stmts, stmts' = compile_patv expr pn patv fresh_b in
  fresh_b :: bs, in_stmt :: stmts, stmts'


and compile_pat (expr : Expr.t) (e_pat : E_Pat.t) : string list * Stmt.t list * Stmt.t list =
  match e_pat with
  | DefaultPat     -> [], [], []
  | ObjPat pn_pats -> (let bs, pre_stmts, in_stmts =
                         List.fold_left (
                           fun (bs, pre_stmts, in_stmts) pn_pat ->
                             let bs', pre_stmts', in_stmts' = compile_pn_pat expr pn_pat in
                             (bs @ bs', pre_stmts @ pre_stmts', in_stmts @ in_stmts')
                         ) ([],[],[]) pn_pats in
                       bs, pre_stmts, in_stmts)


and compile_pats_stmts (expr : Expr.t) (pat, stmt : E_Pat.t * E_Stmt.t) : Stmt.t list * Expr.t * Stmt.t list =
  let bs, pre_pat_stmts, in_pat_stmts = compile_pat expr pat in
  let stmts = compile_stmt stmt in
  let and_bs = Expr.NOpt (Oper.NAry_And, Expr.Val (Val.Bool true) :: List.map (fun b -> Expr.Var b) bs) in
  let if_stmt = in_pat_stmts @ stmts in
  pre_pat_stmts, and_bs, if_stmt


and compile_matchwith (expr : E_Expr.t) (pats_stmts : (E_Pat.t * E_Stmt.t) list) : Stmt.t list =
  let stmts_expr, expr' = compile_expr expr in
  let pat_stmts_bs_stmts_list = List.rev (List.map (compile_pats_stmts expr') pats_stmts) in
  let chained_ifs = match pat_stmts_bs_stmts_list with
    | []                                -> []
    | (pat_stmts, bs_expr, stmts)::rest -> (let last_if = pat_stmts @ [Stmt.If (bs_expr, Stmt.Block stmts, None)] in
                                            List.fold_left (fun acc (ps, be, ss) ->
                                                ps @ [Stmt.If (be, Stmt.Block ss, Some (Stmt.Block acc))]) last_if rest
                                           ) in
  stmts_expr @ chained_ifs


and compile_expr (e_expr : E_Expr.t) : Stmt.t list * Expr.t =
  match e_expr with
  | Val e_v                   -> [], Expr.Val e_v
  | Var e_v                   -> [], Expr.Var e_v
  | BinOpt (e_op, e_e1, e_e2) -> compile_binopt e_op e_e1 e_e2
  | UnOpt (op, e_e)           -> compile_unopt op e_e
  | NOpt (op, e_es)           -> compile_nopt op e_es
  | Call (f, e_es)            -> compile_call f e_es
  | NewObj (e_fes)            -> compile_newobj e_fes
  | Access (e_e, e_f)         -> compile_access e_e e_f


and compile_stmt (e_stmt : E_Stmt.t) : Stmt.t list =
  match e_stmt with
  | Skip                            -> [Stmt.Skip]
  | Assign (v, e_exp)               -> compile_assign v e_exp
  | Block (e_stmts)                 -> compile_block e_stmts
  | If (e_e, e_s1, e_s2)            -> compile_if e_e e_s1 e_s2
  | While (e_exp, e_s)              -> compile_while e_exp e_s
  | Return e_exp                    -> compile_return e_exp
  | FieldAssign (e_eo, e_f, e_ev)   -> compile_fieldassign e_eo e_f e_ev
  | FieldDelete (e_e, e_f)          -> compile_fielddelete e_e e_f
  | ExprStmt e_e                    -> compile_exprstmt e_e
  | RepeatUntil (e_s, e_e)          -> compile_repeatuntil e_s e_e
  | MatchWith (e_e, e_pats_e_stmts) -> compile_matchwith e_e e_pats_e_stmts


let compile_func (e_func : E_Func.t) : Func.t =
  let fname = E_Func.get_name e_func in
  let fparams = E_Func.get_params e_func in
  let fbody = E_Func.get_body e_func in
  let stmt_list = compile_stmt fbody in
  Func.create fname fparams (Stmt.Block stmt_list)


let compile_prog (e_prog : E_Prog.t) : Prog.t =
  let funcs = Hashtbl.fold (fun fname func acc -> acc @ [compile_func func]) e_prog [] in
  Prog.create funcs
