open Ecma_sl
open Test

let test_const (c : Operator.const) (expected : EType.t) : bool =
  TypeExpr.test ~@(EExpr.Const c) (Ok expected)

let test_unopt ((op, v) : Operator.unopt * Val.t) (expected : EType.t) : bool =
  let v' = ~@(EExpr.Val v) in
  TypeExpr.test ~@(EExpr.UnOpt (op, v')) (Ok expected)

let test_binopt ((op, v1, v2) : Operator.binopt * Val.t * Val.t)
  (expected : EType.t) : bool =
  let (v1', v2') = EExpr.(~@(Val v1), ~@(Val v2)) in
  TypeExpr.test ~@(EExpr.BinOpt (op, v1', v2')) (Ok expected)

let test_triopt ((op, v1, v2, v3) : Operator.triopt * Val.t * Val.t * Val.t)
  (expected : EType.t) : bool =
  let (v1', v2', v3') = EExpr.(~@(Val v1), ~@(Val v2), ~@(Val v3)) in
  TypeExpr.test ~@(EExpr.TriOpt (op, v1', v2', v3')) (Ok expected)

(* ========== Constant Operators ========== *)

let%test "constant_max" = test_const MAX_VALUE t_float
let%test "constant_min" = test_const MIN_VALUE t_float
let%test "constant_pi" = test_const PI t_float

(* ========== Simple Unary Operators ========== *)

let%test "unopt_neg_int" = test_unopt (Neg, Int 10) t_int
let%test "unopt_neg_float" = test_unopt (Neg, Flt 10.1) t_float
let%test "unopt_bitwise_not" = test_unopt (BitwiseNot, Flt 10.1) t_float
let%test "unopt_LogicalNot" = test_unopt (LogicalNot, Bool true) t_boolean
let%test "unopt_int_to_float" = test_unopt (IntToFloat, Int 10) t_float
let%test "unopt_int_to_string" = test_unopt (IntToString, Int 10) t_string
let%test "unopt_float_to_int" = test_unopt (FloatToInt, Flt 10.1) t_int
let%test "unopt_float_to_string" = test_unopt (FloatToString, Flt 10.1) t_string
let%test "unopt_to_int" = test_unopt (ToInt, Flt 10.1) t_float
let%test "unopt_to_int32" = test_unopt (ToInt32, Flt 10.1) t_float
let%test "unopt_to_uint16" = test_unopt (ToUint16, Flt 10.1) t_float
let%test "unopt_to_uint32" = test_unopt (ToUint32, Flt 10.1) t_float
let%test "unopt_string_to_int" = test_unopt (StringToInt, Str "abc") t_int
let%test "unopt_string_to_float" = test_unopt (StringToFloat, Str "abc") t_float
let%test "unopt_from_char_code" = test_unopt (FromCharCode, Int 10) t_string
let%test "unopt_to_char_code" = test_unopt (ToCharCode, Str "abc") t_int
let%test "unopt_string_len" = test_unopt (StringLen, Str "abc") t_int
let%test "unopt_random" = test_unopt (Random, Flt 10.1) t_float
let%test "unopt_abs" = test_unopt (Abs, Flt 10.1) t_float
let%test "unopt_sqrt" = test_unopt (Sqrt, Flt 10.1) t_float
let%test "unopt_ceil" = test_unopt (Ceil, Flt 10.1) t_float
let%test "unopt_floor" = test_unopt (Floor, Flt 10.1) t_float
let%test "unopt_exp" = test_unopt (Exp, Flt 10.1) t_float

(* ========== Simple Binary Operators ========== *)

let%test "binopt_plus_int" = test_binopt (Plus, Int 10, Int 10) t_int
let%test "binopt_plus_float" = test_binopt (Plus, Flt 10.1, Flt 10.1) t_float
let%test "binopt_minus_int" = test_binopt (Minus, Int 10, Int 10) t_int
let%test "binopt_minus_float" = test_binopt (Minus, Flt 10.1, Flt 10.1) t_float
let%test "binopt_times_int" = test_binopt (Times, Int 10, Int 10) t_int
let%test "binopt_times_float" = test_binopt (Times, Flt 10.1, Flt 10.1) t_float
let%test "binopt_div_int" = test_binopt (Div, Int 10, Int 10) t_int
let%test "binopt_div_float" = test_binopt (Div, Flt 10.1, Flt 10.1) t_float
let%test "binopt_modulo" = test_binopt (Modulo, Flt 10.1, Flt 10.1) t_float
let%test "binopt_pow" = test_binopt (Pow, Flt 10.1, Flt 10.1) t_float

let%test "binopt_bitwise_and" =
  test_binopt (BitwiseAnd, Flt 10.1, Flt 10.1) t_float

let%test "binopt_bitwise_or" =
  test_binopt (BitwiseOr, Flt 10.1, Flt 10.1) t_float

let%test "binopt_bitwise_xor" =
  test_binopt (BitwiseXor, Flt 10.1, Flt 10.1) t_float

let%test "binopt_shift_left" =
  test_binopt (ShiftLeft, Flt 10.1, Flt 10.1) t_float

let%test "binopt_shift_right" =
  test_binopt (ShiftRight, Flt 10.1, Flt 10.1) t_float

let%test "binopt_shift_right_logical" =
  test_binopt (ShiftRightLogical, Flt 10.1, Flt 10.1) t_float

let%test "binopt_logical_and" =
  test_binopt (LogicalAnd, Bool true, Bool true) t_boolean

let%test "binopt_logical_or" =
  test_binopt (LogicalOr, Bool true, Bool true) t_boolean

let%test "binopt_sc_logical_and" =
  test_binopt (SCLogicalAnd, Bool true, Bool true) t_boolean

let%test "binopt_sc_logical_or" =
  test_binopt (SCLogicalOr, Bool true, Bool true) t_boolean

let%test "binopt_eq_int" = test_binopt (Eq, Int 10, Int 10) t_boolean
let%test "binopt_eq_float" = test_binopt (Eq, Flt 10.1, Flt 10.1) t_boolean
let%test "binopt_eq_null" = test_binopt (Eq, Null, Null) t_boolean
let%test "binopt_lt_int" = test_binopt (Lt, Int 10, Int 10) t_boolean
let%test "binopt_lt_float" = test_binopt (Lt, Flt 10.1, Flt 10.1) t_boolean
let%test "binopt_lt_null" = test_binopt (Lt, Null, Null) t_boolean
let%test "binopt_gt_int" = test_binopt (Gt, Int 10, Int 10) t_boolean
let%test "binopt_gt_float" = test_binopt (Gt, Flt 10.1, Flt 10.1) t_boolean
let%test "binopt_gt_null" = test_binopt (Gt, Null, Null) t_boolean
let%test "binopt_le_int" = test_binopt (Le, Int 10, Int 10) t_boolean
let%test "binopt_le_float" = test_binopt (Le, Flt 10.1, Flt 10.1) t_boolean
let%test "binopt_ge_null" = test_binopt (Ge, Null, Null) t_boolean
let%test "binopt_le_int" = test_binopt (Le, Int 10, Int 10) t_boolean
let%test "binopt_le_float" = test_binopt (Le, Flt 10.1, Flt 10.1) t_boolean
let%test "binopt_le_null" = test_binopt (Le, Null, Null) t_boolean

let%test "binopt_string_nth" =
  test_binopt (StringNth, Str "abc", Int 10) t_string

let%test "binopt_min" = test_binopt (Min, Flt 10.1, Flt 10.1) t_float
let%test "binopt_max" = test_binopt (Max, Flt 10.1, Flt 10.1) t_float

(* ========== Simple Ternary Operators ========== *)

let%test "StringSubstr" =
  test_triopt (StringSubstr, Str "abc", Int 10, Int 10) t_string
