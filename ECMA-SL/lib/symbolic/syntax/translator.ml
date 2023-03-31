open Encoding
open Expression
open Types

exception TODO

let expr_of_value (e : Expression.value) : Expr.t =
  match e with
  | Int i -> Expr.Val (Val.Int i)
  | Str s -> Expr.Val (Val.Str s)
  | Num (Types.F64 f) -> Expr.Val (Val.Flt (Int64.float_of_bits f))
  | _ -> assert false

let translate_binop (t1 : Type.t option) (t2 : Type.t option) (op : Operators.bopt)
    (e1 : Expression.t) (e2 : Expression.t) : Expression.t =
  let open Type in
  let open Operators in
  match (t1, t2, op) with
  (* Integer operations *)
  | Some IntType, Some IntType,  Eq -> Relop (Int I.Eq, e1, e2)
  | Some IntType, Some IntType,  Gt -> Relop (Int I.Gt, e1, e2)
  | Some IntType, Some IntType,  Ge -> Relop (Int I.Ge, e1, e2)
  | Some IntType, Some IntType,  Lt -> Relop (Int I.Lt, e1, e2)
  | Some IntType, Some IntType,  Le -> Relop (Int I.Le, e1, e2)
  | Some IntType, Some IntType,  Plus -> Binop (Int I.Add, e1, e2)
  | Some IntType, Some IntType,  Minus -> Binop (Int I.Sub, e1, e2)
  | Some IntType, Some IntType,  Times -> Binop (Int I.Mul, e1, e2)
  | Some IntType, Some IntType,  Div -> Binop (Int I.Div, e1, e2)
  | Some IntType, Some IntType,  BitwiseAnd -> Binop (Int I.And, e1, e2)
  | Some IntType, Some IntType,  BitwiseOr -> Binop (Int I.Or, e1, e2)
  | Some IntType, Some IntType,  BitwiseXor -> Binop (Int I.Xor, e1, e2)
  | Some IntType, Some IntType,  ShiftLeft -> Binop (Int I.Shl, e1, e2)
  | Some IntType, Some IntType,  ShiftRight -> Binop (Int I.ShrA, e1, e2)
  | Some IntType, Some IntType,  ShiftRightLogical -> Binop (Int I.ShrL, e1, e2)
  | Some IntType, Some IntType,  Modulo -> Binop (Int I.Rem, e1, e2)
  (* Float operations *)
  | Some FltType, Some FltType,  Eq -> Relop (F64 F64.Eq, e1, e2)
  | Some FltType, Some FltType,  Gt -> Relop (F64 F64.Gt, e1, e2)
  | Some FltType, Some FltType,  Ge -> Relop (F64 F64.Ge, e1, e2)
  | Some FltType, Some FltType,  Lt -> Relop (F64 F64.Lt, e1, e2)
  | Some FltType, Some FltType,  Le -> Relop (F64 F64.Le, e1, e2)
  | Some FltType, Some FltType,  Plus -> Binop (F64 F64.Add, e1, e2)
  | Some FltType, Some FltType,  Minus -> Binop (F64 F64.Sub, e1, e2)
  | Some FltType, Some FltType,  Times -> Binop (F64 F64.Mul, e1, e2)
  | Some FltType, Some FltType,  Div -> Binop (F64 F64.Div, e1, e2)
  | Some FltType, Some FltType,  Min -> Binop (F64 F64.Min, e1, e2)
  | Some FltType, Some FltType,  Max -> Binop (F64 F64.Max, e1, e2)
  (* Bool operations *)
  | Some BoolType, Some BoolType, Log_And -> Binop (Bool B.And, e1, e2)
  | Some BoolType, Some BoolType, Log_Or -> Binop (Bool B.Or, e1, e2)
  (* String operations *)
  | Some StrType, Some IntType, Snth -> Binop (Str S.Nth, e1, e2)
  | Some StrType, Some StrType, Eq -> Relop (Str S.Eq, e1, e2)
  (* Defaults *)
  | None, _, _ -> assert false
  | _, _, _ ->
      print_endline (Type.str (Option.get t1));
      raise TODO

let translate_triop (t1 : Type.t option) (t2 : Type.t option) (t3 : Type.t option) 
    (op : Operators.topt) (e1 : Expression.t) (e2 : Expression.t) (e3 : Expression.t)=
  let open Type in
  match (t1, t2, t3, op) with
  | Some StrType, Some IntType, Some IntType, s_substr -> Triop (Str S.SubStr, e1, e2, e3)
  | _, _, _, _ ->
    print_endline (Type.str (Option.get t1));
    raise TODO


let translate_unop (t : Type.t option) (op : Operators.uopt) (e : Expression.t)
    : Expression.t =
  let open Type in
  let open Operators in
  match (t, op) with
  (* Float Operations *)
  | Some FltType, Neg -> Unop (F64 F64.Neg, e)
  | Some FltType, Abs -> Unop (F64 F64.Abs, e)
  | Some FltType, Sqrt -> Unop (F64 F64.Sqrt, e)
  (* Int Operations *)
  | Some IntType, Neg -> Unop (Int I.Neg, e)
  (* String Operations *)
  | Some StrType, StringLen -> Unop (Str S.Len, e)
  (* Bool Operations *)
  | Some BoolType, Not -> Unop (Bool B.Not, e)
  (* Defaults*)
  | _, _ ->
      print_endline (Type.str (Option.get t));
      raise TODO

let rec translate (e : Expr.t) : Expression.t =
  try
    match e with
    | Expr.Val (Val.Int i) -> Val (Int i)
    | Expr.Val (Val.Str s) -> Val (Str s)
    | Expr.Val (Val.Bool b) -> Val (Bool b)
    | Expr.Val (Val.Flt f) -> Val (Num (F64 (Int64.bits_of_float f)))
    | Expr.Symbolic (Type.IntType, Expr.Val (Val.Str x)) ->
        Symbolic (`IntType, x)
    | Expr.Symbolic (Type.StrType, Expr.Val (Val.Str x)) ->
        Symbolic (`StrType, x)
    | Expr.Symbolic (Type.BoolType, Expr.Val (Val.Str x)) ->
        Symbolic (`BoolType, x)
    | Expr.Symbolic (Type.FltType, Expr.Val (Val.Str x)) ->
        Symbolic (`IntType, x)
    | Expr.UnOpt (op, e) ->
        let ty = Sval_typing.type_of e in
        let e' = translate e in
        translate_unop ty op e'
    | Expr.BinOpt (op, e1, e2) ->
        let ty1 = Sval_typing.type_of e1 in
        let ty2 = Sval_typing.type_of e2 in
        let e1' = translate e1 and e2' = translate e2 in
        translate_binop ty1 ty2 op e1' e2'
    | Expr.TriOpt (op, e1, e2, e3) -> 
        let ty1 = Sval_typing.type_of e1 in
        let ty2 = Sval_typing.type_of e2 in
        let ty3 = Sval_typing.type_of e3 in
        let e1' = translate e1 and e2' = translate e2 and e3' = translate e3 in
        translate_triop ty1 ty2 ty3 op e1' e2' e3'
    | _ -> failwith (Expr.str e ^ ": Not translated!")
  with TODO -> failwith (Expr.str e ^ ": Not translated!")
