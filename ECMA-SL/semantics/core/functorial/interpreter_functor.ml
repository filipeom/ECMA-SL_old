open EslBase
open EslSyntax

module Make (P : Interpreter_functor_intf.P) :
  Interpreter_functor_intf.S
    with type env := P.env
     and type 'a choice := 'a P.Choice.t
     and type value = P.value = struct
  module Value = P.Value
  module Extern_func = P.Extern_func
  module Store = P.Store
  module Object = P.Object
  module Memory = P.Memory
  module Env = P.Env
  module Choice = P.Choice
  module Reducer = P.Reducer
  open Choice

  let ( @> ) = Source.( @> )

  type value = P.value
  type store = P.store

  module State = struct
    type store = Store.t
    type env = P.env
    type err = Extern_func.err

    type exec_state =
      { return_state : (exec_state * string) option
      ; locals : store
      ; stmts : Stmt.t list
      ; env : env
      ; func : string
      }

    let empty_state ~env =
      { return_state = None
      ; locals = Store.create []
      ; stmts = []
      ; env
      ; func = ""
      }

    type return_result = (value list, err) Result.t

    type stmt_result =
      | Return of return_result
      | Continue of exec_state

    let return ?(value : value option) (state : exec_state) : stmt_result =
      match state.return_state with
      | None -> Return (Ok (Option.to_list value))
      | Some (state', ret_v) ->
        let v =
          match value with
          | None -> Value.(mk_tuple (Bool.const false, mk_symbol "undefined"))
          | Some v -> v
        in
        let locals = Store.add_exn state'.locals ret_v v in
        Continue { state' with locals; env = state.env }
  end

  let eval_expr (sto : store) (e : Expr.t) : value =
    (* TODO: decouple Reducer from abstract values *)
    (* Reduce is only used on Sym_value.M.value *)
    Value.eval_expr sto e |> Reducer.reduce

  let pp locals heap e = eval_expr locals e |> Memory.pp_val heap

  (* FIXME: Somehow using the functions in Log seems to considerably slowdown exec *)
  let debug k = if !Log.Config.debugs then k Fmt.eprintf

  let exec_func state func args ret_var =
    debug (fun k -> k "calling func: %s@." (Func.name' func));
    let return_state = Some (state, ret_var) in
    let params = Func.params' func in
    let store = Store.create (List.combine params args) in
    let state' =
      State.
        { return_state
        ; locals = store
        ; stmts = [ Func.body func ]
        ; env = state.env
        ; func = Func.name' func
        }
    in
    Choice.return @@ State.Continue state'

  let exec_extern_func state f args ret_var =
    let open Extern_func in
    let rec apply : type a.
         value list
      -> a Extern_func.atype
      -> a
      -> (value, Extern_func.err) Result.t Choice.t =
     fun args ty f ->
      match ty with
      | UArg ty' -> apply args ty' (f ())
      | Arg ty' ->
        let v = List.hd args in
        apply (List.tl args) ty' (f v)
      | Res -> f
    in
    let (Extern_func (Func atype, func)) = f in
    let+ v = apply args atype func in
    match v with
    | Error msg -> State.Return (Error msg)
    | Ok v ->
      let locals = Store.add_exn state.State.locals ret_var v in
      State.Continue State.{ state with locals }

  let exec_stmt stmt ({ locals; env; _ } as state : State.exec_state) :
    State.stmt_result Choice.t =
    let open State in
    let ok st = Choice.return @@ State.Continue st in
    let error err = Choice.return @@ State.Return (Error err) in
    let* m = Env.get_memory env in
    (* debug2 "      store : %a@." Value.Store.pp locals; *)
    debug (fun k -> k "running stmt: %a@." Stmt.pp_simple stmt);
    match stmt.it with
    | Skip -> ok state
    | Merge -> ok state
    | Debug stmt ->
      Format.eprintf "ignoring break point in line %d" stmt.at.left.line;
      ok { state with stmts = stmt :: state.stmts }
    | Fail e ->
      let e' = pp locals m e in
      Log.log ~header:false "       fail : %s" e';
      error (`Failure (Fmt.sprintf "%s" e'))
    | Print e ->
      Format.printf "%s@." (pp locals m e);
      ok state
    | Assign (x, e) ->
      let v = eval_expr locals e in
      ok { state with locals = Store.add_exn locals x.it v }
    | Assert e ->
      let e' = eval_expr locals e in
      let* b = Choice.check_add_true @@ Value.Bool.not_ e' in
      if b then (
        Log.log ~header:false "     assert : failure with (%a)" Value.pp e';
        error (`Assert_failure e') )
      else ok state
    | Block blk -> ok { state with stmts = blk @ state.stmts }
    | If (br, blk1, blk2) ->
      let br = eval_expr locals br in
      let* b = Choice.branch br in
      let stmts =
        if b then blk1 :: state.stmts
        else
          match blk2 with
          | None -> state.stmts
          | Some stmt -> stmt :: state.stmts
      in
      ok { state with stmts }
    | While (br, blk) ->
      let blk' = Stmt.Block (blk :: [ stmt ]) @> blk.at in
      let stmts = (Stmt.If (br, blk', None) @> stmt.at) :: state.stmts in
      ok { state with stmts }
    | Return e ->
      Choice.return @@ State.return state ~value:(eval_expr locals e)
    | AssignCall (x, f, es) -> (
      match Value.func (eval_expr locals f) with
      | Error msg -> error (`Failure (Fmt.sprintf "%s" msg))
      | Ok (func_name, args0) -> (
        match Env.get_func env func_name with
        | Error msg -> error (`Failure (Fmt.sprintf "%s" msg))
        | Ok func ->
          let args = List.map (eval_expr locals) es in
          let args = args0 @ args in
          exec_func state func args x.it ) )
    | AssignECall (x, f, es) -> (
      match Env.get_extern_func env f.it with
      | Error msg -> error (`Failure (Fmt.sprintf "%s" msg))
      | Ok func ->
        let args = List.map (eval_expr locals) es in
        exec_extern_func state func args x.it )
    | AssignNewObj x ->
      let* heap = Env.get_memory env in
      let obj = Object.create () in
      let loc = Memory.insert heap obj in
      ok { state with locals = Store.add_exn locals x.it loc }
    | AssignInObjCheck (x, e_field, e_loc) ->
      let field = eval_expr locals e_field in
      let loc = eval_expr locals e_loc in
      let* loc = Memory.loc loc in
      (* `get_memory` comes after `Memory.loc` due to branching *)
      let* heap = Env.get_memory env in
      let v = Memory.has_field heap loc field in
      ok { state with locals = Store.add_exn locals x.it v }
    | AssignObjToList (x, e) -> (
      let loc = eval_expr locals e in
      let* loc = Memory.loc loc in
      let* heap = Env.get_memory env in
      match Memory.get heap loc with
      | None ->
        error (`Failure (Fmt.asprintf "'%a' not found in heap" Loc.pp loc))
      | Some o ->
        let v = Value.mk_list (List.map Value.mk_tuple (Object.to_list o)) in
        ok { state with locals = Store.add_exn locals x.it v } )
    | AssignObjFields (x, e) -> (
      let loc = eval_expr locals e in
      let* loc = Memory.loc loc in
      let* heap = Env.get_memory env in
      match Memory.get heap loc with
      | None ->
        error (`Failure (Fmt.asprintf "'%a' not found in heap" Loc.pp loc))
      | Some o ->
        let v = Value.mk_list @@ Object.get_fields o in
        ok { state with locals = Store.add_exn locals x.it v } )
    | FieldAssign (e_loc, e_field, e_v) ->
      let loc = eval_expr locals e_loc in
      let field = eval_expr locals e_field in
      let v = eval_expr locals e_v in
      let* loc = Memory.loc loc in
      let* heap = Env.get_memory env in
      Memory.set_field heap loc ~field ~data:v;
      ok state
    | FieldDelete (e_loc, e_field) ->
      let loc = eval_expr locals e_loc in
      let field = eval_expr locals e_field in
      let* loc = Memory.loc loc in
      let* heap = Env.get_memory env in
      Memory.delete_field heap loc field;
      ok state
    | FieldLookup (x, e_loc, e_field) ->
      let loc = eval_expr locals e_loc in
      let field = eval_expr locals e_field in
      let* loc = Memory.loc loc in
      let* heap = Env.get_memory env in
      let* value = Memory.get_field heap loc field in
      let value' = Option.value value ~default:(Value.mk_symbol "undefined") in
      ok { state with locals = Store.add_exn locals x.it value' }
    | Switch (cond, cases, default) -> (
      let cond = eval_expr locals cond in
      let* id = Choice.select_val cond in
      match (Hashtbl.find_opt cases id, default) with
      | (Some { it = Block ss; at }, _) | (None, Some { it = Block ss; at }) ->
        let stmts = ss @ ((Stmt.Merge @> at) :: state.stmts) in
        ok { state with stmts }
      | (Some _, _) ->
        (* TODO: *)
        (* Eslerr.internal __FUNCTION__ (Expecting "switch block") *)
        error (`Failure "Expecting switch block")
      | (None, Some _) ->
        (* TODO: *)
        (* Eslerr.internal __FUNCTION__ (Expecting "sdflt block") *)
        error (`Failure "Expecting sdflt block")
      | (None, None) -> ok state )

  let rec loop (state : State.exec_state) : State.return_result Choice.t =
    let open State in
    match state.stmts with
    | stmt :: stmts -> (
      let* state = exec_stmt stmt { state with stmts } in
      match state with
      | Continue state -> loop state
      | Return ret -> Choice.return ret )
    | [] -> (
      Log.log ~header:false "    warning : %s: missing a return statement!@."
        state.func;
      match State.return state with
      | Continue state -> loop state
      | Return ret -> Choice.return ret )

  let main (env : Env.t) (f : string) : State.return_result Choice.t =
    match Env.get_func env f with
    | Error msg -> Choice.return (Error (`Failure msg))
    | Ok f ->
      let state = State.empty_state ~env in
      loop State.{ state with stmts = [ Func.body f ]; func = Func.name' f }
end
