open EslBase
open EslSyntax
module Env = Symbolic.P.Env
module SMap = Link_env.SMap
module PC = Choice_monad.PC

let of_array l = Array.fold_left (fun m (k, v) -> SMap.add k v m) SMap.empty l

module type S = sig
  type extern_func

  val extern_cmds : Env.t -> extern_func SMap.t
  val symbolic_api : extern_func SMap.t
  val concrete_api : extern_func SMap.t
end

module Make () = struct
  module Value = Symbolic.P.Value
  module Choice = Symbolic.P.Choice
  module Extern_func = Symbolic.P.Extern_func
  module Thread = Choice_monad.Thread
  module Translator = Value_translator
  module Optimizer = Choice_monad.Optimizer
  module PC = Choice_monad.PC
  open Extern_func

  let ( let/ ) = Choice.bind
  let fresh_i = Base.make_name_generator "i"
  let fresh_x = Base.make_name_generator "x"
  let fresh_func = Base.make_name_generator "eval_func_"
  let ok v = Choice.return (Ok v)
  let ok_v v = ok (Value.Val v)
  let err v = Choice.return (Error (`Failure v))

  let extern_cmds env =
    let parseJS data =
      let open EslJSParser.Api in
      let data =
        match data with Value.Val (Val.Str data) -> data | _ -> assert false
      in
      let input_file = Filename.temp_file "__parse_in_" "__.js" in
      let output_file = Filename.temp_file "__parse_out_" "__.js" in
      Io.write_file input_file data;
      let fid = fresh_func () in
      begin
        match Bos.OS.Cmd.run (cmd input_file (Some output_file) (Some fid)) with
        | Error (`Msg msg) -> Log.stderr "%s" msg
        | Ok () -> ()
      end;
      let data = Io.read_file output_file in
      let func = Parsing.parse_func data in
      Env.add_func env fid func;
      ok_v (Val.Str fid)
    in
    of_array [| ("parseJS", Extern_func (Func (Arg Res), parseJS)) |]

  let concrete_api =
    let open Value in
    let open External.Impl in
    let int_to_four_hex = function
      | Val v -> ok_v (int_to_four_hex v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let octal_to_decimal = function
      | Val v -> ok_v (octal_to_decimal v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_precision v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (to_precision (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_exponential v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (to_exponential (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_fixed v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (to_fixed (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let from_char_code_u = function
      | Val v -> ok_v (from_char_code_u v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_char_code_u = function
      | Val v -> ok_v (to_char_code_u v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_lower_case = function
      | Val v -> ok_v (to_lower_case v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let to_upper_case = function
      | Val v -> ok_v (to_upper_case v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let trim = function
      | Val v -> ok_v (trim v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let s_len_u = function
      | Val v -> ok_v (s_len_u v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let s_nth_u v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (s_nth_u (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let s_split v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (s_split (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let s_substr_u v1 v2 v3 =
      match (v1, v2, v3) with
      | (Val v1, Val v2, Val v3) -> ok_v (s_substr_u (v1, v2, v3))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let array_len = function
      | Val v -> ok_v (array_len v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let array_make v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (array_make (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let array_nth v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (array_nth (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let array_set v1 v2 v3 =
      match (v1, v2, v3) with
      | (Val v1, Val v2, Val v3) -> ok_v (array_set (v1, v2, v3))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_to_array = function
      | Val v -> ok_v (list_to_array v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_sort = function
      | Val v -> ok_v (list_sort v)
      | NOpt (ListExpr, lst) -> ok (NOpt (ListExpr, List.sort compare lst))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_mem v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (list_mem (v1, v2))
      | (_, NOpt (ListExpr, lst)) -> ok_v (Bool (List.mem v1 lst))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_remove_last = function
      | Val v -> ok_v (list_remove_last v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_remove v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (list_remove (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let list_remove_nth v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (list_remove_nth (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float_to_byte = function
      | Val v -> ok_v (float_to_byte v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float32_to_le_bytes = function
      | Val v -> ok_v (float32_to_le_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float32_to_be_bytes = function
      | Val v -> ok_v (float32_to_be_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float64_to_le_bytes = function
      | Val v -> ok_v (float64_to_le_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float64_to_be_bytes = function
      | Val v -> ok_v (float64_to_be_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float32_from_le_bytes = function
      | Val v -> ok_v (float32_from_le_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float32_from_be_bytes = function
      | Val v -> ok_v (float32_from_be_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float64_from_le_bytes = function
      | Val v -> ok_v (float64_from_le_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let float64_from_be_bytes = function
      | Val v -> ok_v (float64_from_be_bytes v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let bytes_to_string = function
      | Val v -> ok_v (bytes_to_string v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let int_to_be_bytes v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (int_to_be_bytes (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let int_from_le_bytes v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (int_from_le_bytes (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let uint_from_le_bytes v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (uint_from_le_bytes (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let log_2 = function
      | Val v -> ok_v (log_2 v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let log_e = function
      | Val v -> ok_v (log_e v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let log_10 = function
      | Val v -> ok_v (log_10 v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let sin = function
      | Val v -> ok_v (sin v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let cos = function
      | Val v -> ok_v (cos v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let tan = function
      | Val v -> ok_v (tan v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let sinh = function
      | Val v -> ok_v (sinh v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let cosh = function
      | Val v -> ok_v (cosh v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let tanh = function
      | Val v -> ok_v (tanh v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let asin = function
      | Val v -> ok_v (asin v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let acos = function
      | Val v -> ok_v (acos v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let atan = function
      | Val v -> ok_v (atan v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let atan2 v1 v2 =
      match (v1, v2) with
      | (Val v1, Val v2) -> ok_v (atan2 (v1, v2))
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let utf8_decode = function
      | Val v -> ok_v (utf8_decode v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let hex_decode = function
      | Val v -> ok_v (hex_decode v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let parse_number = function
      | Val v -> ok_v (parse_number v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let parse_string = function
      | Val v -> ok_v (parse_string v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    let parse_date = function
      | Val v -> ok_v (parse_date v)
      | _ -> err (__FUNCTION__ ^ ": invalid argument")
    in
    of_array
      [| (* int *)
         ( "int_to_four_hex_external"
         , Extern_func (Func (Arg Res), int_to_four_hex) )
       ; ( "octal_to_decimal_external"
         , Extern_func (Func (Arg Res), octal_to_decimal) )
         (* float *)
       ; ( "to_precision_external"
         , Extern_func (Func (Arg (Arg Res)), to_precision) )
       ; ( "to_exponential_external"
         , Extern_func (Func (Arg (Arg Res)), to_exponential) )
       ; ("to_fixed_external", Extern_func (Func (Arg (Arg Res)), to_fixed))
         (* string *)
       ; ( "from_char_code_u_external"
         , Extern_func (Func (Arg Res), from_char_code_u) )
       ; ( "to_char_code_u_external"
         , Extern_func (Func (Arg Res), to_char_code_u) )
       ; ("to_lower_case_external", Extern_func (Func (Arg Res), to_lower_case))
       ; ("to_upper_case_external", Extern_func (Func (Arg Res), to_upper_case))
       ; ("trim_external", Extern_func (Func (Arg Res), trim))
       ; ("s_len_u_external", Extern_func (Func (Arg Res), s_len_u))
       ; ("s_nth_u_external", Extern_func (Func (Arg (Arg Res)), s_nth_u))
       ; ("s_split_external", Extern_func (Func (Arg (Arg Res)), s_split))
       ; ( "s_substr_u_external"
         , Extern_func (Func (Arg (Arg (Arg Res))), s_substr_u) )
         (* array *)
       ; ("a_len_external", Extern_func (Func (Arg Res), array_len))
       ; ("array_make_external", Extern_func (Func (Arg (Arg Res)), array_make))
       ; ("a_nth_external", Extern_func (Func (Arg (Arg Res)), array_nth))
       ; ("a_set_external", Extern_func (Func (Arg (Arg (Arg Res))), array_set))
         (* list *)
       ; ("list_to_array_external", Extern_func (Func (Arg Res), list_to_array))
       ; ("l_sort_external", Extern_func (Func (Arg Res), list_sort))
       ; ("in_list_external", Extern_func (Func (Arg (Arg Res)), list_mem))
       ; ( "l_remove_last_external"
         , Extern_func (Func (Arg Res), list_remove_last) )
       ; ("l_remove_external", Extern_func (Func (Arg (Arg Res)), list_remove))
       ; ( "l_remove_nth_external"
         , Extern_func (Func (Arg (Arg Res)), list_remove_nth) )
         (* byte *)
       ; ("float_to_byte_external", Extern_func (Func (Arg Res), float_to_byte))
       ; ( "float32_to_le_bytes_external"
         , Extern_func (Func (Arg Res), float32_to_le_bytes) )
       ; ( "float32_to_be_bytes_external"
         , Extern_func (Func (Arg Res), float32_to_be_bytes) )
       ; ( "float64_to_le_bytes_external"
         , Extern_func (Func (Arg Res), float64_to_le_bytes) )
       ; ( "float64_to_be_bytes_external"
         , Extern_func (Func (Arg Res), float64_to_be_bytes) )
       ; ( "float32_from_le_bytes_external"
         , Extern_func (Func (Arg Res), float32_from_le_bytes) )
       ; ( "float32_from_be_bytes_external"
         , Extern_func (Func (Arg Res), float32_from_be_bytes) )
       ; ( "float64_from_le_bytes_external"
         , Extern_func (Func (Arg Res), float64_from_le_bytes) )
       ; ( "float64_from_be_bytes_external"
         , Extern_func (Func (Arg Res), float64_from_be_bytes) )
       ; ( "bytes_to_string_external"
         , Extern_func (Func (Arg Res), bytes_to_string) )
       ; ( "int_to_be_bytes_external"
         , Extern_func (Func (Arg (Arg Res)), int_to_be_bytes) )
       ; ( "int_from_le_bytes_external"
         , Extern_func (Func (Arg (Arg Res)), int_from_le_bytes) )
       ; ( "uint_from_le_bytes_external"
         , Extern_func (Func (Arg (Arg Res)), uint_from_le_bytes) )
         (* math *)
       ; ("log_2_external", Extern_func (Func (Arg Res), log_2))
       ; ("log_e_external", Extern_func (Func (Arg Res), log_e))
       ; ("log_10_external", Extern_func (Func (Arg Res), log_10))
       ; ("sin_external", Extern_func (Func (Arg Res), sin))
       ; ("cos_external", Extern_func (Func (Arg Res), cos))
       ; ("tan_external", Extern_func (Func (Arg Res), tan))
       ; ("sinh_external", Extern_func (Func (Arg Res), sinh))
       ; ("cosh_external", Extern_func (Func (Arg Res), cosh))
       ; ("tanh_external", Extern_func (Func (Arg Res), tanh))
       ; ("asin_external", Extern_func (Func (Arg Res), asin))
       ; ("acos_external", Extern_func (Func (Arg Res), acos))
       ; ("atan_external", Extern_func (Func (Arg Res), atan))
       ; ("atan2_external", Extern_func (Func (Arg (Arg Res)), atan2))
         (* parse *)
       ; ("utf8_decode_external", Extern_func (Func (Arg Res), utf8_decode))
       ; ("hex_decode_external", Extern_func (Func (Arg Res), hex_decode))
       ; ("parse_number_external", Extern_func (Func (Arg Res), parse_number))
       ; ("parse_string_external", Extern_func (Func (Arg Res), parse_string))
       ; ("parse_date_external", Extern_func (Func (Arg Res), parse_date))
      |]

  let symbolic_api =
    let open Value in
    let open Extern_func in
    let non_empty = function
      | Val (Str "") -> Val (Str (fresh_x ()))
      | Val (Str _) as x -> x
      | x -> Log.fail "'%a' is not a valid string symbol" Value.pp x
    in
    let str_symbol (x : value) = ok (Symbolic (Type.StrType, non_empty x)) in
    let int_symbol (x : value) = ok (Value.int_symbol (non_empty x)) in
    let flt_symbol (x : value) = ok (Symbolic (Type.FltType, non_empty x)) in
    let bool_symbol (x : value) = ok (Symbolic (Type.BoolType, non_empty x)) in
    let is_symbolic (n : value) = ok_v (Val.Bool (Value.is_symbolic n)) in
    let is_number (n : value) =
      ok_v
        (Val.Bool
           ( match Value_typing.type_of n with
           | Some Type.IntType | Some Type.FltType -> true
           | _ -> false ) )
    in
    let is_sat (e : value) =
      let/ b = Choice.check e in
      ok_v (Val.Bool b)
    in
    let is_exec_sat (e : value) =
      (* TODO: more fine-grained exploit analysis *)
      let i = Value.int_symbol_s (fresh_i ()) in
      let len = Value.Val (Int 18) in
      let sub = TriOpt (Operator.StringSubstr, e, i, len) in
      let query =
        BinOpt (Operator.Eq, sub, Val (Val.Str "A; touch success #"))
      in
      let/ b = Choice.check_add_true query in
      ok_v (Val.Bool b)
    in
    let is_eval_sat (e : value) =
      (* TODO: more fine-grained exploit analysis *)
      let i = Value.int_symbol_s (fresh_i ()) in
      let len = Value.Val (Int 25) in
      let sub = TriOpt (Operator.StringSubstr, e, i, len) in
      let query =
        BinOpt (Operator.Eq, sub, Val (Val.Str ";console.log('success')//"))
      in
      let/ b = Choice.check_add_true query in
      ok_v (Val.Bool b)
    in
    let abort (e : value) =
      let e' = Format.asprintf "%a" Value.pp e in
      Log.stdout "      abort : %s@." e';
      Choice.return @@ Error (`Abort e')
    in
    let assume (e : value) thread =
      let e' = Translator.translate e in
      [ (Ok (Val (Val.Symbol "undefined")), Thread.add_pc thread e') ]
    in
    let evaluate (e : value) =
      Choice.with_thread (fun thread ->
          let e' = Translator.translate e in
          let pc = Thread.pc thread |> PC.to_list in
          let solver = Thread.solver thread in
          assert (`Sat = Solver.check solver (e' :: pc));
          let v = Solver.get_value solver e' in
          Ok (Translator.expr_of_value (Smtml.Expr.view v)) )
    in
    let optimize target opt e pc =
      Optimizer.push opt;
      Optimizer.add opt pc;
      let v = target opt e in
      Optimizer.pop opt;
      v
    in
    let maximize (e : value) =
      Choice.with_thread (fun thread ->
          let e' = Translator.translate e in
          let pc = Thread.pc thread |> PC.to_list in
          let opt = Thread.optimizer thread in
          let v = optimize Optimizer.maximize opt e' pc in
          match v with
          | Some v -> Ok (Translator.expr_of_value (Val v))
          | None ->
            (* TODO: Error here *)
            assert false )
    in
    let minimize (e : value) =
      Choice.with_thread (fun thread ->
          let e' = Translator.translate e in
          let pc = Thread.pc thread |> PC.to_list in
          let opt = Thread.optimizer thread in
          let v = optimize Optimizer.minimize opt e' pc in
          match v with
          | Some v -> Ok (Translator.expr_of_value (Val v))
          | None ->
            (* TODO: Error here *)
            assert false )
    in
    let print (v : Value.value) =
      Log.stdout "extern print: %a@." Value.pp v;
      ok_v (Val.Symbol "undefined")
    in
    of_array
      [| ("str_symbol", Extern_func (Func (Arg Res), str_symbol))
       ; ("int_symbol", Extern_func (Func (Arg Res), int_symbol))
       ; ("flt_symbol", Extern_func (Func (Arg Res), flt_symbol))
       ; ("bool_symbol", Extern_func (Func (Arg Res), bool_symbol))
       ; ("is_symbolic", Extern_func (Func (Arg Res), is_symbolic))
       ; ("is_number", Extern_func (Func (Arg Res), is_number))
       ; ("is_sat", Extern_func (Func (Arg Res), is_sat))
       ; ("is_exec_sat", Extern_func (Func (Arg Res), is_exec_sat))
       ; ("is_eval_sat", Extern_func (Func (Arg Res), is_eval_sat))
       ; ("abort", Extern_func (Func (Arg Res), abort))
       ; ("assume", Extern_func (Func (Arg Res), assume))
       ; ("evaluate", Extern_func (Func (Arg Res), evaluate))
       ; ("maximize", Extern_func (Func (Arg Res), maximize))
       ; ("minimize", Extern_func (Func (Arg Res), minimize))
       ; ("value", Extern_func (Func (Arg Res), print))
      |]
end

include (Make () : S with type extern_func := Symbolic.P.Extern_func.extern_func)
