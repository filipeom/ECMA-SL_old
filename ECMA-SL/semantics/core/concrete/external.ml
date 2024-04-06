open EslBase
open EslSyntax

type store = Val.t Store.t
type heap = Val.t Heap.t

let eval_build_ast_func = Base.make_name_generator "eval_func_"

let parseJS (prog : Prog.t) (code : string) : Val.t =
  let input = Filename.temp_file "ecmasl" "eval_func.js" in
  let output = Filename.temp_file "ecmasl" "eval_func.cesl" in
  let eval_func_id = eval_build_ast_func () in
  Io.write_file input code;
  let js2ecmasl = EslJSParser.Api.cmd input (Some output) (Some eval_func_id) in
  match Bos.OS.Cmd.run js2ecmasl with
  | Error _ -> Internal_error.(throw __FUNCTION__ (Custom "err in JS2ECMA-SL"))
  | Ok _ -> (
    try
      let ast_func = Io.read_file output in
      let eval_func = Parsing.parse_func ast_func in
      Hashtbl.replace (Prog.funcs prog) eval_func_id eval_func;
      Val.Str eval_func_id
    with _ -> Internal_error.(throw __FUNCTION__ (Custom "er in ParseJS")) )

let int_to_four_hex (v : Val.t) : Val.t =
  let op_lbl = "int_to_four_hex_external" in
  match v with
  | Int i -> Str (Printf.sprintf "%04x" i)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "integer" [ v ]


let octal_to_decimal (v : Val.t) : Val.t =
  let op_lbl = "octal_to_decimal_external" in
  match v with
  | Int o ->
    let rec loop dec_value base temp =
      if temp = 0 then dec_value
      else
        let dec_value = dec_value + (temp mod 10 * base) in
        loop dec_value (base * 8) (temp / 10)
    in
    Int (loop 0 1 o)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "integer" [ v ]

