open Core
open Expr
open Val
open Operators

let reduce_unop (op : uopt) (v : Expr.t) : Expr.t =
  match (op, v) with
  | op, Val v -> Val (Eval_op.eval_unop op v)
  | Neg, Symbolic (_, _) -> UnOpt (Neg, v)
  | Not, v' -> UnOpt (Not, v)
  | Head, NOpt (ListExpr, a :: _) -> a
  | Tail, NOpt (ListExpr, _ :: tl) -> NOpt (ListExpr, tl)
  | First, NOpt (TupleExpr, a :: _) -> a
  | Second, NOpt (TupleExpr, _ :: b :: _) -> b
  | ListLen, NOpt (ListExpr, vs) -> Val (Int (List.length vs))
  | TupleLen, NOpt (TupleExpr, vs) -> Val (Int (List.length vs))
  | LSort, NOpt (ListExpr, []) -> NOpt (ListExpr, [])
  | Typeof, Symbolic (t, _) -> Val (Type t)
  | Typeof, NOpt (ListExpr, _) -> Val (Type Type.ListType)
  | Typeof, NOpt (TupleExpr, _) -> Val (Type Type.TupleType)
  | Typeof, NOpt (ArrExpr, _) -> Val (Type Type.ArrayType)
  | Typeof, Curry (_, _) -> Val (Type Type.CurryType)
  | Typeof, op ->
      let t = Sval_typing.type_of op in
      Val (Type (Option.value_exn t))
  | Sconcat, NOpt (ListExpr, vs) when List.for_all vs ~f:is_val ->
      Val
        (Str
           (String.concat ~sep:""
              (List.fold_left vs ~init:[] ~f:(fun a b ->
                   match b with Val (Str s) -> a @ [ s ] | _ -> assert false))))
  | FloatOfString, UnOpt (FloatToString, Symbolic (t, x)) -> Symbolic (t, x)
  (* missing obj_to_list, obj_fields*)
  | op', v1' -> UnOpt (op', v1')

let reduce_binop (op : bopt) (v1 : Expr.t) (v2 : Expr.t) : Expr.t =
  match (op, v1, v2) with
  | op, Val v1, Val v2 -> Val (Eval_op.eval_binopt_expr op v1 v2)
  | Eq, v, Val (Symbol _) when is_symbolic v -> Val (Bool false)
  | Eq, NOpt (_, _), Val Null -> Val (Bool false)
  | Eq, v, Val Null when Caml.not (Expr.is_loc v) -> Val (Bool false)
  | Eq, v1, v2 when Caml.not (is_symbolic v1 || is_symbolic v2) ->
      Val (Bool (Expr.equal v1 v2))
  | Tnth, NOpt (TupleExpr, vs), Val (Int i) -> List.nth_exn vs i
  | Lnth, NOpt (ListExpr, vs), Val (Int i) -> List.nth_exn vs i
  | Lconcat, NOpt (ListExpr, vs1), NOpt (ListExpr, vs2) ->
      NOpt (ListExpr, vs1 @ vs2)
  | Lprepend, v1, NOpt (ListExpr, vs) -> NOpt (ListExpr, v1 :: vs)
  | Ladd, NOpt (ListExpr, vs), v2 -> NOpt (ListExpr, vs @ [ v2 ])
  | InList, v1, NOpt (ListExpr, vs) -> Val (Bool (Caml.List.mem v1 vs))
  | op', v1', v2' -> BinOpt (op', v1', v2')

let reduce_triop (op : topt) (v1 : Expr.t) (v2 : Expr.t) (v3 : Expr.t) : Expr.t
    =
  match (op, v1, v2, v3) with
  | op, Val v1, Val v2, Val v3 -> Val (Eval_op.eval_triopt_expr op v1 v2 v3)
  | _ -> TriOpt (op, v1, v2, v3)

let reduce_nop (op : nopt) (vs : Expr.t list) : Expr.t = NOpt (op, vs)

let rec reduce_expr ?(at = Source.no_region) (store : Sstore.t) (e : Expr.t) :
    Expr.t =
  match e with
  | Val v -> Val v
  | Var x -> (
      match Sstore.find store x with
      | Some v -> v
      | None -> failwith ("Cannot find var '" ^ x ^ "'"))
  | UnOpt (op, e) ->
      let v = reduce_expr ~at store e in
      reduce_unop op v
  | BinOpt (op, e1, e2) ->
      let v1 = reduce_expr ~at store e1 and v2 = reduce_expr ~at store e2 in
      reduce_binop op v1 v2
  | TriOpt (op, e1, e2, e3) ->
      let v1 = reduce_expr ~at store e1
      and v2 = reduce_expr ~at store e2
      and v3 = reduce_expr ~at store e3 in
      reduce_triop op v1 v2 v3
  | NOpt (op, es) ->
      let vs = List.map ~f:(reduce_expr ~at store) es in
      reduce_nop op vs
  | Curry (f, es) -> Curry (f, List.map ~f:(reduce_expr ~at store) es)
  | Symbolic (t, x) -> Symbolic (t, reduce_expr ~at store x)
