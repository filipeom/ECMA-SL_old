(* parser-specification file *)

(*
  BEGIN first section - declarations
  - token and type specifications, precedence directives and other output directives
*)
%token SKIP
%token DEFEQ
%token WHILE
%token IF ELSE
%token RETURN
%token FUNCTION
%token LPAREN RPAREN
%token LBRACE RBRACE
%token LBRACK RBRACK
%token PERIOD COMMA SEMICOLON COLON
%token DELETE
%token REPEAT UNTIL
%token MATCH WITH PIPE RIGHT_ARROW NONE DEFAULT
%token <float> FLOAT
%token <int> INT
%token <bool> BOOLEAN
%token <string> VAR
%token <string> STRING
%token LAND LOR
%token PLUS MINUS TIMES DIVIDE EQUAL GT LT EGT ELT IN NOT
%token EOF

%left LAND LOR
%left GT LT EGT ELT IN
%left PLUS MINUS
%left TIMES DIVIDE
%left EQUAL
%left SEMICOLON

%nonassoc binopt_prec
%nonassoc unopt_prec

%type <E_Expr.t> e_prog_e_expr_target
%type <E_Stmt.t> e_prog_e_stmt_target
%type <E_Prog.t> e_prog_target

%start e_prog_target e_prog_e_expr_target e_prog_e_stmt_target
%% (* separator line *)
(* END first section - declarations *)

(*
  BEGIN - second section - grammar and rules
  - specifying the grammar of the language to be parsed, specifying the productions
  - productions are organized into rules, where each rule lists all
    the possible productions for a given nonterminal.
*)

e_prog_e_expr_target:
  | e = e_expr_target; EOF; { e }

e_prog_e_stmt_target:
  | s = e_stmt_target; EOF; { s }

e_prog_target:
  | funcs = separated_list (SEMICOLON, proc_target); EOF;
   { E_Prog.create funcs }

proc_target:
  | FUNCTION; f = VAR; LPAREN; vars = separated_list (COMMA, VAR); RPAREN; LBRACE; s = e_stmt_target; RBRACE
   { E_Func.create f vars s }

(*
  The pipes separate the individual productions, and the curly braces contain a semantic action:
    OCaml code that generates the OCaml value corresponding to the production in question.
  Semantic actions are arbitrary OCaml expressions that are evaluated during parsing
    to produce values that are attached to the nonterminal in the rule.
*)

(* v ::= f | i | b | s *)
val_target:
  | f = FLOAT;
    { Val.Flt f }
  | i = INT;
    { Val.Int i }
  | b = BOOLEAN;
    { Val.Bool b }
  | s = STRING;
    { let len = String.length s in
      let sub = String.sub s 1 (len - 2) in
      Val.Str sub } (* Remove the double-quote characters from the parsed string *)

(* e ::= {} | {f:e} | [] | [e] | e.f | e[f] | v | x | -e | e+e | f(e) | (e) *)
e_expr_target:
  | LBRACE; fes = separated_list (COMMA, fv_target); RBRACE;
    { E_Expr.NewObj (fes) }
  | LBRACK; es = separated_list (COMMA, e_expr_target); RBRACK;
    { E_Expr.NOpt (Oper.ListExpr, es) }
  | e = e_expr_target; PERIOD; f = VAR;
    { E_Expr.Access (e, E_Expr.Val (Str f)) }
  | e = e_expr_target; LBRACK; f = e_expr_target; RBRACK;
    { E_Expr.Access (e, f) }
  | v = val_target;
    { E_Expr.Val v }
  | v = VAR;
    { E_Expr.Var v }
  | MINUS; e = e_expr_target;
    { E_Expr.UnOpt (Oper.Neg, e) } %prec unopt_prec
  | NOT; e = e_expr_target;
    { E_Expr.UnOpt (Oper.Not, e) } %prec unopt_prec
  | e1 = e_expr_target; bop = op_target; e2 = e_expr_target;
    { E_Expr.BinOpt (bop, e1, e2) } %prec binopt_prec
  | f = e_expr_target; LPAREN; es = separated_list (COMMA, e_expr_target); RPAREN;
    { E_Expr.Call (f, es) }
  | LPAREN; e = e_expr_target; RPAREN;
    { e }

