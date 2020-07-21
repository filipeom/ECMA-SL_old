type t = Skip
       | Assign       of string * Expr.t
       | Seq          of t list
       | If           of Expr.t * t * t option
       | While        of Expr.t * t
       | Return       of Expr.t
       | FieldAssign  of Expr.t * Expr.t * Expr.t
       | FieldDelete  of Expr.t * Expr.t
       | AssignCall   of string * Expr.t * Expr.t list
       | AssignNewObj of string
       | AssignAccess of string * Expr.t * Expr.t
       | AssignInObjCheck of string * Expr.t * Expr.t
       | Block of t list

(*---------------Strings------------------*)

let rec str (stmt : t) : string = match stmt with
    Skip                        -> ""
  | Assign (v, exp)             -> v ^ " = " ^ (Expr.str exp)
  | Seq stmts                   -> List.fold_left (fun acc stmt -> acc ^ "; " ^ str stmt) "" stmts
  | If (e, s1, s2)              -> (let v = "if (" ^ Expr.str e ^ ") { " ^ str s1 ^ " }" in
                                    match s2 with
                                    | None   -> v
                                    | Some s -> v ^ " else { " ^ str s ^ " }" )
  | Block (block)               -> String.concat ", " (List.map (fun s -> str s) block)
  | While (exp, s)              -> "while (" ^ (Expr.str exp) ^ ") { " ^ (str s) ^ " }"
  | Return exp                  -> "return " ^ (Expr.str exp) ^ ";"
  | FieldAssign (e_o, f, e_v)   -> Expr.str e_o ^ "[" ^ Expr.str f ^ "] = " ^ Expr.str e_v
  | FieldDelete (e, f)          -> "delete " ^ Expr.str e ^ "[" ^ Expr.str f ^ "]"
  | AssignCall (va, st, e_lst)  -> va ^ " = " ^ Expr.str st ^ " (" ^ String.concat ", " (List.map (fun e -> Expr.str e) e_lst) ^ ")"
  | AssignNewObj va             -> va ^ " = { }"
  | AssignAccess (va, eo, p)    -> va ^ " = " ^ Expr.str eo ^ "[" ^ Expr.str p ^ "]"
  | AssignInObjCheck (st,e1,e2) -> st ^" "^Expr.str e1 ^ " in "^Expr.str e2


and build_ifelse (exp_stmt : Expr.t option * t) : string =
  match exp_stmt with
  | Some e, s -> "if (" ^ (Expr.str e) ^ ") { " ^ (str s) ^ " }"
  | None, s   -> "{ " ^ (str s) ^ " }"
