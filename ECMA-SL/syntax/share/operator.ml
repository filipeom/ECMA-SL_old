open EslBase

type const =
  | MAX_VALUE
  | MIN_VALUE
  | PI

type unopt =
  (* General operators *)
  | Typeof
  (* Arithmetic operators *)
  | Neg
  (* Bitwise operators *)
  | BitwiseNot
  (* Logical *)
  | LogicalNot
  (* Integer operators *)
  | IntToFloat
  | IntToString
  (* Float operators *)
  | FloatToInt
  | FloatToString
  | ToInt32
  | ToUint16
  | ToUint32
  (* String operators *)
  | StringToInt
  | StringToFloat
  | FromCharCode
  | ToCharCode
  | StringLen
  | StringConcat
  (* Object operators *)
  | ObjectToList
  | ObjectFields
  (* List operators *)
  | ListHead
  | ListTail
  | ListLen
  | ListReverse
  (* Tuple operators *)
  | TupleFirst
  | TupleSecond
  | TupleLen
  (* Math operators *)
  | Random
  | Abs
  | Sqrt
  | Ceil
  | Floor
  | Trunc
  | Exp

type binopt =
  (* Arithmetic operators *)
  | Plus
  | Minus
  | Times
  | Div
  | Modulo
  | Pow
  (* Bitwise operators *)
  | BitwiseAnd
  | BitwiseOr
  | BitwiseXor
  | ShiftLeft
  | ShiftRight
  | ShiftRightLogical
  (* Logical operators *)
  | LogicalAnd
  | LogicalOr
  | SCLogicalAnd
  | SCLogicalOr
  (* Comparison operators *)
  | Eq
  | NE
  | Lt
  | Gt
  | Le
  | Ge
  (* Object operators *)
  | ObjectMem
  (* String operators *)
  | StringNth
  (* List operators *)
  | ListNth
  | ListAdd
  | ListPrepend
  | ListConcat
  (* Tuple operators *)
  | TupleNth
  (* Math operators *)
  | Min
  | Max

type triopt =
  (* General operators *)
  | ITE
  (* String operators *)
  | StringSubstr
  (* List operators *)
  | ListSet

type nopt =
  (* Logical operators *)
  | NAryLogicalAnd
  | NAryLogicalOr
  (* Array operators *)
  | ArrayExpr
  (* List operators *)
  | ListExpr
  (* Tuple operators *)
  | TupleExpr

let is_infix_unopt (op : unopt) : bool =
  match op with BitwiseNot | LogicalNot -> true | _ -> false

let is_infix_binopt (op : binopt) : bool =
  match op with
  | Plus | Minus | Times | Div | Modulo | Pow | BitwiseAnd | BitwiseOr
  | BitwiseXor | ShiftLeft | ShiftRight | ShiftRightLogical | LogicalAnd
  | LogicalOr | SCLogicalAnd | SCLogicalOr | Eq | NE | Lt | Gt | Le | Ge
  | ObjectMem ->
    true
  | _ -> false

let label_of_const (c : const) : string =
  match c with
  | MAX_VALUE -> "Const.MAX_VALUE"
  | MIN_VALUE -> "Const.MIN_VALUE"
  | PI -> "Const.PI"

let label_of_unopt (op : unopt) : string =
  match op with
  | Typeof -> "typeof"
  | Neg -> "Arith.neg (-)"
  | BitwiseNot -> "Bitwise.not (~)"
  | LogicalNot -> "Logical.not (!)"
  | IntToFloat -> "Integer.int_to_float"
  | IntToString -> "Integer.int_to_string"
  | FloatToInt -> "Float.float_to_int"
  | FloatToString -> "Float.float_to_string"
  | ToInt32 -> "Float.to_int32"
  | ToUint16 -> "Float.to_uint16"
  | ToUint32 -> "Float.to_uint32"
  | StringToInt -> "String.string_to_int"
  | StringToFloat -> "String.string_to_float"
  | FromCharCode -> "String.from_char_code"
  | ToCharCode -> "String.to_char_code_u"
  | StringLen -> "String.s_len"
  | StringConcat -> "String.s_concat"
  | ObjectToList -> "Object.obj_to_list"
  | ObjectFields -> "Object.obj_fields"
  | ListHead -> "List.hd"
  | ListTail -> "List.tl"
  | ListLen -> "List.l_len"
  | ListReverse -> "List.l_reverse"
  | TupleFirst -> "Tuple.fst"
  | TupleSecond -> "Tuple.snd"
  | TupleLen -> "Tup.t_len"
  | Random -> "Math.random"
  | Abs -> "Math.abs"
  | Sqrt -> "Math.sqrt"
  | Ceil -> "Math.ceil"
  | Floor -> "Math.floor"
  | Trunc -> "Math.trunc"
  | Exp -> "Math.exp"

