open EslBase
open EslSyntax
module Value = Symbolic_value.M
module Memory = Symbolic_memory
module Translator = Value_translator
module Optimizer = Smtml.Optimizer.Z3

module PC = struct
  include Set.Make (struct
    include Smtml.Expr

    let compare = compare
  end)

  let to_list (s : t) = elements s [@@inline]
end

module Thread = struct
  type t =
    { solver : Solver.t
    ; pc : PC.t
    ; mem : Memory.t
    ; optimizer : Optimizer.t
    }

  let create () =
    { solver =
        Solver.create ~params:Smtml.Params.(default () $ (Timeout, 60000)) ()
    ; pc = PC.empty
    ; mem = Memory.create ()
    ; optimizer = Optimizer.create ()
    }

  let solver t = t.solver
  let pc t = t.pc
  let mem t = t.mem
  let optimizer t = t.optimizer

  let add_pc t (v : Smtml.Expr.t) =
    match Smtml.Expr.view v with
    | Val True -> t
    | _ -> { t with pc = PC.add v t.pc }

  let clone { solver; optimizer; pc; mem } =
    let mem = Memory.clone mem in
    { solver; optimizer; pc; mem }
end

module Seq = struct
  type thread = Thread.t
  type 'a t = thread -> ('a * thread) Seq.t

  let return (v : 'a) : 'a t = fun t -> Seq.return (v, t)
  let empty : 'a t = fun _ -> Seq.empty
  let run (v : 'a t) (thread : thread) = v thread

  let bind (v : 'a t) (f : 'a -> 'b t) : 'b t =
   fun t ->
    let result = run v t in
    Seq.flat_map (fun (r, t') -> run (f r) t') result

  let ( let* ) v f = bind v f
  let map (v : 'a t) (f : 'a -> 'b) : 'b t = bind v (fun a -> return (f a))
  let ( let+ ) v f = map v f

  let with_state (f : thread -> 'a) : 'a t =
   fun (state : thread) ->
    let result = f state in
    Seq.return (result, state)

  let check (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> Seq.return (b, t)
      | _ -> (
        let cond = Translator.translate v in
        let pc = PC.(add cond pc |> elements) in
        match Solver.check solver pc with
        | `Sat -> Seq.return (true, t)
        | `Unsat -> Seq.return (false, t)
        | `Unknown ->
          Format.eprintf "Unknown pc: %a@." Smtml.Expr.pp_list pc;
          Seq.empty )

  let check_add_true (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> Seq.return (b, t)
      | _ -> (
        let cond' = Translator.translate v in
        let pc = PC.(add cond' pc |> elements) in
        match Solver.check solver pc with
        | `Sat -> Seq.return (true, Thread.add_pc t cond')
        | `Unsat -> Seq.return (false, t)
        | `Unknown ->
          Format.eprintf "Unknown pc: %a@." Smtml.Expr.pp_list pc;
          Seq.empty )

  let branch (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> Seq.return (b, t)
      | _ -> (
        let with_v = PC.add (Translator.translate v) pc in
        let with_no = PC.add (Translator.translate @@ Value.Bool.not_ v) pc in
        let sat_true =
          if PC.equal with_v pc then true
          else `Sat = Solver.check solver (PC.elements with_v)
        in
        let sat_false =
          if PC.equal with_no pc then true
          else `Sat = Solver.check solver (PC.to_list with_no)
        in
        match (sat_true, sat_false) with
        | (false, false) -> Seq.empty
        | (true, false) | (false, true) -> Seq.return (sat_true, t)
        | (true, true) ->
          let t0 = Thread.clone t in
          let t1 = Thread.clone t in
          List.to_seq
            [ (true, { t0 with pc = with_v })
            ; (false, { t1 with pc = with_no })
            ] )

  let select_val (v : Value.value) thread =
    match v with
    | Val v -> Seq.return (v, thread)
    | _ -> Log.err "Unable to select value from %a" Value.pp v

  let from_list vs : 'a t =
   fun (thread : thread) -> List.to_seq @@ List.map (fun v -> (v, thread)) vs
end

module List = struct
  type thread = Thread.t
  type 'a t = thread -> ('a * thread) list

  let return (v : 'a) : 'a t = fun t -> [ (v, t) ]
  let empty : 'a t = fun _ -> []
  let run (v : 'a t) (thread : thread) = v thread

  let bind (v : 'a t) (f : 'a -> 'b t) : 'b t =
   fun t ->
    let lst = run v t in
    match lst with
    | [] -> []
    | [ (r, t') ] -> run (f r) t'
    | _ -> List.concat_map (fun (r, t') -> run (f r) t') lst

  let ( let* ) v f = bind v f
  let map (v : 'a t) (f : 'a -> 'b) : 'b t = bind v (fun a -> return (f a))
  let ( let+ ) v f = map v f

  let with_state (f : thread -> 'a) : 'a t =
   fun (state : thread) ->
    let result = f state in
    [ (result, state) ]

  let check (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> [ (b, t) ]
      | _ -> (
        let cond = Translator.translate v in
        let pc = PC.(add cond pc |> elements) in
        match Solver.check solver pc with
        | `Sat -> [ (true, t) ]
        | `Unsat -> [ (false, t) ]
        | `Unknown ->
          Format.eprintf "Unknown pc: %a@." Smtml.Expr.pp_list pc;
          [] )

  let check_add_true (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> [ (b, t) ]
      | _ -> (
        let cond' = Translator.translate v in
        let pc = PC.(add cond' pc |> elements) in
        match Solver.check solver pc with
        | `Sat -> [ (true, Thread.add_pc t cond') ]
        | `Unsat -> [ (false, t) ]
        | `Unknown ->
          Format.eprintf "Unknown pc: %a@." Smtml.Expr.pp_list pc;
          [] )

  let branch (v : Value.value) : bool t =
    let open Value in
    fun t ->
      let solver = Thread.solver t in
      let pc = Thread.pc t in
      match v with
      | Val (Val.Bool b) -> [ (b, t) ]
      | _ -> (
        let with_v = PC.add (Translator.translate v) pc in
        let with_no = PC.add (Translator.translate @@ Value.Bool.not_ v) pc in
        let sat_true =
          if PC.equal with_v pc then true
          else `Sat = Solver.check solver (PC.elements with_v)
        in
        let sat_false =
          if PC.equal with_no pc then true
          else `Sat = Solver.check solver (PC.to_list with_no)
        in
        match (sat_true, sat_false) with
        | (false, false) -> []
        | (true, false) | (false, true) -> [ (sat_true, t) ]
        | (true, true) ->
          let t0 = Thread.clone t in
          let t1 = Thread.clone t in
          [ (true, { t0 with pc = with_v }); (false, { t1 with pc = with_no }) ]
        )

  let select_val (v : Value.value) thread =
    match v with
    | Val v -> [ (v, thread) ]
    | _ -> Log.err "Unable to select value from %a" Value.pp v

  let from_list vs : 'a t =
   fun (thread : thread) -> List.map (fun v -> (v, thread)) vs
end

module P : Choice_monad_intf.Complete with module V := Value = Seq
