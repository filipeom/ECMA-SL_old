open Core
open Encoding
open Expr
open Func
open Source
open Reducer
module Crash = Err.Make ()
module Invalid_arg = Err.Make ()
module Obj = S_object
module Heap = S_heap.MakeHeap (Obj)
module State = State.MakeState (Obj)
open State

exception Crash = Crash.Error
exception Invalid_arg = Invalid_arg.Error

let rec unfold_ite ~(accum : Expr.t) (e : Expr.t) :
    (Expr.t Option.t * String.t) List.t =
  let open Operators in
  match e with
  | Val (Val.Loc x) | Val (Val.Symbol x) -> [ (Some accum, x) ]
  | TriOpt (ITE, c, Val (Val.Loc l), e) ->
      let accum' = BinOpt (Log_And, accum, UnOpt (Not, c)) in
      let tl = unfold_ite ~accum:accum' e in
      (Some (BinOpt (Log_And, accum, c)), l) :: tl
  | _ ->
      Printf.printf "rip with %s\n" (Expr.str e);
      assert false

let loc (at : region) (e : Expr.t) : (Expr.t Option.t * String.t) List.t =
  match e with
  | Val (Val.Loc l) -> [ (None, l) ]
  | TriOpt (Operators.ITE, c, Val (Val.Loc l), v) ->
      (Some c, l) :: unfold_ite ~accum:(UnOpt (Operators.Not, c)) v
  | _ ->
      Invalid_arg.error at ("Expr '" ^ Expr.str e ^ "' is not a loc expression")

(* Eval pass to remove variables from store *)
let rec eval_expr (store : S_store.t) (e : Expr.t) : Expr.t =
  match e with
  | Val v -> Val v
  | Var x ->
      Option.value_exn (S_store.find store x)
        ~message:(sprintf "Cannot find var '%s'" x)
  | UnOpt (op, e') -> UnOpt (op, eval_expr store e')
  | BinOpt (op, e1, e2) -> BinOpt (op, eval_expr store e1, eval_expr store e2)
  | TriOpt (op, e1, e2, e3) ->
      TriOpt (op, eval_expr store e1, eval_expr store e2, eval_expr store e3)
  | NOpt (op, es) -> NOpt (op, List.map ~f:(eval_expr store) es)
  | Curry (f, es) -> Curry (f, List.map ~f:(eval_expr store) es)
  | Symbolic (t, x) -> Symbolic (t, eval_expr store x)

let func (at : region) (v : Expr.t) : string * Expr.t list =
  match v with
  | Val (Val.Str x) -> (x, [])
  | Curry (Val (Val.Str x), vs) -> (x, vs)
  | _ -> Invalid_arg.error at "Sval is not a 'func' identifier"