let label_of_binopt (op : binopt) : string =
  match op with
  | Plus -> "Arith.plus (+)"
  | Minus -> "Arith.minus (-)"
  | Times -> "Arith.times (*)"
  | Div -> "Arith.div (/)"
  | Modulo -> "Arith.mod (%)"
  | Pow -> "Arith.pow (**)"
  | BitwiseAnd -> "Bitwise.and (&)"
  | BitwiseOr -> "Bitwise.or (|)"
  | BitwiseXor -> "Bitwise.xor (^)"
  | ShiftLeft -> "Bitwise.shift_left (<<)"
  | ShiftRight -> "Bitwise.shift_right (>>)"
  | ShiftRightLogical -> "Bitwise.shift_right_logical (>>>)"
  | LogicalAnd -> "Logical.and (&&)"
  | LogicalOr -> "Logical.or (||)"
  | SCLogicalAnd -> "Logical.sc_and (&&&)"
  | SCLogicalOr -> "Logical.sc_or (|||)"
  | Eq -> "Comp.eq (=)"
  | NE -> "Comp.ne (!=)"
  | Lt -> "Comp.lt (<)"
  | Gt -> "Comp.gt (>)"
  | Le -> "Comp.le (<=)"
  | Ge -> "Comp.ge (>=)"
  | ObjectMem -> "Object.in_obj"
  | StringNth -> "String.s_nth"
  | ListNth -> "List.l_nth"
  | ListAdd -> "List.l_add"
  | ListPrepend -> "List.l_prepend"
  | ListConcat -> "List.l_concat"
  | TupleNth -> "Tuple.t_nth"
  | Min -> "Math.min"
  | Max -> "Math.max"

let label_of_triopt (op : triopt) : string =
  match op with
  | ITE -> "IfThenElse"
  | StringSubstr -> "String.s_substr"
  | ListSet -> "List.l_set"

let label_of_nopt (op : nopt) : string =
  match op with
  | NAryLogicalAnd -> "Logical.nary_and"
  | NAryLogicalOr -> "Logical.nary_or"
  | ArrayExpr -> "Array.a_expr"
  | ListExpr -> "List.l_expr"
  | TupleExpr -> "Tuple.t_expr"

let pp_of_unopt_single (fmt : Fmt.t) (op : unopt) : unit =
  let open Fmt in
  match op with
  | Typeof -> pp_str fmt "typeof"
  | Neg -> pp_str fmt "-"
  | BitwiseNot -> pp_str fmt "~"
  | LogicalNot -> pp_str fmt "!"
  | IntToFloat -> pp_str fmt "int_to_float"
  | IntToString -> pp_str fmt "int_to_string"
  | FloatToInt -> pp_str fmt "int_of_float"
  | FloatToString -> pp_str fmt "float_to_string"
  | ToInt32 -> pp_str fmt "to_int32"
  | ToUint16 -> pp_str fmt "to_uint16"
  | ToUint32 -> pp_str fmt "to_uint32"
  | StringToInt -> pp_str fmt "int_of_string"
  | StringToFloat -> pp_str fmt "float_of_string"
  | FromCharCode -> pp_str fmt "from_char_code"
  | ToCharCode -> pp_str fmt "to_char_code"
  | StringLen -> pp_str fmt "s_len"
  | StringConcat -> pp_str fmt "s_concat"
  | ObjectToList -> pp_str fmt "obj_to_list"
  | ObjectFields -> pp_str fmt "obj_fields"
  | ListHead -> pp_str fmt "hd"
  | ListTail -> pp_str fmt "tl"
  | ListLen -> pp_str fmt "l_len"
  | ListReverse -> pp_str fmt "l_reverse"
  | TupleFirst -> pp_str fmt "fst"
  | TupleSecond -> pp_str fmt "snd"
  | TupleLen -> pp_str fmt "t_len"
  | Random -> pp_str fmt "random"
  | Abs -> pp_str fmt "abs"
  | Sqrt -> pp_str fmt "sqrt"
  | Ceil -> pp_str fmt "ceil"
  | Floor -> pp_str fmt "floor"
  | Trunc -> pp_str fmt "trunc"
  | Exp -> pp_str fmt "exp"
