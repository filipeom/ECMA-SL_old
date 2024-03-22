open EslBase
open EslSyntax
open EslSyntax.Source

let rec type_expr (e : EExpr.t) : EType.t = type_expr' e @> e.at

and type_expr' (e : EExpr.t) : EType.t' =
  let texprs es = List.map type_expr es in
  let tflds flds = List.map (fun (fn, fe) -> (fn, type_expr fe)) flds in
  match e.it with
  | Val v -> type_val v
  | Var _ -> AnyType (* TODO: variables *)
  | GVar _ -> AnyType (* TODO: global variables *)
  | Const c -> TOperator.type_const c
  | UnOpt (op, e') -> texprs [ e' ] |> TOperator.type_unopt op
  | BinOpt (op, e1, e2) -> texprs [ e1; e2 ] |> TOperator.type_binopt op
  | TriOpt (op, e1, e2, e3) -> texprs [ e1; e2; e3 ] |> TOperator.type_triopt op
  | NOpt (op, es) -> texprs es |> TOperator.type_nopt op
  | Call (_, _, None) -> AnyType (* TODO: function calls *)
  | Call (_, _, Some _) -> AnyType (* TODO: function calls with throws *)
  | ECall _ -> AnyType (* TODO: external calls *)
  | NewObj flds -> tflds flds |> type_object
  | Lookup _ -> AnyType (* TODO: field lookups *)
  | Curry _ -> AnyType (* TODO: curry expressions *)
  | Symbolic _ -> AnyType (* TODO: symbolic expression *)

and type_val (v : Val.t) : EType.t' =
  let err v = Internal_error.UnexpectedEval (Some (v ^ " val")) in
  match v with
  | Null -> NullType
  | Void -> VoidType
  | Int i -> LiteralType (IntegerLit i)
  | Flt f -> LiteralType (FloatLit f)
  | Str s -> LiteralType (StringLit s)
  | Bool b -> LiteralType (BooleanLit b)
  | Symbol s -> LiteralType (SymbolLit s)
  | Loc _ -> Internal_error.(throw __FUNCTION__ (err "loc"))
  | Arr _ -> Internal_error.(throw __FUNCTION__ (err "array"))
  | List _ -> Internal_error.(throw __FUNCTION__ (err "list"))
  | Tuple _ -> Internal_error.(throw __FUNCTION__ (err "tuple"))
  | Byte _ -> Internal_error.(throw __FUNCTION__ (err "byte"))
  | Type _ -> AnyType (* TODO *)
  | Curry _ -> AnyType (* TODO *)

and type_object (flds : (Id.t * EType.t) list) : EType.t' =
  let set_object_field_f tflds (fn, ft) =
    if not (Hashtbl.mem tflds fn.it) then
      Hashtbl.replace tflds fn.it (fn, ft, EType.FldReq)
    else Internal_error.(throw __FUNCTION__ (Expecting "non-dup object flds"))
  in
  let tflds = Hashtbl.create !Base.default_hashtbl_sz in
  List.iter (set_object_field_f tflds) flds;
  ObjectType { kind = ObjLit; flds = tflds; smry = None }
