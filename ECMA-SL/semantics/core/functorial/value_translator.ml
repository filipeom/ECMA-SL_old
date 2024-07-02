open EslSyntax
open Smtml
open Ty
open Expr
open Value

let expr_of_value : Expr.expr -> Symbolic_value.M.value =
  let open Symbolic_value.M in
  function
  | Val (Int x) -> Val (Int x)
  | Val (Str x) -> Val (Str x)
  | Val (Real x) -> Val (Flt x)
  | _ -> assert false

let translate_val (v : Val.t) : Expr.t =
  match v with
  | Int x -> value (Int x)
  | Flt x -> value (Real x)
  | Str x -> value (Str x)
  | Bool x -> value (if x then True else False)
  | Loc x -> value (Str (Loc.str x))
  | _ -> Log.err "translate_val: unsupported value '%a'" Val.pp v

let translate_symbol (t : Type.t) (x : string) : Expr.t =
  match t with
  | Type.IntType -> mk_symbol (Symbol.make Ty_int x)
  | Type.FltType -> mk_symbol (Symbol.make Ty_real x)
  | Type.StrType -> mk_symbol (Symbol.make Ty_str x)
  | Type.BoolType -> mk_symbol (Symbol.make Ty_bool x)
  | _ -> Log.err "translate_symbol: unsupported symbol type '%a'" Type.pp t

let of_type =
  let open Type in
  function
  | Some IntType -> Ty_int
  | Some FltType -> Ty_real
  | Some StrType -> Ty_str
  | Some BoolType -> Ty_bool
  | None | _ -> Log.err "of_type: no type@."

let translate_unop (t : Type.t option) (op : Operator.unopt) (e : Expr.t) :
  Expr.t =
  let open Operator in
  match op with
  | Neg -> unop (of_type t) Neg e
  | Abs -> unop Ty_real Abs e
  | Sqrt -> unop Ty_real Sqrt e
  | IsNaN -> value False
  | Ceil -> unop Ty_real Ceil e
  | Floor -> unop Ty_real Floor e
  | IntToFloat -> cvtop Ty_real Reinterpret_int e
  | IntToString -> cvtop Ty_str String_from_int e
  | FloatToString -> cvtop Ty_real ToString e
  | StringToFloat -> cvtop Ty_real OfString e
  | FloatToInt -> cvtop Ty_int Reinterpret_float e
  | ToInt | ToUint32 -> unop Ty_real Trunc e
  | StringLen | StringLenU -> unop Ty_str Length e
  | Trim -> unop Ty_str Trim e
  | ToCharCode | ToCharCodeU -> cvtop Ty_str String_to_code e
  | StringToInt -> cvtop Ty_str String_to_int e
  | LogicalNot -> Expr.Bool.not e
  | _ ->
    Log.err "translate_unop: unsupported operator '%a'!"
      Operator.pp_of_unopt_single op

