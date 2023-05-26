type t =
  | AnyType
  | UnknownType
  | NeverType
  | UndefinedType
  | NullType
  | NumberType
  | StringType
  | BooleanType
  | SymbolType
  | LiteralType of Val.t
  | ListType of t
  | TupleType of t list
  | UnionType of t list
  | ObjectType of tobj_t
  | RuntimeType of Type.t
  | UserDefinedType of string

and tobj_t = { flds : (string, tfld_t) Hashtbl.t; smry : t option }
and tfld_t = t * tpres_t
and tpres_t = Required | Optional

let get_tfld (tobj : tobj_t) (fn : string) : tfld_t option =
  Hashtbl.find_opt tobj.flds fn

module Field = struct
  type ft = NamedField of string * (t * bool) | SumryField of t
end

let parse_literal_type (v : Val.t) : t =
  match v with
  | Val.Int _ -> LiteralType v
  | Val.Flt _ -> LiteralType v
  | Val.Str _ -> LiteralType v
  | Val.Bool _ -> LiteralType v
  | Val.Symbol "undefined" -> UndefinedType
  | Val.Symbol _ -> LiteralType v
  | Val.Null -> NullType
  | _ -> invalid_arg ("Invalid value '" ^ Val.str v ^ "' for literal type.")

let parse_obj_type (fields : Field.ft list) : tobj_t =
  let _field_split_f field (nflds, sflds) =
    match field with
    | Field.NamedField (fn, ft) -> ((fn, ft) :: nflds, sflds)
    | Field.SumryField t -> (nflds, t :: sflds)
  in
  let _nfield_add_f flds (fn, (ft, opt)) =
    let fp = if opt then Optional else Required in
    match Hashtbl.find_opt flds fn with
    | None -> Hashtbl.replace flds fn (ft, fp)
    | Some _ -> invalid_arg ("Field '" ^ fn ^ "' already in the object.")
  in
  let nfields, sfields = List.fold_right _field_split_f fields ([], []) in
  let flds = Hashtbl.create !Config.default_hashtbl_sz in
  let _ = List.iter (_nfield_add_f flds) nfields in
  match sfields with
  | [] -> { flds; smry = None }
  | t :: [] -> { flds; smry = Some t }
  | _ -> invalid_arg "Duplicated summary field in the object."

let merge_tuple_type (t1 : t) (t2 : t) : t =
  match t1 with
  | TupleType ts -> TupleType (List.append ts [ t2 ])
  | _ -> TupleType [ t1; t2 ]

let rec merge_union_type (t1 : t) (t2 : t) : t =
  match (t1, t2) with
  | _, UnionType ts -> List.fold_right (fun t r -> merge_union_type r t) ts t1
  | UnionType ts, _ ->
      UnionType (if List.mem t2 ts then ts else List.append ts [ t2 ])
  | _ -> if t1 = t2 then t1 else UnionType [ t1; t2 ]

let merge_type (merge_fun_f : t -> t -> t) (ts : t list) : t =
  let tf, tr = match ts with [] -> (NeverType, []) | f :: r -> (f, r) in
  List.fold_left merge_fun_f tf tr

let is_fld_opt ((_, fp) : tfld_t) : bool =
  match fp with Required -> false | Optional -> true

let get_fld_t ((ft, fp) : tfld_t) : t =
  if fp = Optional then merge_union_type ft UndefinedType else ft

let get_fld_data (tobj : tobj_t) : (string * tfld_t) list =
  let nflds = Hashtbl.fold (fun fn ft r -> (fn, ft) :: r) tobj.flds [] in
  let sfld =
    match tobj.smry with
    | Some tsmry -> [ ("*", (tsmry, Required)) ]
    | None -> []
  in
  List.append nflds sfld

let rec str (t : t) : string =
  match t with
  | AnyType -> "any"
  | UnknownType -> "unknown"
  | NeverType -> "never"
  | UndefinedType -> "undefined"
  | NullType -> "null"
  | NumberType -> "number"
  | StringType -> "string"
  | BooleanType -> "boolean"
  | SymbolType -> "symbol"
  | LiteralType v -> Val.str v
  | ListType t' -> "[" ^ str t' ^ "]"
  | TupleType ts ->
      "(" ^ String.concat " * " (List.map (fun el -> str el) ts) ^ ")"
  | UnionType ts ->
      "(" ^ String.concat " | " (List.map (fun el -> str el) ts) ^ ")"
  | ObjectType tobj ->
      let fp_str_f tfld = if is_fld_opt tfld then "?" else "" in
      let fld_str_f (fn, tfld) = fn ^ fp_str_f tfld ^ ": " ^ str (fst tfld) in
      let flds = get_fld_data tobj in
      "{ " ^ String.concat ", " (List.map (fun f -> fld_str_f f) flds) ^ " }"
  | RuntimeType t' -> "runtime(" ^ Type.str t' ^ ")"
  | UserDefinedType t' -> t'

let wide_type (t : t) : t =
  match t with
  | LiteralType Val.Null -> NullType
  | LiteralType (Val.Int _) -> NumberType
  | LiteralType (Val.Flt _) -> NumberType
  | LiteralType (Val.Str _) -> StringType
  | LiteralType (Val.Bool _) -> BooleanType
  | LiteralType (Val.Symbol "undefined") -> UndefinedType
  | LiteralType (Val.Symbol _) -> SymbolType
  | LiteralType (Val.Type t') -> RuntimeType t'
  | _ -> t

let rec unfold_type (addNonLits : bool) (t : t) : t list =
  let bLits = [ LiteralType (Val.Bool true); LiteralType (Val.Bool false) ] in
  match (addNonLits, t) with
  | _, UndefinedType -> [ t ]
  | _, NullType -> [ t ]
  | _, BooleanType -> bLits
  | _, LiteralType _ -> [ t ]
  | _, UnionType ts -> List.concat (List.map (unfold_type addNonLits) ts)
  | true, _ -> [ t ]
  | false, _ -> []

let fold_type (ts : t list) =
  let _fold_bool_f = function LiteralType (Val.Bool _) -> true | _ -> false in
  let _find_bool_val ts b = List.mem (LiteralType (Val.Bool b)) ts in
  let convertToBool = _find_bool_val ts true && _find_bool_val ts false in
  if convertToBool then BooleanType :: List.filter _fold_bool_f ts else ts

let to_runtime (t : t) : t =
  match t with
  | UndefinedType -> RuntimeType Type.SymbolType
  | NullType -> RuntimeType Type.NullType
  | NumberType -> RuntimeType Type.TypeType
  | StringType -> RuntimeType Type.StrType
  | BooleanType -> RuntimeType Type.BoolType
  | SymbolType -> RuntimeType Type.SymbolType
  | LiteralType Val.Null -> RuntimeType Type.NullType
  | LiteralType (Val.Int _) -> RuntimeType Type.IntType
  | LiteralType (Val.Flt _) -> RuntimeType Type.FltType
  | LiteralType (Val.Str _) -> RuntimeType Type.StrType
  | LiteralType (Val.Bool _) -> RuntimeType Type.BoolType
  | LiteralType (Val.Symbol _) -> RuntimeType Type.SymbolType
  | LiteralType (Val.Type t') -> RuntimeType t'
  | ObjectType _ -> RuntimeType Type.LocType
  | RuntimeType _ -> t
  | _ -> RuntimeType Type.TypeType
