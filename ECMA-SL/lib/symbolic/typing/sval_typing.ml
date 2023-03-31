open Val
open Args_typing_unop
open Args_typing_binop

let type_of_val (v : Val.t) : Type.t option =
  match v with
  | Void -> None
  | Null -> Some Type.NullType
  | Int _ -> Some Type.IntType
  | Flt _ -> Some Type.FltType
  | Bool _ -> Some Type.BoolType
  | Str _ -> Some Type.StrType
  | Loc _ -> Some Type.LocType
  | List _ -> Some Type.ListType
  | Arr _ -> Some Type.ArrayType
  | Tuple _ -> Some Type.TupleType
  | Curry _ -> Some Type.CurryType
  | Byte _ -> Some Type.IntType
  | Type _ -> Some Type.TypeType
  | Symbol _ -> Some Type.SymbolType

let type_of_unop (op : Operators.uopt) (arg_t : Type.t option) : Type.t option =
  match op with
  | Operators.Neg -> un_args_typing_neg arg_t
  | Operators.Not -> un_args_typing_not arg_t
  | Operators.Head -> None
  | Operators.Tail -> None
  | Operators.First -> None
  | Operators.Second -> None
  | Operators.ListLen -> un_args_typing_container_length arg_t Type.ListType
  | Operators.TupleLen -> un_args_typing_container_length arg_t Type.TupleType
  | Operators.IntToFloat -> un_args_typing_int_casts arg_t Type.FltType
  | Operators.IntToString -> un_args_typing_int_casts arg_t Type.StrType
  | Operators.FloatToString -> un_args_typing_float_casts arg_t Type.StrType
  | Operators.Typeof -> un_args_typing_typeof arg_t
  | Operators.Sconcat -> un_args_typing_sconcat arg_t
  | Operators.Exp -> un_args_typing_float_math arg_t Type.FltType
  | Operators.Log_e -> un_args_typing_float_math arg_t Type.FltType
  | Operators.Log_10 -> un_args_typing_float_math arg_t Type.FltType
  | Operators.Sqrt -> un_args_typing_float_math arg_t Type.FltType
  | Operators.IsNaN -> un_args_typing_float_math arg_t Type.BoolType
  | Operators.StringLen -> Some Type.IntType
  | default ->
      failwith
        ("Typing Error: [type_of_unop] -> unsuported typing for unary \
          operation " ^ Operators.str_of_unopt op)

let type_of_binop (op : Operators.bopt) (arg1_t : Type.t option)
    (arg2_t : Type.t option) : Type.t option =
  match op with
  | Operators.Plus -> bin_args_typing_arith arg1_t arg2_t
  | Operators.Minus -> bin_args_typing_arith arg1_t arg2_t
  | Operators.Times -> bin_args_typing_arith arg1_t arg2_t
  | Operators.Div -> bin_args_typing_arith arg1_t arg2_t
  | Operators.Modulo -> bin_args_typing_arith arg1_t arg2_t
  | Operators.Eq -> bin_args_typing_eq arg1_t arg2_t
  | Operators.Lt -> bin_args_typing_comp arg1_t arg2_t
  | Operators.Gt -> bin_args_typing_comp arg1_t arg2_t
  | Operators.Le -> bin_args_typing_comp arg1_t arg2_t
  | Operators.Ge -> bin_args_typing_comp arg1_t arg2_t
  | Operators.Log_And -> bin_args_typing_logic arg1_t arg2_t
  | Operators.Log_Or -> bin_args_typing_logic arg1_t arg2_t
  | Operators.Tnth -> None
  | Operators.Lnth -> None
  | Operators.InList -> bin_args_typing_inlist arg1_t
  | Operators.Lprepend -> None
  | Operators.Ladd -> None
  | Operators.Pow -> bin_args_typing_pow arg1_t arg2_t
  | Operators.Snth -> Some Type.StrType
  | default ->
      failwith
        ("Typing Error: [type_of_binop] -> unsuported typing for binary \
          operation "
        ^ Operators.str_of_binopt_single op)

let type_of_triop (op : Operators.topt) (arg1_t : Type.t option)
    (arg2_t : Type.t option) (arg3_t : Type.t option) : Type.t option =

  match op with
  | Operators.Ssubstr -> Some Type.StrType
  | default ->
    failwith
      ("Typing Error: [type_of_binop] -> unsuported typing for binary \
        operation ") 


let rec type_of (v : Expr.t) : Type.t option =
  match v with
  | Expr.Val v -> type_of_val v
  | Expr.UnOpt (op, arg) ->
      let arg_t = type_of arg in
      type_of_unop op arg_t
  | Expr.BinOpt (op, arg1, arg2) ->
      let arg1_t = type_of arg1 and arg2_t = type_of arg2 in
      type_of_binop op arg1_t arg2_t
  | Expr.TriOpt (op, arg1, arg2, arg3) ->
    let arg1_t = type_of arg1 and arg2_t = type_of arg2 and arg3_t = type_of arg3 in
    type_of_triop op arg1_t arg2_t arg3_t
  | Expr.Symbolic (t, _) -> Some t
  | _ -> failwith (Expr.str v ^ ": Not typed!")
