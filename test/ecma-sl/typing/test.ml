open Ecma_sl
open EType

let ( ~@ ) (x : 'a) : 'a Source.phrase = Source.(x @> no_region)
let t_any : t = ~@AnyType
let t_unknown : t = ~@UnknownType
let t_never : t = ~@NeverType
let t_undefined : t = ~@UndefinedType
let t_null : t = ~@NullType
let t_void : t = ~@VoidType
let t_int : t = ~@IntType
let t_float : t = ~@FloatType
let t_string : t = ~@StringType
let t_boolean : t = ~@BooleanType
let t_symbol : t = ~@SymbolType
let lt_integer (i : int) : t = ~@(LiteralType (IntegerLit i))
let lt_float (f : float) : t = ~@(LiteralType (FloatLit f))
let lt_string (s : string) : t = ~@(LiteralType (StringLit s))
let lt_boolean (b : bool) : t = ~@(LiteralType (BooleanLit b))
let lt_symbol (s : string) : t = ~@(LiteralType (SymbolLit s))

let t_fld ?(opt : bool = false) (fn : Id.t') (ft : t) : tobjfld =
  (~@fn, ft, if opt then FldOpt else FldReq)

let t_obj ?(kind : tobjkind = ObjSto) (flds : tobjfld list) : t =
  let tobj = EParsing_helper.Type.parse_tobject flds in
  ~@(ObjectType { tobj with kind })

let t_objlit (flds : tobjfld list) : t = t_obj ~kind:ObjLit flds
let t_objsto (flds : tobjfld list) : t = t_obj ~kind:ObjSto flds
let t_list (t : t) : t = ~@(ListType t)
let t_tuple (ts : t list) : t = ~@(TupleType ts)
let t_union (ts : t list) : t = ~@(UnionType ts)

let t_sigma (dsc : Id.t') (ts : t list) : t =
  ~@(SigmaType (~@dsc, EParsing_helper.Type.parse_tsigma ~@dsc ~@(UnionType ts)))

module Log = struct
  let expected (msg1 : string) (msg2 : string) : bool =
    Printf.printf "Expected: %s\nResult:   %s\n" msg1 msg2;
    false
end

module Syntax = struct
  module Err = Compile_error.CompileErr

  let test (syntax : string) (expected : (t, Err.t list) Result.t) : bool =
    let err_str msgs = List.map Err.str msgs |> String.concat " ; " in
    let result =
      try Ok (Parsing_utils.parse_etype syntax) with
      | Compile_error.Error err -> Error err.msgs
      | exn -> raise exn
    in
    match (expected, result) with
    | (Ok t1, Ok t2) ->
      if equal t1 t2 then true else Log.expected (str t1) (str t2)
    | (Error msgs1, Error msgs2) ->
      if List.equal Err.equal msgs1 msgs2 then true
      else Log.expected (err_str msgs1) (err_str msgs2)
    | (Ok t1, Error msgs2) -> Log.expected (str t1) (err_str msgs2)
    | (Error msgs1, Ok t2) -> Log.expected (err_str msgs1) (str t2)
end

module TypeCheck = struct
  module Err = Typing_error.TypingErr

  let test (congruency : bool) ((tref, tsrc) : EType.t * EType.t)
    (expected : (unit, Err.t list) Result.t) : bool =
    let err_str msgs = List.map Err.str msgs |> String.concat "\n\t  " in
    let result =
      try Ok (TSubtyping.type_check ~congruency tref tsrc) with
      | Typing_error.Error err -> Error err.msgs
      | exn -> raise exn
    in
    match (expected, result) with
    | (Ok (), Ok ()) -> true
    | (Error msgs1, Error msgs2) ->
      if List.equal Err.equal msgs1 msgs2 then true
      else Log.expected (err_str msgs1) (err_str msgs2)
    | (Ok (), Error msgs2) -> Log.expected "success" (err_str msgs2)
    | (Error msgs1, Ok ()) -> Log.expected (err_str msgs1) "success"

  let test_congruency ((tref, tsrc) : EType.t * EType.t)
    (expected : (unit, Err.t list) Result.t) : bool =
    test true (tref, tsrc) expected

  let test_subtyping ((tref, tsrc) : EType.t * EType.t)
    (expected : (unit, Err.t list) Result.t) : bool =
    test false (tref, tsrc) expected
end