fv_target:
  | f = VAR; COLON; e = e_expr_target;
    { (f, e) }

(* s ::= e.f := e | delete e.f | skip | x := e | s1; s2 | if (e) { s1 } else { s2 } | while (e) { s } | return e | return | repeat s until e*)
e_stmt_target:
  | e1 = e_expr_target; PERIOD; f = VAR; DEFEQ; e2 = e_expr_target;
    { E_Stmt.FieldAssign (e1, E_Expr.Val (Str f), e2) }
  | e1 = e_expr_target; LBRACK; f = e_expr_target; RBRACK; DEFEQ; e2 = e_expr_target;
    { E_Stmt.FieldAssign (e1, f, e2) }
  | DELETE; e = e_expr_target; PERIOD; f = VAR;
    { E_Stmt.FieldDelete (e, E_Expr.Val (Str f)) }
  | DELETE; e = e_expr_target; LBRACK; f = e_expr_target; RBRACK;
    { E_Stmt.FieldDelete (e, f) }
  | SKIP;
    { E_Stmt.Skip }
  | v = VAR; DEFEQ; e = e_expr_target;
    { E_Stmt.Assign (v, e) }
  | s1 = e_stmt_target; SEMICOLON; s2 = e_stmt_target;
    { E_Stmt.Seq (s1, s2) }
  | exps_stmts = ifelse_target;
    { exps_stmts }
  | WHILE; LPAREN; e = e_expr_target; RPAREN; LBRACE; s = e_stmt_target; RBRACE;
    { E_Stmt.While (e, s) }
  | RETURN; e = e_expr_target;
    { E_Stmt.Return e }
  | e = e_expr_target;
    { E_Stmt.ExprStmt e }
  | REPEAT; s = e_stmt_target;
    { E_Stmt.RepeatUntil (s, E_Expr.Val (Val.Bool true)) }
  | REPEAT; s = e_stmt_target; UNTIL; e = e_expr_target;
    { E_Stmt.RepeatUntil (s, e) }
  | MATCH; e = e_expr_target; WITH; PIPE; pat_stmts = separated_list (PIPE, pat_stmt_target);
    { E_Stmt.MatchWith (e, pat_stmts) }

(* if (e) { s } | if (e) {s} else { s } *)
ifelse_target:
  | IF; LPAREN; e = e_expr_target; RPAREN; LBRACE; s1 = e_stmt_target; RBRACE; ELSE; LBRACE; s2 = e_stmt_target; RBRACE;
    { E_Stmt.If (e, s1, Some s2) }
  | IF; LPAREN; e = e_expr_target; RPAREN; LBRACE; s = e_stmt_target; RBRACE;
    { E_Stmt.If (e, s, None) }

(* { p: v | "x" ! None } -> s | default -> s *)
pat_stmt_target:
  | p = e_pat_target; RIGHT_ARROW; s = e_stmt_target;
    { (p, s) }

e_pat_target:
  | LBRACE; pn_patv = separated_list (COMMA, e_pat_v_target); RBRACE;
    { E_Pat.ObjPat pn_patv }
  | DEFAULT;
    { E_Pat.DefaultPat }

e_pat_v_target:
  | pn = VAR; COLON; v = VAR;
    { (pn, E_Pat_v.PatVar v) }
  | pn = VAR; COLON; v = val_target;
    { (pn, E_Pat_v.PatVal v) }
  | pn = VAR; COLON; NONE;
    { (pn, E_Pat_v.PatNone) }

op_target:
  | MINUS   { Oper.Minus }
  | PLUS    { Oper.Plus }
  | TIMES   { Oper.Times }
  | DIVIDE  { Oper.Div }
  | EQUAL   { Oper.Equal }
  | GT      { Oper.Gt }
  | LT      { Oper.Lt }
  | EGT     { Oper.Egt }
  | ELT     { Oper.Elt }
  | LAND    { Oper.Log_And }
  | LOR     { Oper.Log_Or }
  | IN      { Oper.InObj }