let pp_of_binopt_single (fmt : Fmt.t) (op : binopt) : unit =
  let open Fmt in
  match op with
  | Plus -> pp_str fmt "+"
  | Minus -> pp_str fmt "-"
  | Times -> pp_str fmt "*"
  | Div -> pp_str fmt "/"
  | Modulo -> fprintf fmt "%%"
  | Pow -> pp_str fmt "**"
  | BitwiseAnd -> pp_str fmt "&"
  | BitwiseOr -> pp_str fmt "|"
  | BitwiseXor -> pp_str fmt "^"
  | ShiftLeft -> pp_str fmt "<<"
  | ShiftRight -> pp_str fmt ">>"
  | ShiftRightLogical -> pp_str fmt ">>>"
  | LogicalAnd -> pp_str fmt "&&"
  | LogicalOr -> pp_str fmt "||"
  | SCLogicalAnd -> pp_str fmt "&&&"
  | SCLogicalOr -> pp_str fmt "|||"
  | Eq -> pp_str fmt "="
  | NE -> pp_str fmt "!="
  | Lt -> pp_str fmt "<"
  | Gt -> pp_str fmt ">"
  | Le -> pp_str fmt "<="
  | Ge -> pp_str fmt ">="
  | ObjectMem -> pp_str fmt "in_obj"
  | StringNth -> pp_str fmt "s_nth"
  | ListNth -> pp_str fmt "l_nth"
  | ListAdd -> pp_str fmt "l_add"
  | ListPrepend -> pp_str fmt "l_prepend"
  | ListConcat -> pp_str fmt "l_concat"
  | TupleNth -> pp_str fmt "t_nth"
  | Min -> pp_str fmt "min"
  | Max -> pp_str fmt "max"

let pp_of_triopt_single (fmt : Fmt.t) (op : triopt) : unit =
  let open Fmt in
  match op with
  | ITE -> pp_str fmt "ite"
  | StringSubstr -> pp_str fmt "s_substr"
  | ListSet -> pp_str fmt "l_set"

let pp_of_const (fmt : Fmt.t) (c : const) : unit =
  let open Fmt in
  match c with
  | MAX_VALUE -> pp_str fmt "MAX_VALUE"
  | MIN_VALUE -> pp_str fmt "MIN_VALUE"
  | PI -> pp_str fmt "PI"

let pp_of_unopt (pp_val : Fmt.t -> 'a -> unit) (fmt : Fmt.t)
  ((op, v) : unopt * 'a) : unit =
  if is_infix_unopt op then
    Fmt.fprintf fmt "%a%a" pp_of_unopt_single op pp_val v
  else Fmt.fprintf fmt "%a(%a)" pp_of_unopt_single op pp_val v

let pp_of_binopt (pp_val : Fmt.t -> 'a -> unit) (fmt : Fmt.t)
  ((op, v1, v2) : binopt * 'a * 'a) : unit =
  if is_infix_binopt op then
    Fmt.fprintf fmt "%a %a %a" pp_val v1 pp_of_binopt_single op pp_val v2
  else Fmt.fprintf fmt "%a(%a, %a)" pp_of_binopt_single op pp_val v1 pp_val v2

let pp_of_triopt (pp_val : Fmt.t -> 'a -> unit) (fmt : Fmt.t)
  ((op, v1, v2, v3) : triopt * 'a * 'a * 'a) : unit =
  Fmt.fprintf fmt "%a(%a, %a, %a)" pp_of_triopt_single op pp_val v1 pp_val v2
    pp_val v3

let pp_of_nopt (pp_val : Fmt.t -> 'a -> unit) (fmt : Fmt.t)
  ((op, vs) : nopt * 'a list) : unit =
  let open Fmt in
  match op with
  | NAryLogicalAnd -> fprintf fmt "%a" (pp_lst " && " pp_val) vs
  | NAryLogicalOr -> fprintf fmt "%a" (pp_lst " || " pp_val) vs
  | ArrayExpr -> fprintf fmt "[|%a|]" (pp_lst ", " pp_val) vs
  | ListExpr -> fprintf fmt "[%a]" (pp_lst ", " pp_val) vs
  | TupleExpr -> fprintf fmt "(%a)" (pp_lst ", " pp_val) vs

let str_of_unopt_single (op : unopt) : string =
  Fmt.asprintf "%a" pp_of_unopt_single op

let str_of_binopt_single (op : binopt) : string =
  Fmt.asprintf "%a" pp_of_binopt_single op

let str_of_triopt_single (op : triopt) : string =
  Fmt.asprintf "%a" pp_of_triopt_single op

let str_of_const (c : const) : string = Fmt.asprintf "%a" pp_of_const c

let str_of_unopt (pp_val : Fmt.t -> 'a -> unit) (op : unopt) (v : 'a) : string =
  Fmt.asprintf "%a" (pp_of_unopt pp_val) (op, v)

let str_of_binopt (pp_val : Fmt.t -> 'a -> unit) (op : binopt) (v1 : 'a)
  (v2 : 'a) : string =
  Fmt.asprintf "%a" (pp_of_binopt pp_val) (op, v1, v2)

let str_of_triopt (pp_val : Fmt.t -> 'a -> unit) (op : triopt) (v1 : 'a)
  (v2 : 'a) (v3 : 'a) : string =
  Fmt.asprintf "%a" (pp_of_triopt pp_val) (op, v1, v2, v3)

let str_of_nopt (pp_val : Fmt.t -> 'a -> unit) (op : nopt) (vs : 'a list) :
  string =
  Fmt.asprintf "%a" (pp_of_nopt pp_val) (op, vs)
