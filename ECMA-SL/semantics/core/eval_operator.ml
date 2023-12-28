open Operator
open Val

let op_err (src_arg_i : int) (op_label : string) (rt_msg : Eslerr.runtime_err) :
  'a =
  let msgs = [ Eslerr.RuntimeErr.OperatorError op_label; rt_msg ] in
  raise Eslerr.(runtime' ~src:(Index src_arg_i) msgs)

let unexpected_err (src_arg_i : int) (op_label : string) (msg : string) : 'a =
  op_err src_arg_i op_label (Eslerr.RuntimeErr.UnexpectedValue msg)

let bad_arg_err (src_arg_i : int) (op_label : string) (types : string)
  (vals : Val.t list) : 'a =
  op_err src_arg_i op_label (Eslerr.RuntimeErr.BadOperands (types, vals))

let typeof (v : Val.t) : Val.t =
  let op_label = label_of_unopt Typeof in
  match v with
  | Null -> Type Type.NullType
  | Void -> unexpected_err 1 op_label "void value"
  | Int _ -> Type Type.IntType
  | Flt _ -> Type Type.FltType
  | Bool _ -> Type Type.BoolType
  | Str _ -> Type Type.StrType
  | Symbol _ -> Type Type.SymbolType
  | Loc _ -> Type Type.LocType
  | Arr _ -> Type Type.ArrayType
  | List _ -> Type Type.ListType
  | Tuple _ -> Type Type.TupleType
  | Type _ -> Type Type.TypeType
  | Byte _ -> Eslerr.internal __FUNCTION__ (NotImplemented (Some "byte"))
  | Curry _ -> Type Type.CurryType

let neg (v : Val.t) : Val.t =
  let op_label = label_of_unopt Neg in
  match v with
  | Int v -> Int (-v)
  | Flt v -> Flt (-.v)
  | _ -> bad_arg_err 1 op_label "integer or float" [ v ]

let bitwise_not (v : Val.t) : Val.t =
  let op_label = label_of_unopt BitwiseNot in
  match v with
  | Flt f -> Flt (Arith_utils.int32_bitwise_not f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let logical_not (v : Val.t) : Val.t =
  let op_label = label_of_unopt LogicalNot in
  match v with
  | Bool v -> Bool (not v)
  | _ -> bad_arg_err 1 op_label "boolean" [ v ]

let int_to_float (v : Val.t) : Val.t =
  let op_label = label_of_unopt IntToFloat in
  match v with
  | Int i -> Flt (float_of_int i)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let int_to_string (v : Val.t) : Val.t =
  let op_label = label_of_unopt IntToString in
  match v with
  | Int i -> Str (string_of_int i)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let int_to_four_hex (v : Val.t) : Val.t =
  let op_label = label_of_unopt IntToFourHex in
  match v with
  | Int i -> Str (Printf.sprintf "%04x" i)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let octal_to_decimal (v : Val.t) : Val.t =
  let op_label = label_of_unopt OctalToDecimal in
  match v with
  | Int o ->
    let rec loop dec_value base temp =
      if temp = 0 then dec_value
      else
        let dec_value = dec_value + (temp mod 10 * base) in
        loop dec_value (base * 8) (temp / 10)
    in
    Int (loop 0 1 o)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let float_to_int (v : Val.t) : Val.t =
  let op_label = label_of_unopt FloatToInt in
  match v with
  | Flt f -> Int (int_of_float f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float_to_string (v : Val.t) : Val.t =
  let op_label = label_of_unopt FloatToString in
  match v with
  | Flt i -> Str (Arith_utils.float_to_string_inner i)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let to_int (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToInt in
  match v with
  | Flt n -> Flt (Arith_utils.to_int n)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let to_int32 (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToInt32 in
  match v with
  | Flt n -> Flt (Arith_utils.to_int32 n)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let to_uint16 (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToUint16 in
  match v with
  | Flt n -> Flt (Arith_utils.to_uint16 n)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let to_uint32 (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToUint32 in
  match v with
  | Flt n -> Flt (Arith_utils.to_uint32 n)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let is_nan (v : Val.t) : Val.t =
  match v with Flt v -> Bool (Float.is_nan v) | _ -> Bool false

let string_to_int (v : Val.t) : Val.t =
  let op_label = label_of_unopt StringToInt in
  match v with
  | Str s -> Int (int_of_string s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let string_to_float (v : Val.t) : Val.t =
  let op_label = label_of_unopt StringToFloat in
  match v with
  | Str s -> (
    let trimmed = String.trim s in
    if String.length trimmed == 0 then Flt nan
    else try Flt (float_of_string trimmed) with _ -> Flt nan )
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let from_char_code (v : Val.t) : Val.t =
  let op_label = label_of_unopt FromCharCode in
  match v with
  | Int n -> Str (String_utils.from_char_code n)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let from_char_code_u (v : Val.t) : Val.t =
  let op_label = label_of_unopt FromCharCodeU in
  match v with
  | Int n -> Str (String_utils.from_char_code_u n)
  | _ -> bad_arg_err 1 op_label "integer" [ v ]

let to_char_code (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToCharCode in
  match v with
  | Str s -> Int (String_utils.to_char_code s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let to_char_code_u (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToCharCodeU in
  match v with
  | Str s -> Int (String_utils.to_char_code_u s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let to_lower_case (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToLowerCase in
  match v with
  | Str s -> Str (String_utils.to_lower_case s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let to_upper_case (v : Val.t) : Val.t =
  let op_label = label_of_unopt ToUpperCase in
  match v with
  | Str s -> Str (String_utils.to_upper_case s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let trim (v : Val.t) : Val.t =
  let op_label = label_of_unopt Trim in
  match v with
  | Str s -> Str (String_utils.trim s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let string_len (v : Val.t) : Val.t =
  let op_label = label_of_unopt StringLen in
  match v with
  | Str s -> Int (String.length s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let string_len_u (v : Val.t) : Val.t =
  let op_label = label_of_unopt StringLenU in
  match v with
  | Str s -> Int (String_utils.s_len_u s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let string_concat_aux (lst : t list) : string list option =
  let _concat_f acc v =
    match (acc, v) with
    | (Some strs, Val.Str s) -> Some (strs @ [ s ])
    | _ -> None
  in
  List.fold_left _concat_f (Some []) lst

let string_concat (v : Val.t) : Val.t =
  let op_label = label_of_unopt StringConcat in
  match v with
  | List lst -> (
    let strs = string_concat_aux lst in
    match strs with
    | Some strs -> Str (String.concat "" strs)
    | None -> bad_arg_err 1 op_label "string list" [ v ] )
  | _ -> bad_arg_err 1 op_label "string list" [ v ]

let array_len (v : Val.t) : Val.t =
  let op_label = label_of_unopt ArrayLen in
  match v with
  | Arr a -> Val.Int (Array.length a)
  | _ -> bad_arg_err 1 op_label "array" [ v ]

let list_to_array (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListToArray in
  match v with
  | List lst -> Val.Arr (Array.of_list lst)
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let list_head (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListHead in
  match v with
  | List lst -> List.hd lst
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let list_tail (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListTail in
  match v with
  | List lst -> List (List.tl lst)
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let list_len (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListLen in
  match v with
  | List lst -> Val.Int (List.length lst)
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let list_sort (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListSort in
  let _str_f s = Val.Str s in
  match v with
  | List lst -> (
    let strs = string_concat_aux lst in
    match strs with
    | Some strs -> List (List.map _str_f (List.fast_sort String.compare strs))
    | None -> bad_arg_err 1 op_label "string list" [ v ] )
  | _ -> bad_arg_err 1 op_label "string list" [ v ]

let list_reverse (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListReverse in
  match v with
  | List lst -> Val.List (List.rev lst)
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let list_remove_last (v : Val.t) : Val.t =
  let op_label = label_of_unopt ListRemoveLast in
  let rec _remove_last lst =
    match lst with [] -> [] | _ :: [] -> [] | _ :: tl -> _remove_last tl
  in
  match v with
  | List lst -> List (_remove_last lst)
  | _ -> bad_arg_err 1 op_label "list" [ v ]

let tuple_first (v : Val.t) : Val.t =
  let op_label = label_of_unopt TupleFirst in
  match v with
  | Tuple tup -> List.nth tup 0
  | _ -> bad_arg_err 1 op_label "tuple" [ v ]

let tuple_second (v : Val.t) : Val.t =
  let op_label = label_of_unopt TupleSecond in
  match v with
  | Tuple tup -> List.nth tup 1
  | _ -> bad_arg_err 1 op_label "tuple" [ v ]

let tuple_len (v : Val.t) : Val.t =
  let op_label = label_of_unopt TupleLen in
  match v with
  | Tuple t -> Val.Int (List.length t)
  | _ -> bad_arg_err 1 op_label "tuple" [ v ]

let unpack_bytes_aux (op_label : string) (v : Val.t) : int array =
  let _unpack_byte_f = function Int i -> i | Byte b -> b | _ -> raise Exit in
  try
    match v with
    | Arr bytes -> Array.map _unpack_byte_f bytes
    | _ -> bad_arg_err 1 op_label "byte array" [ v ]
  with _ -> bad_arg_err 1 op_label "byte array" [ v ]

let float_to_byte (v : Val.t) : Val.t =
  let op_label = label_of_unopt FloatToByte in
  match v with
  | Flt x -> Val.Byte (Int64.to_int (Int64.bits_of_float x))
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float32_to_le_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float32ToLEBytes in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float32_to_le_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int32.to_int b)) bytes in
    List val_bytes
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float32_to_be_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float32ToBEBytes in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float32_to_be_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int32.to_int b)) bytes in
    List val_bytes
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float64_to_le_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float64ToLEBytes in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float64_to_le_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int64.to_int b)) bytes in
    List val_bytes
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float64_to_be_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float64ToBEBytes in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float64_to_be_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int64.to_int b)) bytes in
    List val_bytes
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let float32_from_le_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float32FromLEBytes in
  let int_bytes = unpack_bytes_aux op_label v in
  let int32_bytes = Array.map Int32.of_int int_bytes in
  let f = Byte_utils.float32_from_le_bytes int32_bytes in
  Flt f

let float32_from_be_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float32FromBEBytes in
  let int_bytes = unpack_bytes_aux op_label v in
  let int32_bytes = Array.map Int32.of_int int_bytes in
  let f = Byte_utils.float32_from_be_bytes int32_bytes in
  Flt f

let float64_from_le_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float64FromLEBytes in
  let int_bytes = unpack_bytes_aux op_label v in
  let int64_bytes = Array.map Int64.of_int int_bytes in
  let f = Byte_utils.float64_from_le_bytes int64_bytes in
  Flt f

let float64_from_be_bytes (v : Val.t) : Val.t =
  let op_label = label_of_unopt Float64FromBEBytes in
  let int_bytes = unpack_bytes_aux op_label v in
  let int64_bytes = Array.map Int64.of_int int_bytes in
  let f = Byte_utils.float64_from_be_bytes int64_bytes in
  Flt f

let bytes_to_string (v : Val.t) : Val.t =
  let op_label = label_of_unopt BytesToString in
  let int_bytes = unpack_bytes_aux op_label v in
  let str_bytes = Array.map string_of_int int_bytes |> Array.to_list in
  let bytes_string = "[" ^ String.concat "; " str_bytes ^ "]" in
  Str bytes_string

let random (v : Val.t) : Val.t =
  let op_label = label_of_unopt Random in
  match v with
  | Flt f -> Flt (Random.float f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let abs (v : Val.t) : Val.t =
  let op_label = label_of_unopt Abs in
  match v with
  | Flt f -> Flt (Float.abs f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let sqrt (v : Val.t) : Val.t =
  let op_label = label_of_unopt Sqrt in
  match v with
  | Flt f -> Flt (Float.sqrt f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let ceil (v : Val.t) : Val.t =
  let op_label = label_of_unopt Ceil in
  match v with
  | Flt f -> Flt (Float.ceil f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let floor (v : Val.t) : Val.t =
  let op_label = label_of_unopt Floor in
  match v with
  | Flt f -> Flt (Float.floor f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let exp (v : Val.t) : Val.t =
  let op_label = label_of_unopt Exp in
  match v with
  | Flt f -> Flt (Float.exp f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let log_2 (v : Val.t) : Val.t =
  let op_label = label_of_unopt Log2 in
  match v with
  | Flt f -> Flt (Float.log2 f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let log_e (v : Val.t) : Val.t =
  let op_label = label_of_unopt LogE in
  match v with
  | Flt f -> Flt (Float.log f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let log_10 (v : Val.t) : Val.t =
  let op_label = label_of_unopt Log10 in
  match v with
  | Flt f -> Flt (Float.log10 f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let sin (v : Val.t) : Val.t =
  let op_label = label_of_unopt Sin in
  match v with
  | Flt f -> Flt (Float.sin f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let cos (v : Val.t) : Val.t =
  let op_label = label_of_unopt Cos in
  match v with
  | Flt f -> Flt (Float.cos f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let tan (v : Val.t) : Val.t =
  let op_label = label_of_unopt Tan in
  match v with
  | Flt f -> Flt (Float.tan f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let sinh (v : Val.t) : Val.t =
  let op_label = label_of_unopt Sinh in
  match v with
  | Flt f -> Flt (Float.sinh f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let cosh (v : Val.t) : Val.t =
  let op_label = label_of_unopt Cosh in
  match v with
  | Flt f -> Flt (Float.cosh f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let tanh (v : Val.t) : Val.t =
  let op_label = label_of_unopt Tanh in
  match v with
  | Flt f -> Flt (Float.tanh f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let asin (v : Val.t) : Val.t =
  let op_label = label_of_unopt Asin in
  match v with
  | Flt f -> Flt (Float.asin f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let acos (v : Val.t) : Val.t =
  let op_label = label_of_unopt Acos in
  match v with
  | Flt f -> Flt (Float.acos f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let atan (v : Val.t) : Val.t =
  let op_label = label_of_unopt Atan in
  match v with
  | Flt f -> Flt (Float.atan f)
  | _ -> bad_arg_err 1 op_label "float" [ v ]

let utf8_decode (v : Val.t) : Val.t =
  let op_label = label_of_unopt Utf8Decode in
  match v with
  | Str s -> Str (String_utils.utf8decode s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let hex_decode (v : Val.t) : Val.t =
  let op_label = label_of_unopt HexDecode in
  match v with
  | Str s -> Str (String_utils.hexdecode s)
  | _ -> bad_arg_err 1 op_label "string" [ v ]

(** * JSON number regex: https://stackoverflow.com/a/13340826/3049315 *
    Recognized Regexp constructs in OCaml Str: https://ocaml.org/api/Str.html *)
let parse_number (v : Val.t) : Val.t =
  let op_label = label_of_unopt ParseNumber in
  match v with
  | Str s ->
    let regex =
      Str.regexp "-?\\(0\\|[1-9][0-9]*\\)\\(\\.[0-9]+\\)?\\([eE][+-]?[0-9]+\\)?"
    in
    let matched = Str.string_match regex s 0 in
    if matched then Str (Str.matched_string s) else Str ""
  | _ -> bad_arg_err 1 op_label "string" [ v ]

(** * JSON string regex: https://stackoverflow.com/a/32155765/3049315 *)
let parse_string (v : Val.t) : Val.t =
  let op_label = label_of_unopt ParseString in
  match v with
  | Str s ->
    let regex =
      Str.regexp
        "\"\\(\\\\\\([\"\\\\\\/bfnrt]\\|u[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]\\)\\|[^\"\\\\\000-\031\127]+\\)*\""
    in
    let matched = Str.string_match regex s 0 in
    if matched then Str (Str.matched_string s) else Str ""
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let parse_date (v : Val.t) : Val.t =
  let op_label = label_of_unopt ParseDate in
  let _remove_sign s = String.sub s 1 (String.length s - 1) in
  let _signed_year year_neg year = if year_neg then -.year else year in
  let _parse_date year_neg date =
    match date with
    | None -> Val.Flt (-1.)
    | Some ([ year; month; day; hour; min; sec; msec ], tz) ->
      Val.List
        [ Val.Flt (_signed_year year_neg year)
        ; Val.Flt month
        ; Val.Flt day
        ; Val.Flt hour
        ; Val.Flt min
        ; Val.Flt sec
        ; Val.Flt msec
        ; Val.Str tz
        ]
    | _ -> unexpected_err 1 op_label "date format"
  in
  match v with
  | Str s ->
    let year_sign = s.[0] in
    if year_sign == '-' then
      _remove_sign s |> Date_utils.parse_date |> _parse_date true
    else if year_sign == '+' then
      _remove_sign s |> Date_utils.parse_date |> _parse_date false
    else Date_utils.parse_date s |> _parse_date false
  | _ -> bad_arg_err 1 op_label "string" [ v ]

let plus ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Plus in
  match (v1, v2) with
  | (Int i1, Int i2) -> Int (i1 + i2)
  | (Flt f1, Flt f2) -> Flt (f1 +. f2)
  | (Int _, _) | (Flt _, _) ->
    bad_arg_err 2 op_label "(integer, integer) or (float, float)" [ v1; v2 ]
  | _ ->
    bad_arg_err 1 op_label "(integer, integer) or (float, float)" [ v1; v2 ]

let minus ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Minus in
  match (v1, v2) with
  | (Int i1, Int i2) -> Int (i1 - i2)
  | (Flt f1, Flt f2) -> Flt (f1 -. f2)
  | (Int _, _) | (Flt _, _) ->
    bad_arg_err 2 op_label "(integer, integer) or (float, float)" [ v1; v2 ]
  | _ ->
    bad_arg_err 1 op_label "(integer, integer) or (float, float)" [ v1; v2 ]

let times ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Times in
  match (v1, v2) with
  | (Int i1, Int i2) -> Int (i1 * i2)
  | (Flt f1, Flt f2) -> Flt (f1 *. f2)
  | (Int _, _) | (Flt _, _) ->
    bad_arg_err 2 op_label "(integer, integer) or (float, float)" [ v1; v2 ]
  | _ ->
    bad_arg_err 1 op_label "(integer, integer) or (float, float)" [ v1; v2 ]

let div ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Div in
  match (v1, v2) with
  | (Int i1, Int i2) -> Int (i1 / i2)
  | (Flt f1, Flt f2) -> Flt (f1 /. f2)
  | (Int _, _) | (Flt _, _) ->
    bad_arg_err 2 op_label "(integer, integer) or (float, float)" [ v1; v2 ]
  | _ ->
    bad_arg_err 1 op_label "(integer, integer) or (float, float)" [ v1; v2 ]

let modulo ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Modulo in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (mod_float f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let pow ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Max in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Float.pow f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let bitwise_and ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt BitwiseAnd in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.int32_bitwise_and f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let bitwise_or ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt BitwiseOr in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.int32_bitwise_or f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let bitwise_xor ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt BitwiseXor in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.int32_bitwise_xor f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let shift_left ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ShiftLeft in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.int32_left_shift f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let shift_right ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ShiftRight in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.int32_right_shift f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let shift_right_logical ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ShiftRightLogical in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Arith_utils.uint32_right_shift f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let logical_and ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt LogicalAnd in
  match (v1, v2) with
  | (Bool v1, Bool v2) -> Bool (v1 && v2)
  | (Bool _, _) -> bad_arg_err 2 op_label "(boolean, boolean)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(boolean, boolean)" [ v1; v2 ]

let logical_or ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt LogicalOr in
  match (v1, v2) with
  | (Bool v1, Bool v2) -> Bool (v1 || v2)
  | (Bool _, _) -> bad_arg_err 2 op_label "(boolean, boolean)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(boolean, boolean)" [ v1; v2 ]

let eq ((v1, v2) : Val.t * Val.t) : Val.t =
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Bool (Float.equal f1 f2)
  | (Arr a1, Arr a2) -> Bool (a1 == a2)
  | _ -> Bool (v1 = v2)

let lt ((v1, v2) : Val.t * Val.t) : Val.t = Bool (v1 < v2)
let gt ((v1, v2) : Val.t * Val.t) : Val.t = Bool (v1 > v2)
let le ((v1, v2) : Val.t * Val.t) : Val.t = Bool (v1 >= v2)
let ge ((v1, v2) : Val.t * Val.t) : Val.t = Bool (v1 <= v2)

let to_precision ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ToPrecision in
  match (v1, v2) with
  | (Flt x, Int y) ->
    let z = Float.to_int (Float.log10 x) + 1 in
    if y < z then
      let exp = Float.log10 x in
      if exp >= 0. then
        let num =
          Float.round
            (x /. (10. ** Float.trunc exp) *. (10. ** Float.of_int (y - 1)))
          /. (10. ** Float.of_int (y - 1))
        in
        if Float.is_integer num && y = 1 then
          Str
            ( string_of_int (Float.to_int num)
            ^ "e+"
            ^ Int.to_string (Float.to_int exp) )
        else Str (string_of_float num ^ "e+" ^ Int.to_string (Float.to_int exp))
      else
        let num =
          Float.round
            (x /. (10. ** Float.floor exp) *. (10. ** Float.of_int (y - 1)))
          /. (10. ** Float.of_int (y - 1))
        in
        if Float.is_integer num && y = 1 then
          Str
            ( string_of_int (Float.to_int num)
            ^ "e"
            ^ Int.to_string (Float.to_int (Float.floor exp)) )
        else
          Str
            ( string_of_float num
            ^ "e"
            ^ Int.to_string (Float.to_int (Float.floor exp)) )
    else
      let res =
        Float.round (x *. (10. ** float_of_int (y - 1)))
        /. (10. ** float_of_int (y - 1))
      in
      Str (Float.to_string res)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, integer)" [ v1; v2 ]

let to_exponential ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ToExponential in
  match (v1, v2) with
  | (Flt x, Int y) ->
    let exp = Float.log10 x in
    if exp >= 0. then
      let num =
        Float.round (x /. (10. ** Float.trunc exp) *. (10. ** Float.of_int y))
        /. (10. ** Float.of_int y)
      in
      if Float.is_integer num then
        Str
          ( string_of_int (Float.to_int num)
          ^ "e+"
          ^ Int.to_string (Float.to_int exp) )
      else Str (string_of_float num ^ "e+" ^ Int.to_string (Float.to_int exp))
    else
      let num =
        Float.round (x /. (10. ** Float.floor exp) *. (10. ** Float.of_int y))
        /. (10. ** Float.of_int y)
      in
      if Float.is_integer num then
        Str
          ( string_of_int (Float.to_int num)
          ^ "e"
          ^ Int.to_string (Float.to_int (Float.floor exp)) )
      else
        Str
          ( string_of_float num
          ^ "e"
          ^ Int.to_string (Float.to_int (Float.floor exp)) )
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, integer)" [ v1; v2 ]

let to_fixed ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ToFixed in
  match (v1, v2) with
  | (Flt x, Int y) -> Str (Printf.sprintf "%0.*f" y x)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, integer)" [ v1; v2 ]

let string_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt StringNth in
  match (v1, v2) with
  | (Str s, Int i) -> (
    try Str (String.sub s i 1)
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (Str _, _) -> bad_arg_err 2 op_label "(string, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(string, integer)" [ v1; v2 ]

let string_nth_u ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt StringNthU in
  match (v1, v2) with
  | (Str s, Int i) -> (
    try Str (String_utils.s_nth_u s i)
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (Str _, _) -> bad_arg_err 2 op_label "(string, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(string, integer)" [ v1; v2 ]

let string_split ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt StringSplit in
  match (v1, v2) with
  | (_, Str "") -> unexpected_err 2 op_label "empty separator"
  | (Str str, Str sep) ->
    Val.List (List.map (fun s -> Val.Str s) (Str.split (Str.regexp sep) str))
  | (Str _, _) -> bad_arg_err 2 op_label "(string, string)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(string, string)" [ v1; v2 ]

let array_make ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ArrayMake in
  match (v1, v2) with
  | (Int n, v) ->
    if n > 0 then Val.Arr (Array.make n v)
    else unexpected_err 1 op_label "non-positive array size"
  | _ -> bad_arg_err 1 op_label "(integer, any)" [ v1; v2 ]

let array_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ArrayNth in
  match (v1, v2) with
  | (Arr arr, Int i) -> (
    try Array.get arr i
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (Arr _, _) -> bad_arg_err 2 op_label "(array, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(array, integer)" [ v1; v2 ]

let list_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListNth in
  match (v1, v2) with
  | (List lst, Int i) -> (
    try List.nth lst i
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (List _, _) -> bad_arg_err 2 op_label "(list, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(list, integer)" [ v1; v2 ]

let list_mem ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListMem in
  match v2 with
  | List lst -> Bool (List.mem v1 lst)
  | _ -> bad_arg_err 2 op_label "(any, list)" [ v1; v2 ]

let list_add ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListAdd in
  match v1 with
  | List lst -> Val.List (lst @ [ v2 ])
  | _ -> bad_arg_err 1 op_label "(list, any)" [ v1; v2 ]

let list_prepend ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListPrepend in
  match v2 with
  | List lst -> Val.List (v1 :: lst)
  | _ -> bad_arg_err 2 op_label "(any, list)" [ v1; v2 ]

let list_concat ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListPrepend in
  match (v1, v2) with
  | (List l1, List l2) -> Val.List (l1 @ l2)
  | (List _, _) -> bad_arg_err 2 op_label "(list, list)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(list, list)" [ v1; v2 ]

let list_remove ((v1, v2) : Val.t * Val.t) : Val.t =
  let rec _remove_aux lst el =
    match lst with
    | [] -> []
    | hd :: tl when hd = el -> tl
    | hd :: tl -> hd :: _remove_aux tl el
  in
  let op_label = label_of_binopt ListRemove in
  match (v1, v2) with
  | (List lst, el) -> List (_remove_aux lst el)
  | _ -> bad_arg_err 1 op_label "(list, any)" [ v1; v2 ]

let list_remove_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt ListRemoveNth in
  let rec _remove_nth_aux lst i =
    match (lst, i) with
    | ([], _) -> unexpected_err 2 op_label "index out of bounds"
    | (_ :: tl, 0) -> tl
    | (hd :: tl, _) -> hd :: _remove_nth_aux tl (i - 1)
  in
  match (v1, v2) with
  | (List lst, Int i) -> List (_remove_nth_aux lst i)
  | (List _, _) -> bad_arg_err 2 op_label "(list, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(list, integer)" [ v1; v2 ]

let tuple_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt TupleNth in
  match (v1, v2) with
  | (Tuple tup, Int i) -> (
    try List.nth tup i
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (Tuple _, _) -> bad_arg_err 2 op_label "(tuple, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(tuple, integer)" [ v1; v2 ]

let int_to_be_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt IntToBEBytes in
  match (v1, v2) with
  | (Flt x, Int n) ->
    let bytes = Byte_utils.int_to_be_bytes (x, n) in
    let val_bytes = List.map (fun b -> Val.Byte b) bytes in
    List val_bytes
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, integer)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, integer)" [ v1; v2 ]

let int_from_le_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt IntFromLEBytes in
  let int_bytes =
    try unpack_bytes_aux op_label v1
    with _ -> bad_arg_err 1 op_label "(byte array, integer)" [ v1; v2 ]
  in
  match v2 with
  | Int n -> Flt (Byte_utils.int_from_le_bytes (int_bytes, n))
  | _ -> bad_arg_err 2 op_label "(byte array, integer)" [ v1; v2 ]

let uint_from_le_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt UintFromLEBytes in
  let int_bytes =
    try unpack_bytes_aux op_label v1
    with _ -> bad_arg_err 1 op_label "(byte array, integer)" [ v1; v2 ]
  in
  match v2 with
  | Int n -> Flt (Byte_utils.uint_from_le_bytes (int_bytes, n))
  | _ -> bad_arg_err 2 op_label "(byte array, integer)" [ v1; v2 ]

let min ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Min in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Float.min f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let max ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Max in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Float.max f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let atan2 ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_label = label_of_binopt Atan2 in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Float.atan2 f1 f2)
  | (Flt _, _) -> bad_arg_err 2 op_label "(float, float)" [ v1; v2 ]
  | _ -> bad_arg_err 1 op_label "(float, float)" [ v1; v2 ]

let ite ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_label = label_of_triopt ITE in
  match v1 with
  | Bool b -> if b then v2 else v3
  | _ -> bad_arg_err 1 op_label "(boolean, any, any)" [ v1; v2; v3 ]

let s_substr ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_label = label_of_triopt StringSubstr in
  let err_msg = "(string, integer, integer)" in
  let arg_err i = bad_arg_err i op_label err_msg [ v1; v2; v3 ] in
  match (v1, v2, v3) with
  | (Str s, Int i, Int j) -> Str (String.sub s i j)
  | (Str _, Int _, _) -> arg_err 3
  | (Str _, _, _) -> arg_err 2
  | _ -> arg_err 1

let s_substr_u ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_label = label_of_triopt StringSubstr in
  let err_msg = "(string, integer, integer)" in
  let arg_err i = bad_arg_err i op_label err_msg [ v1; v2; v3 ] in
  match (v1, v2, v3) with
  | (Str s, Int i, Int j) -> Str (String_utils.s_substr_u s i j)
  | (Str _, Int _, _) -> arg_err 3
  | (Str _, _, _) -> arg_err 2
  | _ -> arg_err 1

let array_set ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_label = label_of_triopt ArraySet in
  match (v1, v2) with
  | (Arr arr, Int i) -> (
    try Array.set arr i v3 |> fun () -> Val.Null
    with _ -> unexpected_err 2 op_label "index out of bounds" )
  | (Arr _, _) -> bad_arg_err 2 op_label "(array, integer, any)" [ v1; v2; v3 ]
  | _ -> bad_arg_err 1 op_label "(array, integer, any)" [ v1; v2; v3 ]

let list_set ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_label = label_of_triopt ListSet in
  let rec _set_aux lst i v =
    match (lst, i) with
    | ([], _) -> v :: unexpected_err 2 op_label "index out of bounds"
    | (_ :: tl, 0) -> v :: tl
    | (hd :: tl, _) -> hd :: _set_aux tl (i - 1) v
  in
  match (v1, v2) with
  | (List lst, Int i) -> List (_set_aux lst i v3)
  | (List _, _) -> bad_arg_err 2 op_label "(list, integer, any)" [ v1; v2; v3 ]
  | _ -> bad_arg_err 1 op_label "(list, integer, any)" [ v1; v2; v3 ]

let to_bool_aux op_label (vals : Val.t list) (v : Val.t) : bool =
  match v with Bool v -> v | _ -> bad_arg_err 1 op_label "boolean list" vals

let nary_logical_and (vals : Val.t list) : Val.t =
  let op_label = label_of_nopt NAryLogicalAnd in
  Bool (List.for_all (to_bool_aux op_label vals) vals)

let nary_logical_or (vals : Val.t list) : Val.t =
  let op_label = label_of_nopt NAryLogicalOr in
  Bool (List.exists (to_bool_aux op_label vals) vals)

let array_expr (vals : Val.t list) : Val.t = Arr (Array.of_list vals)
let list_expr (vals : Val.t list) : Val.t = List vals
let tuple_expr (vals : Val.t list) : Val.t = Tuple vals

let eval_unopt (op : unopt) (v : Val.t) : Val.t =
  match op with
  | Typeof -> typeof v
  | Neg -> neg v
  | BitwiseNot -> bitwise_not v
  | LogicalNot -> logical_not v
  | IntToFloat -> int_to_float v
  | IntToString -> int_to_string v
  | IntToFourHex -> int_to_four_hex v
  | OctalToDecimal -> octal_to_decimal v
  | FloatToInt -> float_to_int v
  | FloatToString -> float_to_string v
  | ToInt -> to_int v
  | ToInt32 -> to_int32 v
  | ToUint16 -> to_uint16 v
  | ToUint32 -> to_uint32 v
  | IsNaN -> is_nan v
  | StringToInt -> string_to_int v
  | StringToFloat -> string_to_float v
  | FromCharCode -> from_char_code v
  | FromCharCodeU -> from_char_code_u v
  | ToCharCode -> to_char_code v
  | ToCharCodeU -> to_char_code_u v
  | ToLowerCase -> to_lower_case v
  | ToUpperCase -> to_upper_case v
  | Trim -> trim v
  | StringLen -> string_len v
  | StringLenU -> string_len_u v
  | StringConcat -> string_concat v
  | ObjectToList ->
    Eslerr.internal __FUNCTION__ (UnexpectedEval (Some "ObjectToList"))
  | ObjectFields ->
    Eslerr.internal __FUNCTION__ (UnexpectedEval (Some "ObjectFields"))
  | ArrayLen -> array_len v
  | ListToArray -> list_to_array v
  | ListHead -> list_head v
  | ListTail -> list_tail v
  | ListLen -> list_len v
  | ListSort -> list_sort v
  | ListReverse -> list_reverse v
  | ListRemoveLast -> list_remove_last v
  | TupleFirst -> tuple_first v
  | TupleSecond -> tuple_second v
  | TupleLen -> tuple_len v
  | FloatToByte -> float_to_byte v
  | Float32ToLEBytes -> float32_to_le_bytes v
  | Float32ToBEBytes -> float32_to_be_bytes v
  | Float64ToLEBytes -> float64_to_le_bytes v
  | Float64ToBEBytes -> float64_to_be_bytes v
  | Float32FromLEBytes -> float32_from_le_bytes v
  | Float32FromBEBytes -> float32_from_be_bytes v
  | Float64FromLEBytes -> float64_from_le_bytes v
  | Float64FromBEBytes -> float64_from_be_bytes v
  | BytesToString -> bytes_to_string v
  | Random -> random v
  | Abs -> abs v
  | Sqrt -> sqrt v
  | Ceil -> ceil v
  | Floor -> floor v
  | Exp -> exp v
  | Log2 -> log_2 v
  | LogE -> log_e v
  | Log10 -> log_10 v
  | Sin -> sin v
  | Cos -> cos v
  | Tan -> tan v
  | Sinh -> sinh v
  | Cosh -> cosh v
  | Tanh -> tanh v
  | Asin -> asin v
  | Acos -> acos v
  | Atan -> atan v
  | Utf8Decode -> utf8_decode v
  | HexDecode -> hex_decode v
  | ParseNumber -> parse_number v
  | ParseString -> parse_string v
  | ParseDate -> parse_date v

let eval_binopt (op : binopt) (v1 : Val.t) (v2 : Val.t) : Val.t =
  match op with
  | Plus -> plus (v1, v2)
  | Minus -> minus (v1, v2)
  | Times -> times (v1, v2)
  | Div -> div (v1, v2)
  | Modulo -> modulo (v1, v2)
  | Pow -> pow (v1, v2)
  | BitwiseAnd -> bitwise_and (v1, v2)
  | BitwiseOr -> bitwise_or (v1, v2)
  | BitwiseXor -> bitwise_xor (v1, v2)
  | ShiftLeft -> shift_left (v1, v2)
  | ShiftRight -> shift_right (v1, v2)
  | ShiftRightLogical -> shift_right_logical (v1, v2)
  | LogicalAnd -> logical_and (v1, v2)
  | LogicalOr -> logical_or (v1, v2)
  | Eq -> eq (v1, v2)
  | Lt -> lt (v1, v2)
  | Gt -> gt (v1, v2)
  | Le -> le (v1, v2)
  | Ge -> ge (v1, v2)
  | ToPrecision -> to_precision (v1, v2)
  | ToExponential -> to_exponential (v1, v2)
  | ToFixed -> to_fixed (v1, v2)
  | ObjectMem -> Eslerr.internal __FUNCTION__ (UnexpectedEval (Some "ObjectMem"))
  | StringNth -> string_nth (v1, v2)
  | StringNthU -> string_nth_u (v1, v2)
  | StringSplit -> string_split (v1, v2)
  | ArrayMake -> array_make (v1, v2)
  | ArrayNth -> array_nth (v1, v2)
  | ListMem -> list_mem (v1, v2)
  | ListNth -> list_nth (v1, v2)
  | ListAdd -> list_add (v1, v2)
  | ListPrepend -> list_prepend (v1, v2)
  | ListConcat -> list_concat (v1, v2)
  | ListRemove -> list_remove (v1, v2)
  | ListRemoveNth -> list_remove_nth (v1, v2)
  | TupleNth -> tuple_nth (v1, v2)
  | IntToBEBytes -> int_to_be_bytes (v1, v2)
  | IntFromLEBytes -> int_from_le_bytes (v1, v2)
  | UintFromLEBytes -> uint_from_le_bytes (v1, v2)
  | Min -> min (v1, v2)
  | Max -> max (v1, v2)
  | Atan2 -> atan2 (v1, v2)

let eval_triopt (op : triopt) (v1 : Val.t) (v2 : Val.t) (v3 : Val.t) : Val.t =
  match op with
  | ITE -> ite (v1, v2, v3)
  | StringSubstr -> s_substr (v1, v2, v3)
  | StringSubstrU -> s_substr_u (v1, v2, v3)
  | ArraySet -> array_set (v1, v2, v3)
  | ListSet -> list_set (v1, v2, v3)

let eval_nopt (op : nopt) (vals : Val.t list) : Val.t =
  match op with
  | NAryLogicalAnd -> Val.Bool true
  | NAryLogicalOr -> Val.Bool true
  | ArrayExpr -> Val.Arr (Array.of_list vals)
  | ListExpr -> Val.List vals
  | TupleExpr -> Val.Tuple vals
