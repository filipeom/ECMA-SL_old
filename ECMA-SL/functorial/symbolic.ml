module Value = Symbolic_value.M
module Store = Value.Store
module Object = Symbolic_object.M
module Memory = Symbolic_memory
module Env = Link_env.Make (Memory)
module Thread = Choice_monad.Thread
module Translator = Value_translator

let ( let* ) o f = match o with Error e -> failwith e | Ok o -> f o

module P = struct
  type value = Value.value
  type store = Store.t
  type memory = Memory.t
  type object_ = Object.t

  module Value = struct
    include Value
  end

  module Choice = Choice_monad.List
  module Extern_func = Extern_func.Make (Value) (Choice)

  type extern_func = Extern_func.extern_func
  type env = extern_func Env.t

  module Store = struct
    type bind = string
    type t = store

    let create = Store.create
    let mem = Store.mem
    let add_exn = Store.add_exn
    let find = Store.find
  end

  module Object = struct
    type t = object_
    type nonrec value = value

    let create = Object.create
    let to_string = Object.to_string
    let set = Object.set

    let get o key =
      let vals = Object.get o key in
      let return thread (v, pc) =
        let pc_thread = Thread.pc thread in
        let solver = Thread.solver thread in
        match pc with
        | [] -> Some (Some v, thread)
        | _ ->
          let pc' = List.map Translator.translate pc in
          if not (Solver.check solver (pc' @ pc_thread)) then None
          else Some (Some v, List.fold_left Thread.add_pc thread pc')
      in
      match vals with
      | [] -> fun thread -> [ (None, thread) ]
      | [ (v, pc) ] ->
        fun thread ->
          Option.fold ~none:[] ~some:(fun r -> [ r ]) (return thread (v, pc))
      | _ ->
        fun thread ->
          let thread = Thread.clone_mem thread in
          List.filter_map (return thread) vals

    let delete = Object.delete
    let to_list = Object.to_list
    let has_field = Object.has_field
    let get_fields = Object.get_fields
  end

  module Memory = struct
    type t = memory
    type nonrec object_ = object_
    type nonrec value = value

    let create = Memory.create
    let clone = Memory.clone
    let insert = Memory.insert
    let remove = Memory.remove
    let set = Memory.set
    let get = Memory.get
    let has_field = Memory.has_field

    let get_field h loc v =
      let field_vals = Memory.get_field h loc v in
      let return thread (v, pc) =
        let pc_thread = Thread.pc thread in
        let solver = Thread.solver thread in
        match pc with
        | [] -> Some (Some v, thread)
        | _ ->
          let pc' = List.map Translator.translate pc in
          if not (Solver.check solver (pc' @ pc_thread)) then None
          else Some (Some v, List.fold_left Thread.add_pc thread pc')
      in
      match field_vals with
      | [] -> fun thread -> [ (None, thread) ]
      | [ (v, pc) ] ->
        fun thread ->
          Option.fold ~none:[] ~some:(fun r -> [ r ]) (return thread (v, pc))
      | _ ->
        fun thread ->
          let thread = Thread.clone_mem thread in
          List.filter_map (return thread) field_vals

    let set_field = Memory.set_field
    let delete_field = Memory.delete_field
    let to_string h = Format.asprintf "%a" Memory.pp h

    let loc v =
      let* locs = Memory.loc v in
      let return thread (cond, v) =
        let pc = Thread.pc thread in
        let solver = Thread.solver thread in
        match cond with
        | None -> Some (v, thread)
        | Some c ->
          let c' = Translator.translate c in
          if not (Solver.check solver (c' :: pc)) then None
          else Some (v, Thread.add_pc thread c')
      in
      match locs with
      | [] ->
        fun _thread ->
          Log.warn "no loc";
          []
      | [ (c, v) ] ->
        fun thread ->
          Option.fold ~none:[] ~some:(fun a -> [ a ]) (return thread (c, v))
      | _ ->
        fun thread ->
          let thread = Thread.clone_mem thread in
          List.filter_map (return thread) locs

    let pp = Memory.pp
    let pp_val = Memory.pp_val
  end

  module Env = struct
    type t = env
    type nonrec memory = memory

    let clone = Env.clone

    let get_memory _env thread =
      (* Env.get_memory env *)
      [ (Thread.mem thread, thread) ]

    let get_func = Env.get_func
    let get_extern_func = Env.get_extern_func
    let add_memory = Env.add_memory

    module Build = struct
      let empty = Env.Build.empty
      let add_memory = Env.Build.add_memory
      let add_functions = Env.Build.add_functions
      let add_extern_functions = Env.Build.add_extern_functions
    end
  end

  module Reducer = struct
    let reduce = Value_reducer.reduce
  end
end

module P' : Interpreter_functor_intf.P = P