let translate_binop (t1 : Type.t option) (t2 : Type.t option)
  (op : Operator.binopt) (e1 : Expr.t) (e2 : Expr.t) : Expr.t =
  let open Type in
  let open Operator in
  let int_binop (op : Operator.binopt) e1 e2 =
    match op with
    | Eq -> relop Ty_bool Eq e1 e2
    | Gt -> relop Ty_int Gt e1 e2
    | Ge -> relop Ty_int Ge e1 e2
    | Lt -> relop Ty_int Lt e1 e2
    | Le -> relop Ty_int Le e1 e2
    | Plus -> binop Ty_int Add e1 e2
    | Minus -> binop Ty_int Sub e1 e2
    | Times -> binop Ty_int Mul e1 e2
    | Div -> binop Ty_int Div e1 e2
    | _ -> Log.err "int binop: %a@." Operator.pp_of_binopt_single op
  in
  let flt_binop op e1 e2 =
    match op with
    | Modulo -> assert false
    | Eq -> relop Ty_bool Eq e1 e2
    | Gt -> relop Ty_real Gt e1 e2
    | Ge -> relop Ty_real Ge e1 e2
    | Lt -> relop Ty_real Lt e1 e2
    | Le -> relop Ty_real Le e1 e2
    | Plus -> binop Ty_real Add e1 e2
    | Minus -> binop Ty_real Sub e1 e2
    | Times -> binop Ty_real Mul e1 e2
    | Div -> binop Ty_real Div e1 e2
    | Min -> binop Ty_real Min e1 e2
    | Max -> binop Ty_real Max e1 e2
    | _ -> Log.err "real binop: %a@." Operator.pp_of_binopt_single op
  in
  let str_binop op e1 e2 =
    match op with
    | StringNth | StringNthU -> binop Ty_str At e1 e2
    | Eq -> relop Ty_bool Eq e1 e2
    | _ -> Log.err "str binop: %a@." Operator.pp_of_binopt_single op
  in
  let bool_binop (op : Operator.binopt) e1 e2 =
    match op with
    | Eq -> relop Ty_bool Eq e1 e2
    | LogicalAnd -> binop Ty_bool And e1 e2
    | LogicalOr -> binop Ty_bool Or e1 e2
    | _ -> Log.err "bool binop: %a@." Operator.pp_of_binopt_single op
  in
  match (t1, t2) with
  | (Some IntType, Some IntType) -> int_binop op e1 e2
  | (Some FltType, Some FltType) -> flt_binop op e1 e2
  | (Some StrType, _) -> str_binop op e1 e2
  | (Some BoolType, Some BoolType) -> bool_binop op e1 e2
  | (None, _) | (_, None) -> Log.err "translate_binop: untyped operator!"
  | _ ->
    Log.err "translate_binop: ill-typed or unsupported operator: (%a, %a, %a)"
      Operator.pp_of_binopt_single op Expr.pp e1 Expr.pp e2

let translate_triop (t1 : Type.t option) (t2 : Type.t option)
  (t3 : Type.t option) (op : Operator.triopt) (e1 : Expr.t) (e2 : Expr.t)
  (e3 : Expr.t) =
  let open Type in
  let open Operator in
  let str_triop (op : Operator.triopt) e1 e2 e3 =
    match op with
    | StringSubstrU | StringSubstr -> Expr.triop Ty_str String_extract e1 e2 e3
    | _ -> assert false
  in
  let bool_triop (op : Operator.triopt) e1 e2 e3 =
    match op with ITE -> triop Ty_bool Ite e1 e2 e3 | _ -> assert false
  in
  match (t1, t2, t3) with
  | (Some BoolType, _, _) -> bool_triop op e1 e2 e3
  | (Some StrType, _, _) -> str_triop op e1 e2 e3
  | (None, _, _) | (_, None, _) | (_, _, None) ->
    Log.err "translate_triop: untyped operator! %s"
      (Operator.str_of_triopt Format.pp_print_string op "e1" "e2" "e3")
  | _ -> Log.err "translate_triop: ill-typed or unsupported operator!"

let rec translate (v : Symbolic_value.M.value) : Expr.t =
  let open Symbolic_value.M in
  match v with
  | Val v -> translate_val v
  | Symbolic (t, Val (Val.Str x)) -> translate_symbol t x
  | UnOpt (Operator.StringConcat, e) -> (
    match e with
    | NOpt (_, es) -> Expr.naryop Ty_str Concat (List.map translate es)
    | _ -> assert false )
  | UnOpt (op, e') ->
    let ty = Value_typing.type_of e' in
    let e' = translate e' in
    translate_unop ty op e'
  | BinOpt (op, e1, e2) ->
    let ty1 = Value_typing.type_of e1 in
    let ty2 = Value_typing.type_of e2 in
    let e1' = translate e1
    and e2' = translate e2 in
    translate_binop ty1 ty2 op e1' e2'
  | TriOpt (op, e1, e2, e3) ->
    let ty1 = Value_typing.type_of e1 in
    let ty2 = Value_typing.type_of e2 in
    let ty3 = Value_typing.type_of e3 in
    let e1' = translate e1
    and e2' = translate e2
    and e3' = translate e3 in
    translate_triop ty1 ty2 ty3 op e1' e2' e3'
  | _ -> Log.err "%a: Not translated!" pp v