let to_precision ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "to_precision_external" in
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
  | (Flt _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(float, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(float, integer)" [ v1; v2 ]

let to_exponential ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "to_exponential_external" in
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
  | (Flt _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(float, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(float, integer)" [ v1; v2 ]
    
let to_fixed ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "to_fixed_external" in
  match (v1, v2) with
  | (Flt x, Int y) -> Str (Printf.sprintf "%0.*f" y x)
  | (Flt _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(float, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(float, integer)" [ v1; v2 ]

let from_char_code_u (v : Val.t) : Val.t =
  let op_lbl = "from_char_code_u_external" in
  match v with
  | Int n -> Str (String_utils.from_char_code_u n)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "integer" [ v ]
  
let to_char_code_u (v : Val.t) : Val.t =
  let op_lbl = "to_char_code_u_external" in
  match v with
  | Str s -> Int (String_utils.to_char_code_u s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let to_lower_case (v : Val.t) : Val.t =
  let op_lbl = "to_lower_case_external" in
  match v with
  | Str s -> Str (String_utils.to_lower_case s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let to_upper_case (v : Val.t) : Val.t =
  let op_lbl = "to_upper_case_external" in
  match v with
  | Str s -> Str (String_utils.to_upper_case s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let trim (v : Val.t) : Val.t =
  let op_lbl = "trim_external" in
  match v with
  | Str s -> Str (String_utils.trim s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let s_len_u (v : Val.t) : Val.t =
  let op_lbl = "s_len_u_external" in
  match v with
  | Str s -> Int (String_utils.s_len_u (s))
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let s_nth_u ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "s_nth_u_external" in
  match (v1, v2) with
  | (Str s, Int i) -> (
    try Str (String_utils.s_nth_u s i)
    with _ -> Eval_operator.unexpected_err 2 op_lbl "index out of bounds" )
  | (Str _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(string, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(string, integer)" [ v1; v2 ]

let s_split ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "s_split_external" in
  match (v1, v2) with
  | (_, Str "") -> Eval_operator.unexpected_err 2 op_lbl "empty separator"
  | (Str str, Str sep) ->
    Val.List (List.map (fun s -> Val.Str s) (Str.split (Str.regexp sep) str))
  | (Str _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(string, string)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(string, string)" [ v1; v2 ]

let s_substr_u ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_lbl = "s_substr_u_external" in
  let err_msg = "(string, integer, integer)" in
  let arg_err i = Eval_operator.bad_arg_err i op_lbl err_msg [ v1; v2; v3 ] in
  match (v1, v2, v3) with
  | (Str s, Int i, Int j) -> Str (String_utils.s_substr_u s i j)
  | (Str _, Int _, _) -> arg_err 3
  | (Str _, _, _) -> arg_err 2
  | _ -> arg_err 1

let array_len (v : Val.t) : Val.t =
  let op_lbl = "a_len_external" in
  match v with
  | Arr arr -> Val.Int (Array.length arr)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "array" [ v ]

let array_make ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "array_make_external" in
  match (v1, v2) with
  | (Int n, v) ->
    if n > 0 then Val.Arr (Array.make n v)
    else Eval_operator.unexpected_err 1 op_lbl "non-positive array size"
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(integer, any)" [ v1; v2 ]

let array_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "a_nth_external" in
  match (v1, v2) with
  | (Arr arr, Int i) -> (
    try Array.get arr i
    with _ -> Eval_operator.unexpected_err 2 op_lbl "index out of bounds" )
  | (Arr _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(array, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(array, integer)" [ v1; v2 ]
  
let array_set ((v1, v2, v3) : Val.t * Val.t * Val.t) : Val.t =
  let op_lbl = "a_set_external" in
  match (v1, v2) with
  | (Arr arr, Int i) -> (
    try Array.set arr i v3 |> fun () -> Val.Null
    with _ -> Eval_operator.unexpected_err 2 op_lbl "index out of bounds" )
  | (Arr _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(array, integer, any)" [ v1; v2; v3 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(array, integer, any)" [ v1; v2; v3 ]

let list_to_array (v : Val.t) : Val.t =
  let op_lbl = "list_to_array_external" in
  match v with
  | List lst -> Val.Arr (Array.of_list lst)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "list" [ v ]

let list_sort (v : Val.t) : Val.t =
  let op_lbl = "l_sort_external" in
  let str_f s = Val.Str s in
  match v with
  | List lst -> (
    let strs = Eval_operator.string_concat_aux lst in
    match strs with
    | Some strs -> List (List.map str_f (List.fast_sort String.compare strs))
    | None -> Eval_operator.bad_arg_err 1 op_lbl "string list" [ v ] )
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string list" [ v ]

let list_remove_last (v : Val.t) : Val.t =
  let op_lbl =  "l_remove_last_external" in
  let rec _remove_last lst =
    match lst with [] -> [] | _ :: [] -> [] | _ :: tl -> _remove_last tl
  in
  match v with
  | List lst -> List (_remove_last lst)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "list" [ v ]
  
let list_remove ((v1, v2) : Val.t * Val.t) : Val.t =
  let rec _remove_aux lst el =
    match lst with
    | [] -> []
    | hd :: tl when hd = el -> tl
    | hd :: tl -> hd :: _remove_aux tl el
  in
  let op_lbl = "l_remove_external" in
  match (v1, v2) with
  | (List lst, el) -> List (_remove_aux lst el)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(list, any)" [ v1; v2 ]

let list_remove_nth ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "l_remove_nth_external" in
  let rec _remove_nth_aux lst i =
    match (lst, i) with
    | ([], _) -> Eval_operator.unexpected_err 2 op_lbl "index out of bounds"
    | (_ :: tl, 0) -> tl
    | (hd :: tl, _) -> hd :: _remove_nth_aux tl (i - 1)
  in
  match (v1, v2) with
  | (List lst, Int i) -> List (_remove_nth_aux lst i)
  | (List _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(list, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(list, integer)" [ v1; v2 ]

let float_to_byte (v : Val.t) : Val.t =
  let op_lbl = "float_to_byte_external" in
  match v with
  | Flt x -> Val.Byte (Int64.to_int (Int64.bits_of_float x))
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let float32_to_le_bytes (v : Val.t) : Val.t =
  let op_lbl = "float32_to_le_bytes_external" in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float32_to_le_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int32.to_int b)) bytes in
    List val_bytes
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let float32_to_be_bytes (v : Val.t) : Val.t =
  let op_lbl = "float32_to_be_bytes_external" in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float32_to_be_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int32.to_int b)) bytes in
    List val_bytes
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let float64_to_le_bytes (v : Val.t) : Val.t =
  let op_lbl = "float64_to_le_bytes_external" in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float64_to_le_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int64.to_int b)) bytes in
    List val_bytes
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let float64_to_be_bytes (v : Val.t) : Val.t =
  let op_lbl = "float64_to_be_bytes_external" in
  match v with
  | Flt x ->
    let bytes = Byte_utils.float64_to_be_bytes x in
    let val_bytes = List.map (fun b -> Val.Byte (Int64.to_int b)) bytes in
    List val_bytes
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let unpack_bytes_aux (op_lbl : string) (v : Val.t) : int array =
  let open Val in
  let unpack_bt_f = function Int i -> i | Byte bt -> bt | _ -> raise Exit in
  try
    match v with
    | Arr bytes -> Array.map unpack_bt_f bytes
    | _ -> Eval_operator.bad_arg_err 1 op_lbl "byte array" [ v ]
  with _ -> Eval_operator.bad_arg_err 1 op_lbl "byte array" [ v ]
  
let float32_from_le_bytes (v : Val.t) : Val.t =
  let op_lbl = "float32_from_le_bytes_external" in
  let int_bytes = unpack_bytes_aux op_lbl v in
  let int32_bytes = Array.map Int32.of_int int_bytes in
  let f = Byte_utils.float32_from_le_bytes int32_bytes in
  Flt f

let float32_from_be_bytes (v : Val.t) : Val.t =
  let op_lbl = "float32_from_be_bytes_external" in
  let int_bytes = unpack_bytes_aux op_lbl v in
  let int32_bytes = Array.map Int32.of_int int_bytes in
  let f = Byte_utils.float32_from_be_bytes int32_bytes in
  Flt f

let float64_from_le_bytes (v : Val.t) : Val.t =
  let op_lbl = "float64_from_le_bytes_external" in
  let int_bytes = unpack_bytes_aux op_lbl v in
  let int64_bytes = Array.map Int64.of_int int_bytes in
  let f = Byte_utils.float64_from_le_bytes int64_bytes in
  Flt f

let float64_from_be_bytes (v : Val.t) : Val.t =
  let op_lbl = "float64_from_be_bytes_external" in
  let int_bytes = unpack_bytes_aux op_lbl v in
  let int64_bytes = Array.map Int64.of_int int_bytes in
  let f = Byte_utils.float64_from_be_bytes int64_bytes in
  Flt f

let bytes_to_string (v : Val.t) : Val.t =
  let op_lbl = "bytes_to_string_external" in
  let int_bytes = unpack_bytes_aux op_lbl v in
  let str_bytes = Array.map string_of_int int_bytes |> Array.to_list in
  let bytes_string = "[" ^ String.concat "; " str_bytes ^ "]" in
  Str bytes_string

let int_to_be_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "int_to_be_bytes_external" in
  match (v1, v2) with
  | (Flt x, Int n) ->
    let bytes = Byte_utils.int_to_be_bytes (x, n) in
    let val_bytes = List.map (fun b -> Val.Byte b) bytes in
    List val_bytes
  | (Flt _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(float, integer)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(float, integer)" [ v1; v2 ]

let int_from_le_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "int_from_le_bytes_external" in
  let int_bytes =
    try unpack_bytes_aux op_lbl v1
    with _ -> Eval_operator.bad_arg_err 1 op_lbl "(byte array, integer)" [ v1; v2 ]
  in
  match v2 with
  | Int n -> Flt (Byte_utils.int_from_le_bytes (int_bytes, n))
  | _ -> Eval_operator.bad_arg_err 2 op_lbl "(byte array, integer)" [ v1; v2 ]

let uint_from_le_bytes ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "uint_from_le_bytes_external" in
  let int_bytes =
    try unpack_bytes_aux op_lbl v1
    with _ -> Eval_operator.bad_arg_err 1 op_lbl "(byte array, integer)" [ v1; v2 ]
  in
  match v2 with
  | Int n -> Flt (Byte_utils.uint_from_le_bytes (int_bytes, n))
  | _ -> Eval_operator.bad_arg_err 2 op_lbl "(byte array, integer)" [ v1; v2 ]
  
let log_2 (v : Val.t) : Val.t =
  let op_lbl = "log_2_external" in
  match v with
  | Flt f -> Flt (Float.log2 f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let log_e (v : Val.t) : Val.t =
  let op_lbl = "log_e_external" in
  match v with
  | Flt f -> Flt (Float.log f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let log_10 (v : Val.t) : Val.t =
  let op_lbl = "log_10_external" in
  match v with
  | Flt f -> Flt (Float.log10 f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]
  
let sin (v : Val.t) : Val.t =
  let op_lbl = "sin_external" in
  match v with
  | Flt f -> Flt (Float.sin f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let cos (v : Val.t) : Val.t =
  let op_lbl = "cos_external" in
  match v with
  | Flt f -> Flt (Float.cos f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let tan (v : Val.t) : Val.t =
  let op_lbl = "tan_external" in
  match v with
  | Flt f -> Flt (Float.tan f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let sinh (v : Val.t) : Val.t =
  let op_lbl = "sinh_external" in
  match v with
  | Flt f -> Flt (Float.sinh f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let cosh (v : Val.t) : Val.t =
  let op_lbl = "cosh_external" in
  match v with
  | Flt f -> Flt (Float.cosh f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let tanh (v : Val.t) : Val.t =
  let op_lbl = "tanh_external" in
  match v with
  | Flt f -> Flt (Float.tanh f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let asin (v : Val.t) : Val.t =
  let op_lbl = "asin_external" in
  match v with
  | Flt f -> Flt (Float.asin f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let acos (v : Val.t) : Val.t =
  let op_lbl = "acos_external" in
  match v with
  | Flt f -> Flt (Float.acos f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]

let atan (v : Val.t) : Val.t =
  let op_lbl = "atan_external" in
  match v with
  | Flt f -> Flt (Float.atan f)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "float" [ v ]
  
let atan2 ((v1, v2) : Val.t * Val.t) : Val.t =
  let op_lbl = "atan2_external" in
  match (v1, v2) with
  | (Flt f1, Flt f2) -> Flt (Float.atan2 f1 f2)
  | (Flt _, _) -> Eval_operator.bad_arg_err 2 op_lbl "(float, float)" [ v1; v2 ]
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "(float, float)" [ v1; v2 ]
  
let utf8_decode (v : Val.t) : Val.t =
  let op_lbl = "utf8_decode_external" in
  match v with
  | Str s -> Str (String_utils.utf8decode s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let hex_decode (v : Val.t) : Val.t =
  let op_lbl = "hex_decode_external" in
  match v with
  | Str s -> Str (String_utils.hexdecode s)
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

(** * JSON number regex: https://stackoverflow.com/a/13340826/3049315 *
    Recognized Regexp constructs in OCaml Str: https://ocaml.org/api/Str.html *)
let parse_number (v : Val.t) : Val.t =
  let op_lbl = "parse_number_external" in
  match v with
  | Str s ->
    let regex =
      Str.regexp "-?\\(0\\|[1-9][0-9]*\\)\\(\\.[0-9]+\\)?\\([eE][+-]?[0-9]+\\)?"
    in
    let matched = Str.string_match regex s 0 in
    if matched then Str (Str.matched_string s) else Str ""
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

(** * JSON string regex: https://stackoverflow.com/a/32155765/3049315 *)
let parse_string (v : Val.t) : Val.t =
  let op_lbl = "parse_string_external" in
  match v with
  | Str s ->
    let regex =
      Str.regexp
        "\"\\(\\\\\\([\"\\\\\\/bfnrt]\\|u[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]\\)\\|[^\"\\\\\000-\031\127]+\\)*\""
    in
    let matched = Str.string_match regex s 0 in
    if matched then Str (Str.matched_string s) else Str ""
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]

let parse_date (v : Val.t) : Val.t =
  let op_lbl = "parse_date_external" in
  let remove_sign s = String.sub s 1 (String.length s - 1) in
  let signed_year year_neg year = if year_neg then -.year else year in
  let parse_date year_neg date =
    match date with
    | None -> Val.Flt (-1.)
    | Some ([ year; month; day; hour; min; sec; msec ], tz) ->
      Val.List
        [ Val.Flt (signed_year year_neg year)
        ; Val.Flt month
        ; Val.Flt day
        ; Val.Flt hour
        ; Val.Flt min
        ; Val.Flt sec
        ; Val.Flt msec
        ; Val.Str tz
        ]
    | _ -> Eval_operator.unexpected_err 1 op_lbl "date format"
  in
  match v with
  | Str s ->
    let year_sign = s.[0] in
    if year_sign == '-' then
      remove_sign s |> Date_utils.parse_date |> parse_date true
    else if year_sign == '+' then
      remove_sign s |> Date_utils.parse_date |> parse_date false
    else Date_utils.parse_date s |> parse_date false
  | _ -> Eval_operator.bad_arg_err 1 op_lbl "string" [ v ]
  
let execute (prog : Prog.t) (_store : 'a Store.t) (_heap : 'a Heap.t)
  (fn : Id.t') (vs : Val.t list) : Val.t =
  match (fn, vs) with
  | ("is_symbolic", _) -> Val.Bool false
  | ("parseJS", [ Val.Str code ]) -> parseJS prog code
  | ("int_to_four_hex_external", [ v ]) -> int_to_four_hex v
  | ("octal_to_decimal_external", [ v ]) -> octal_to_decimal v
  | ("to_precision_external", [ v1 ; v2 ]) -> to_precision (v1, v2)
  | ("to_exponential_external", [ v1 ; v2 ]) -> to_exponential (v1, v2)
  | ("to_fixed_external", [ v1 ; v2 ]) -> to_fixed (v1, v2)
  | ("from_char_code_u_external", [ v ]) -> from_char_code_u v
  | ("to_char_code_u_external", [ v ]) -> to_char_code_u v
  | ("to_lower_case_external", [ v ]) -> to_lower_case v
  | ("to_upper_case_external", [ v ]) -> to_upper_case v
  | ("trim_external", [ v ]) -> trim v
  | ("s_len_u_external", [ v ]) -> s_len_u v
  | ("s_nth_u_external", [ v1 ; v2 ]) -> s_nth_u (v1, v2)
  | ("s_split_external", [ v1 ; v2 ]) -> s_split (v1, v2)
  | ("s_substr_u_external", [ v1 ; v2 ; v3 ]) -> s_substr_u (v1, v2, v3)
  | ("a_len_external", [ v ]) -> array_len v
  | ("array_make_external", [ v1 ; v2 ]) -> array_make (v1, v2)
  | ("a_nth_external", [ v1 ; v2 ]) -> array_nth (v1, v2)
  | ("a_set_external", [ v1 ; v2 ; v3 ]) -> array_set (v1, v2, v3)
  | ("list_to_array_external", [ v ]) -> list_to_array v
  | ("l_sort_external", [ v ]) -> list_sort v
  | ("l_remove_last_external", [ v ]) -> list_remove_last v
  | ("l_remove_external", [ v1 ; v2 ]) -> list_remove (v1, v2)
  | ("l_remove_nth_external", [ v1 ; v2 ]) -> list_remove_nth (v1, v2)
  | ("float_to_byte_external", [ v ]) -> float_to_byte v
  | ("float32_to_le_bytes_external", [ v ]) -> float32_to_le_bytes v
  | ("float32_to_be_bytes_external", [ v ]) -> float32_to_be_bytes v
  | ("float64_to_le_bytes_external", [ v ]) -> float64_to_le_bytes v
  | ("float64_to_be_bytes_external", [ v ]) -> float64_to_be_bytes v
  | ("float32_from_le_bytes_external", [ v ]) -> float32_from_le_bytes v
  | ("float32_from_be_bytes_external", [ v ]) -> float32_from_be_bytes v
  | ("float64_from_le_bytes_external", [ v ]) -> float64_from_le_bytes v
  | ("float64_from_be_bytes_external", [ v ]) -> float64_from_be_bytes v
  | ("bytes_to_string_external", [ v ]) -> bytes_to_string v
  | ("int_to_be_bytes_external", [ v1 ; v2 ]) -> int_to_be_bytes (v1, v2)
  | ("int_from_le_bytes_external", [ v1 ; v2 ]) -> int_from_le_bytes (v1, v2)
  | ("uint_from_le_bytes_external", [ v1 ; v2 ]) -> uint_from_le_bytes (v1, v2)
  | ("log_2_external", [ v ]) -> log_2 v
  | ("log_e_external", [ v ]) -> log_e v
  | ("log_10_external", [ v ]) -> log_10 v
  | ("sin_external", [ v ]) -> sin v
  | ("cos_external", [ v ]) -> cos v
  | ("tan_external", [ v ]) -> tan v
  | ("sinh_external", [ v ]) -> sinh v
  | ("cosh_external", [ v ]) -> cosh v
  | ("tanh_external", [ v ]) -> tanh v
  | ("asin_external", [ v ]) -> asin v
  | ("acos_external", [ v ]) -> acos v
  | ("atan_external", [ v ]) -> atan v
  | ("atan2_external", [ v1 ; v2 ]) -> atan2 (v1, v2)
  | ("utf8_decode_external", [ v ]) -> utf8_decode v
  | ("hex_decode_external", [ v ]) -> hex_decode v
  | ("parse_number_external", [ v ]) -> parse_number v
  | ("parse_string_external", [ v ]) -> parse_string v
  | ("parse_date_external", [ v ]) -> parse_date v
  | _ ->
    Log.warn "UNKNOWN %s external function" fn;
    Val.Symbol "undefined"
