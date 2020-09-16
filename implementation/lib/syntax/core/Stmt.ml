type t = Skip
       | Print        of Expr.t
       | Assign       of string * Expr.t
       | If           of Expr.t * t * t option
       | While        of Expr.t * t
       | Return       of Expr.t
       | AssignCall   of string * Expr.t * Expr.t list
       | AssignNewObj of string
       | AssignInObjCheck of string * Expr.t * Expr.t
       | Block of t list
       | FieldAssign  of Expr.t * Expr.t * Expr.t
       | FieldDelete  of Expr.t * Expr.t
       | FieldLookup of string * Expr.t * Expr.t

(*---------------Strings------------------*)

let rec str (stmt : t) : string = match stmt with
    Skip                        -> ""
  | Print e                     -> "print " ^ (Expr.str e)
  | Assign (v, exp)             -> v ^ " := " ^ (Expr.str exp)
  | If (e, s1, s2)              -> (let v = "if (" ^ Expr.str e ^ ") {\n" ^ str s1 ^ "\n}" in
                                    match s2 with
                                    | None   -> v
                                    | Some s -> v ^ " else {\n" ^ str s ^ "\n}" )
  | Block (block)               -> String.concat ";\n" (List.map str block)
  | While (exp, s)              -> "while (" ^ (Expr.str exp) ^ ") { " ^ (str s) ^ " }"
  | Return exp                  -> "return " ^ (Expr.str exp)
  | FieldAssign (e_o, f, e_v)   -> Expr.str e_o ^ "[" ^ Expr.str f ^ "] := " ^ Expr.str e_v
  | FieldDelete (e, f)          -> "delete " ^ Expr.str e ^ "[" ^ Expr.str f ^ "]"
  | AssignCall (va, st, e_lst)  -> va ^ " := " ^ Expr.str st ^ " (" ^ String.concat ", " (List.map (fun e -> Expr.str e) e_lst) ^ ")"
  | AssignNewObj va             -> va ^ " := { }"
  | FieldLookup (va, eo, p)    -> va ^ " := " ^ Expr.str eo ^ "[" ^ Expr.str p ^ "]"
  | AssignInObjCheck (st,e1,e2) -> st ^ " := " ^ Expr.str e1 ^ " in_obj " ^ Expr.str e2

let rec to_json (stmt : t) : string = 
  match stmt with
  | Skip                        -> Printf.sprintf "{\"type\" : \"skip\"}"
  | Print e                     -> Printf.sprintf "{\"type\" : \"print\", \"args\" : [ %s ]}" (Expr.to_json e)
  | Assign (v, exp)             -> Printf.sprintf "{\"type\" : \"assign\", \"args\" : [ %s, %s ]}" v (Expr.to_json exp)
  | If (e, s1, s2)              -> Printf.sprintf "{\"type\" : \"condition\", \"args\" : [ %s, %s%s ]}" (Expr.to_json e) (to_json s1) (match s2 with
                                                                                                                                        | Some v -> Printf.sprintf ", %s" (to_json v)
                                                                                                                                        | None -> "")
  | Block (block)               -> Printf.sprintf "{\"type\" : \"block\", \"args\" : [ %s ]}" (String.concat ", " (List.map to_json block))
  | While (exp, s)              -> Printf.sprintf "{\"type\" : \"while\", \"args\" : [ %s, %s ]}" (Expr.to_json exp) (to_json s)
  | Return exp                  -> Printf.sprintf "{\"type\" : \"return\", \"args\" : [ %s ]}" (Expr.to_json exp)
  | FieldAssign (e_o, f, e_v)   -> Printf.sprintf "{\"type\" : \"fieldassign\", \"args\" : [ %s, %s, %s ]}" (Expr.to_json e_o) (Expr.to_json f) (Expr.to_json e_v)
  | FieldDelete (e, f)          -> Printf.sprintf "{\"type\" : \"fielddelete\", \"args\" : [ %s, %s ]}" (Expr.to_json e) (Expr.to_json f)
  | AssignCall (va, st, e_lst)  -> Printf.sprintf "{\"type\" : \"assigncall\", \"args\" : [ %s, %s, %s ]}" (va) (Expr.to_json st) (String.concat ", " (List.map Expr.to_json e_lst))
  | AssignNewObj va             -> Printf.sprintf "{\"type\" : \"assignnewobject\", \"args\" : [ %s ]}" (va)
  | FieldLookup (va, eo, p)     -> Printf.sprintf "{\"type\" : \"fieldlookup\", \"args\" : [ %s, %s, %s]}" (va) (Expr.to_json eo) (Expr.to_json p)
  | AssignInObjCheck (st,e1,e2) -> Printf.sprintf "{\"type\" : \"assigninobjcheck\", \"args\" : [ %s, %s, %s ]}" (st) (Expr.to_json e1) (Expr.to_json e2)