let step (c : State.config) : State.config list =
  let open Stmt in
  let { prog; code; state; pc; solver; opt } = c in
  let heap, store, stack, f = state in
  let stmts =
    match code with
    | Cont stmts -> stmts
    | _ -> Crash.error no_region "step: Empty continuation!"
  in
  let s = List.hd_exn stmts in
  (*
  (if Stmt.is_basic_stmt s then
     let str_e (e : Expr.t) : string = Expr.str e in
     let debug =
       lazy
         (sprintf
            "====================================\nEvaluating >>>>> %s: %s (%s)"
            f (Stmt.str s)
            (Stmt.str ~print_expr:str_e s))
     in
     Logging.print_endline debug
     );
     *)
  match s.it with
  | Skip -> [ update c (Cont (List.tl_exn stmts)) state pc ]
  | Merge -> [ update c (Cont (List.tl_exn stmts)) state pc ]
  | Exception err ->
      fprintf stderr "%s: Exception: %s\n" (Source.string_of_region s.at) err;
      [ update c (Error (Some (Val (Val.Str err)))) state pc ]
  | Print e ->
      let e' = reduce_expr ~at:s.at store e in
      let s =
        match e' with
        | Val (Val.Loc l) ->
            let o = Heap.get heap l in
            Obj.to_string (Option.value_exn o) Expr.str
        | _ -> Expr.str e'
      in
      (* Printf.printf "print:%s\npc:%s\nheap id:%d\n" s (Encoding.Expression.string_of_pc pc) (Heap.get_id heap); *)
      Logging.print_endline (lazy s);
      [ update c (Cont (List.tl_exn stmts)) state pc ]
  | Fail e ->
      [ update c (Error (Some (reduce_expr ~at:s.at store e))) state pc ]
  | Abort e ->
      [
        update c
          (Failure ("Abort", Some (reduce_expr ~at:s.at store e)))
          state pc;
      ]
  | Stmt.Assign (x, e) ->
      let v = reduce_expr ~at:s.at store e in
      [
        update c
          (Cont (List.tl_exn stmts))
          (heap, S_store.add_exn store x v, stack, f)
          pc;
      ]
  | Stmt.Assert e -> (
      match reduce_expr ~at:s.at store e with
      | Val (Val.Bool b) ->
          if b then [ update c (Cont (List.tl_exn stmts)) state pc ]
          else
            let e' = Some (reduce_expr ~at:s.at store e) in
            [ update c (Failure ("assert", e')) state pc ]
      | v ->
          let v' = reduce_expr ~at:s.at store (Expr.UnOpt (Operators.Not, v)) in
          let cont =
            let pc' = ESet.add pc (Translator.translate v') in
            if Batch.check_sat solver (ESet.to_list pc') then
              [ update c (Failure ("assert", Some v)) state pc' ]
            else [ update c (Cont (List.tl_exn stmts)) state pc ]
          in
          Logging.print_endline
            (lazy
              ("assert (" ^ Expr.str v ^ ") = "
              ^ Bool.to_string (is_cont c.code)));
          cont)
  | Stmt.Block blk -> [ update c (Cont (blk @ List.tl_exn stmts)) state pc ]
  | Stmt.If (br, blk, _)
    when Expr.equal (Val (Val.Bool true)) (reduce_expr ~at:s.at store br) ->
      let cont =
        match blk.it with
        | Stmt.Block b -> b @ ((Stmt.Merge @@ blk.at) :: List.tl_exn stmts)
        | _ -> Crash.error s.at "Malformed if statement 'then' block!"
      in
      [ update c (Cont cont) state pc ]
  | Stmt.If (br, _, blk)
    when Expr.equal (Val (Val.Bool false)) (reduce_expr ~at:s.at store br) ->
      let cont =
        let t = List.tl_exn stmts in
        match blk with None -> t | Some s' -> s' :: (Stmt.Merge @@ s'.at) :: t
      in
      [ update c (Cont cont) state pc ]
  | Stmt.If (br, blk1, blk2) ->
      let br' = eval_expr store br in
      let br_t = reduce_expr ~at:s.at store br'
      and br_f = reduce_expr ~at:s.at store (Expr.UnOpt (Operators.Not, br')) in
      Logging.print_endline
        (lazy
          (sprintf "%s: If (%s)" (Source.string_of_region s.at) (Expr.str br_t)));
      let br_t' = Translator.translate br_t
      and br_f' = Translator.translate br_f in
      let then_branch =
        let pc' = ESet.add pc br_t' in
        try
          if not (Batch.check_sat solver (ESet.to_list pc')) then []
          else
            let state' = (Heap.clone heap, store, stack, f) in
            let stmts' = blk1 :: (Stmt.Merge @@ blk1.at) :: List.tl_exn stmts in
            [ update c (Cont stmts') state' pc' ]
        with Batch.Unknown -> [ update c (Unknown (Some br_t)) state pc' ]
      in
      let else_branch =
        let pc' = ESet.add pc br_f' in
        try
          if not (Batch.check_sat solver (ESet.to_list pc')) then []
          else
            let state' = (Heap.clone heap, store, stack, f) in
            let stmts' =
              match blk2 with
              | None -> List.tl_exn stmts
              | Some s' -> s' :: (Stmt.Merge @@ s'.at) :: List.tl_exn stmts
            in
            [ update c (Cont stmts') state' pc' ]
        with Batch.Unknown -> [ update c (Unknown (Some br_f)) state pc' ]
      in
      let temp = else_branch @ then_branch in

      temp
  | Stmt.While (br, blk) ->
      let blk' =
        Stmt.Block (blk :: [ Stmt.While (br, blk) @@ s.at ]) @@ blk.at
      in
      [
        update c
          (Cont ((Stmt.If (br, blk', None) @@ s.at) :: List.tl_exn stmts))
          state pc;
      ]
  | Stmt.Return e -> (
      let v = reduce_expr ~at:s.at store e in
      let frame, stack' = Call_stack.pop stack in
      match frame with
      | Call_stack.Intermediate (stmts', store', x, f') ->
          [
            update c (Cont stmts')
              (heap, S_store.add_exn store' x v, stack', f')
              pc;
          ]
      | Call_stack.Toplevel -> [ update c (Final (Some v)) state pc ])
  | Stmt.AssignCall (x, e, es) ->
      let f', vs = func s.at (reduce_expr ~at:s.at store e) in
      let vs' = vs @ List.map ~f:(reduce_expr ~at:s.at store) es in
      let func = Prog.get_func prog f' in
      let stack' =
        Call_stack.push stack
          (Call_stack.Intermediate (List.tl_exn stmts, store, x, f))
      in
      let store' =
        S_store.create (List.zip_exn (Prog.get_params prog f') vs')
      in
      [ update c (Cont [ func.body ]) (heap, store', stack', f') pc ]
  | Stmt.AssignECall (x, y, es) ->
      Crash.error s.at "'AssignECall' not implemented!"
  | Stmt.AssignNewObj x ->
      let obj = Obj.create () in
      let loc = Heap.insert heap obj in
      [
        update c
          (Cont (List.tl_exn stmts))
          (heap, S_store.add_exn store x (Val (Val.Loc loc)), stack, f)
          pc;
      ]
  | Stmt.AssignInObjCheck (x, e_field, e_loc) ->
      let locs = loc s.at (reduce_expr ~at:s.at store e_loc) in
      let field = reduce_expr ~at:s.at store e_field in
      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              let v = Heap.has_field heap' l field in
              update c
                (Cont (List.tl_exn stmts))
                (heap', S_store.add_exn store x v, stack, f)
                pc
              :: accum
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else
                let v = Heap.has_field heap l field in
                update c
                  (Cont (List.tl_exn stmts))
                  (Heap.clone heap, S_store.add_exn store x v, stack, f)
                  pc'
                :: accum)
  | Stmt.AssignObjToList (x, e) ->
      let f h l pc' =
        let v =
          match Heap.get h l with
          | None -> Crash.error s.at ("'" ^ l ^ "' not found in heap")
          | Some obj ->
              NOpt
                ( Operators.ListExpr,
                  List.map (Obj.to_list obj) ~f:(fun (f, v) ->
                      NOpt (Operators.TupleExpr, [ f; v ])) )
        in
        update c
          (Cont (List.tl_exn stmts))
          (h, S_store.add_exn store x v, stack, f)
          pc'
      in
      let locs = loc s.at (reduce_expr ~at:s.at store e) in
      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              f heap' l pc :: accum
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else f (Heap.clone heap) l pc' :: accum)
  | Stmt.AssignObjFields (x, e) ->
      let f h l pc' =
        let v =
          match Heap.get h l with
          | None -> Crash.error s.at ("'" ^ l ^ "' not found in heap")
          | Some obj -> NOpt (Operators.ListExpr, Obj.get_fields obj)
        in
        update c
          (Cont (List.tl_exn stmts))
          (h, S_store.add_exn store x v, stack, f)
          pc'
      in
      let locs = loc s.at (reduce_expr ~at:s.at store e) in
      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              f heap' l pc :: accum
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else f (Heap.clone heap) l pc' :: accum)
  | Stmt.FieldAssign (e_loc, e_field, e_v) ->
      let locs = loc s.at (reduce_expr ~at:s.at store e_loc) in
      let reduced_field = reduce_expr ~at:s.at store e_field
      and v = reduce_expr ~at:s.at store e_v in

      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              let objects =
                Heap.set_field heap' l reduced_field v solver (ESet.to_list pc)
                  store
              in
              List.map objects ~f:(fun (new_heap, new_pc) ->
                  let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                  update c
                    (Cont (List.tl_exn stmts))
                    (new_heap, store, stack, f)
                    pc')
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else
                let objects =
                  Heap.set_field heap l reduced_field v solver (ESet.to_list pc)
                    store
                in
                List.map objects ~f:(fun (new_heap, new_pc) ->
                    let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                    update c
                      (Cont (List.tl_exn stmts))
                      (new_heap, store, stack, f)
                      pc'))
  | Stmt.FieldDelete (e_loc, e_field) ->
      let locs = loc s.at (reduce_expr ~at:s.at store e_loc) in
      let reduced_field = reduce_expr ~at:s.at store e_field in

      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              let objects =
                Heap.delete_field heap' l reduced_field solver (ESet.to_list pc)
                  store
              in
              List.map objects ~f:(fun (new_heap, new_pc) ->
                  let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                  update c
                    (Cont (List.tl_exn stmts))
                    (new_heap, store, stack, f)
                    pc')
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else
                let objects =
                  Heap.delete_field heap l reduced_field solver
                    (ESet.to_list pc) store
                in
                List.map objects ~f:(fun (new_heap, new_pc) ->
                    let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                    update c
                      (Cont (List.tl_exn stmts))
                      (new_heap, store, stack, f)
                      pc'))
  | Stmt.FieldLookup (x, e_loc, e_field) ->
      let locs = loc s.at (reduce_expr ~at:s.at store e_loc) in
      let reduced_field = reduce_expr ~at:s.at store e_field in

      List.fold locs ~init:[] ~f:(fun accum (cond, l) ->
          match cond with
          | None ->
              let heap' =
                if List.length locs > 1 then Heap.clone heap else heap
              in
              let objects =
                Heap.get_field heap' l reduced_field solver (ESet.to_list pc)
                  store
              in
              List.map objects ~f:(fun (new_heap, new_pc, v) ->
                  let v' =
                    Option.value v ~default:(Val (Val.Symbol "undefined"))
                  in
                  let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                  update c
                    (Cont (List.tl_exn stmts))
                    (new_heap, S_store.add_exn store x v', stack, f)
                    pc')
          | Some cond' ->
              let pc' = ESet.add pc (Translator.translate cond') in
              if not (Batch.check_sat solver (ESet.to_list pc')) then accum
              else
                let objects =
                  Heap.get_field heap l reduced_field solver (ESet.to_list pc)
                    store
                in
                List.map objects ~f:(fun (new_heap, new_pc, v) ->
                    let v' =
                      Option.value v ~default:(Val (Val.Symbol "undefined"))
                    in
                    let pc' = List.fold new_pc ~init:pc ~f:ESet.add in
                    update c
                      (Cont (List.tl_exn stmts))
                      (new_heap, S_store.add_exn store x v', stack, f)
                      pc'))
  | Stmt.SymStmt (SymStmt.Assume e) -> (
      match reduce_expr ~at:s.at store e with
      | Val (Val.Bool b) ->
          if b then [ update c (Cont (List.tl_exn stmts)) state pc ] else []
      | e' ->
          let pc' = ESet.add pc (Translator.translate e') in
          let cont =
            if not (Batch.check_sat solver (ESet.to_list pc')) then []
            else [ update c (Cont (List.tl_exn stmts)) state pc' ]
          in
          Logging.print_endline
            (lazy
              ("assume (" ^ Expr.str e' ^ ") = "
              ^ Bool.to_string (List.length cont > 0)));
          cont)
  | Stmt.SymStmt (SymStmt.Evaluate (x, e)) ->
      let e' = Translator.translate (reduce_expr ~at:s.at store e) in
      let v =
        Option.map ~f:Translator.expr_of_value
          (Batch.eval solver e' (ESet.to_list pc))
      in
      let store' =
        S_store.add_exn store x (Option.value ~default:(Val Val.Null) v)
      in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]
  | Stmt.SymStmt (SymStmt.Maximize (x, e)) ->
      let e' = Translator.translate (reduce_expr ~at:s.at store e) in
      let v =
        Option.map ~f:Translator.expr_of_value
          (Optimizer.maximize opt e' (ESet.to_list pc))
      in
      let store' =
        S_store.add_exn store x (Option.value ~default:(Val Val.Null) v)
      in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]
  | Stmt.SymStmt (SymStmt.Minimize (x, e)) ->
      let e' = Translator.translate (reduce_expr ~at:s.at store e) in
      let v =
        Option.map ~f:Translator.expr_of_value
          (Optimizer.minimize opt e' (ESet.to_list pc))
      in
      let store' =
        S_store.add_exn store x (Option.value ~default:(Val Val.Null) v)
      in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]
  | Stmt.SymStmt (SymStmt.Is_symbolic (x, e)) ->
      let e' = reduce_expr ~at:s.at store e in
      let store' =
        S_store.add_exn store x (Val (Val.Bool (Expr.is_symbolic e')))
      in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]
  | Stmt.SymStmt (SymStmt.Is_sat (x, e)) ->
      let e' = reduce_expr ~at:s.at store e in
      let pc' = ESet.add pc (Translator.translate e') in
      let sat = Batch.check_sat c.solver (ESet.to_list pc') in
      let store' = S_store.add_exn store x (Val (Val.Bool sat)) in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]
  | Stmt.SymStmt (SymStmt.Is_number (x, e)) ->
      let e' = reduce_expr ~at:s.at store e in
      let is_num =
        match Sval_typing.type_of e' with
        | Some Type.IntType | Some Type.FltType -> true
        | _ -> false
      in
      let store' = S_store.add_exn store x (Val (Val.Bool is_num)) in
      [ update c (Cont (List.tl_exn stmts)) (heap, store', stack, f) pc ]

module type WorkList = sig
  type 'a t

  exception Empty

  val create : unit -> 'a t
  val push : 'a -> 'a t -> unit
  val pop : 'a t -> 'a
  val is_empty : 'a t -> bool
  val length : 'a t -> int
end

(* Source: Thanks to Joao Borges (@RageKnify) for writing this code *)
module TreeSearch (L : WorkList) = struct
  let eval c : State.config list =
    let w = L.create () in
    L.push c w;
    let out = ref [] in
    while not (L.is_empty w) do
      let c = L.pop w in
      match c.code with
      | Cont [] ->
          let _, _, _, f = c.state in
          Crash.error Source.no_region
            (sprintf "%s: eval: Empty continuation!" f)
      | Cont _ -> List.iter ~f:(fun c -> L.push c w) (step c)
      | Error v | Final v | Unknown v -> out := c :: !out
      | Failure (f, e) ->
          let e' = Option.value_map e ~default:"" ~f:Expr.str in
          Logging.print_endline (lazy (sprintf "Failure: %s: %s" f e'));
          out := c :: !out
    done;
    !out
end

module RandArray : WorkList = struct
  type 'a t = 'a BatDynArray.t

  exception Empty

  let create () = BatDynArray.create ()
  let is_empty a = BatDynArray.empty a
  let push v a = BatDynArray.add a v

  let pop a =
    let i = Random.int (BatDynArray.length a) in
    let v = BatDynArray.get a i in
    BatDynArray.delete a i;
    v

  let length = BatDynArray.length
end

module DFS = TreeSearch (Caml.Stack)
module BFS = TreeSearch (Caml.Queue)
module RND = TreeSearch (RandArray)

(* Source: Thanks to Joao Borges (@RageKnify) for writing this code *)
let invoke (prog : Prog.t) (func : Func.t)
    (eval : State.config -> State.config list) : State.config list =
  let heap = Heap.create ()
  and store = S_store.create []
  and stack = Call_stack.push Call_stack.empty Call_stack.Toplevel in
  let solver =
    let s = Batch.create () in
    if !Config.axioms then Batch.set_default_axioms s;
    s
  in
  let initial_config =
    {
      prog;
      code = Cont [ func.body ];
      state = (heap, store, stack, func.name);
      pc = ESet.empty;
      solver;
      opt = Optimizer.create ();
    }
  in
  eval initial_config

let analyse (prog : Prog.t) (f : State.func) (policy : string) :
    State.config list =
  let f = Prog.get_func prog f in
  let eval =
    match policy with
    | "breadth" -> BFS.eval
    | "depth" -> DFS.eval
    | "random" -> RND.eval
    | _ ->
        Crash.error f.body.at ("Invalid search policy '" ^ !Config.policy ^ "'")
  in
  invoke prog f eval

let main (prog : Prog.t) (f : State.func) : unit =
  let time_analysis = ref 0.0 in
  let configs =
    Time_utils.time_call time_analysis (fun () -> analyse prog f !Config.policy)
  in
  let testsuite_path = Filename.concat !Config.workspace "test-suite" in
  Io.safe_mkdir testsuite_path;
  let final_configs = List.filter ~f:(fun c -> State.is_final c.code) configs
  and error_configs = List.filter ~f:(fun c -> State.is_fail c.code) configs in
  let f c =
    let open Encoding in
    let pc' = State.ESet.to_list c.pc in
    let model = Batch.find_model c.solver pc' in
    let testcase =
      Option.value_map model ~default:[] ~f:(fun m ->
          List.map (Model.get_bindings m) ~f:(fun (s, v) ->
              let sort = Types.string_of_type (Symbol.type_of s)
              and name = Symbol.to_string s
              and interp = Value.to_string v in
              (sort, name, interp)))
    in
    let pc = (Expression.string_of_pc pc', Expression.to_smt pc') in
    let sink =
      match c.code with
      | Failure (sink, e) -> (sink, Option.value_map e ~default:"" ~f:Expr.str)
      | _ -> ("", "")
    in
    (sink, pc, testcase)
  in
  let serialize cs prefix =
    let cs' = List.map ~f cs in
    let prefix' = Filename.concat testsuite_path prefix in
    let sinks = List.map ~f:(fun (sink, _, _) -> sink) cs' in
    let queries = List.map ~f:(fun (_, pc, _) -> pc) cs' in
    let testsuite = List.map ~f:(fun (_, _, testcase) -> testcase) cs' in
    Report.serialise_sinks sinks prefix';
    Report.serialise_queries queries prefix';
    Report.serialise_testsuite testsuite prefix'
  in
  serialize final_configs "testcase";
  serialize error_configs "witness";
  Report.serialise_report
    (Filename.concat !Config.workspace "report.json")
    !Config.file (List.length configs)
    (List.length error_configs)
    0 !time_analysis !Batch.solver_time
