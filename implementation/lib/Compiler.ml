let make_fresh_var_generator (pref : string) : (unit -> string) =
  let count = ref 0 in
  fun () -> let x = !count in
    count := x+1; pref ^ (string_of_int x)


let generate_fresh_var = make_fresh_var_generator "___temp"


let rec compile_binopt (binop : Oper.bopt) (e_e1 : E_Expr.t) (e_e2 : E_Expr.t) : Stmt.t list * Expr.t =
  let stmts_1, e1 = compile_expr e_e1 in
  let stmts_2, e2 = compile_expr e_e2 in
  stmts_1 @ stmts_2, Expr.BinOpt (binop, e1, e2)


and compile_nopt (nop : Oper.nopt) (e_exprs : E_Expr.t list) : Stmt.t list * Expr.t =
  let stmts_exprs = List.map compile_expr e_exprs in
  let stmts, exprs = List.split stmts_exprs in
  List.concat stmts, Expr.NOpt (nop, exprs)


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
  List.concat stmts @ [newObj], Expr.Var var


and compile_assign (var : string) (e_exp : E_Expr.t) : Stmt.t list =
  let stmts, aux_var = compile_expr e_exp in
  stmts @ [Stmt.Assign (var, aux_var)]


and compile_fieldassign (e_eo : E_Expr.t) (e_f : E_Expr.t) (e_ev : E_Expr.t) : Stmt.t list =
  let stmts_eo, expr_eo = compile_expr e_eo in
  let stmts_f, expr_f = compile_expr e_f in
  let stmts_ev, expr_ev = compile_expr e_ev in
  stmts_eo @ stmts_f @ stmts_ev @ [Stmt.FieldAssign (expr_eo, expr_f, expr_ev)]


and compile_expr (e_expr : E_Expr.t) : Stmt.t list * Expr.t =
  match e_expr with
  | Val e_v                   -> [], Expr.Val e_v
  | Var e_v                   -> [], Expr.Var e_v
  | BinOpt (e_op, e_e1, e_e2) -> compile_binopt e_op e_e1 e_e2
  | UnOpt (op, e_e)           -> invalid_arg "Exception in Compile.compile_expr: UnOpt is not implemented"
  | NOpt (op, e_es)           -> compile_nopt op e_es
  | Call (f, e_es)            -> compile_call f e_es
  | NewObj (e_fes)            -> compile_newobj e_fes
  | Access (e_e, e_f)         -> invalid_arg "Exception in Compile.compile_expr: Access is not implemented"


let rec compile_stmt (e_stmt : E_Stmt.t) : Stmt.t list =
  match e_stmt with
  | Skip                            -> [Stmt.Skip]
  | Assign (v, e_exp)               -> compile_assign v e_exp
  | Seq (e_s1, e_s2)                -> compile_stmt e_s1 @ compile_stmt e_s2
  | If (e_exps_e_stmts)             -> invalid_arg "Exception in Compile.compile_stmt: If is not implemented"
  | While (e_exp, e_s)              -> invalid_arg "Exception in Compile.compile_stmt: While is not implemented"
  | Return e_exp                    -> invalid_arg "Exception in Compile.compile_stmt: Return is not implemented"
  | FieldAssign (e_eo, e_f, e_ev)   -> compile_fieldassign e_eo e_f e_ev
  | FieldDelete (e_e, e_f)          -> invalid_arg "Exception in Compile.compile_stmt: FieldDelete is not implemented"
  | ExprStmt e_e                    -> invalid_arg "Exception in Compile.compile_stmt: ExprStmt is not implemented"
  | RepeatUntil (e_s, e_e)          -> invalid_arg "Exception in Compile.compile_stmt: RepeatUntil is not implemented"
  | MatchWith (e_e, e_exps_e_stmts) -> invalid_arg "Exception in Compile.compile_stmt: MatchWith is not implemented"


let compile_func (e_func : E_Func.t) : Func.t =
  let fname = E_Func.get_name e_func and
    fparams = E_Func.get_params e_func and
    fbody = E_Func.get_body e_func in
  let stmt_list = compile_stmt fbody in
  Func.create fname fparams stmt_list


let compile_prog (e_prog : E_Prog.t) : Prog.t =
  let funcs = Hashtbl.fold (fun fname func acc -> acc @ [compile_func func]) e_prog [] in
  Prog.create funcs
