module Value = Sym_value.M
module Store = Sym_value.M.Store
module Object = Sym_heap2.Object
module Heap = Sym_heap2.Heap
module Env = Link_env.Make (Heap)

module P = struct
  type value = Value.value
  type store = Store.t
  type memory = Heap.t
  type object_ = Object.t

  module Value = struct
    include Value
  end

  module Extern_func = Extern_func.Make (Value)

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
    let get = Object.get
    let delete = Object.delete
    let to_list = Object.to_list
    let has_field = Object.has_field
    let get_fields = Object.get_fields
  end

  module Heap = struct
    type t = memory
    type nonrec object_ = object_
    type nonrec value = value

    let create = Heap.create
    let clone = Heap.clone
    let insert = Heap.insert
    let remove = Heap.remove
    let set = Heap.set
    let get = Heap.get
    let has_field = Heap.has_field
    let get_field = Heap.get_field
    let set_field = Heap.set_field
    let delete_field = Heap.delete_field
    let to_string = Heap.to_string
    let loc = Heap.loc
  end

  module Env = struct
    type t = env
    type nonrec memory = memory

    let clone = Env.clone
    let get_memory = Env.get_memory
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

  module Translator = struct
    let translate = Value_translator.translate
    let expr_of_value = Value_translator.expr_of_value
  end

  module Choice = struct
    open Value

    let assertion solver pc c =
      match c with
      | Val (Val.Bool b) -> b
      | v ->
          let v' = Translator.translate (Value.Bool.not_ v) in
          not (Batch.check solver (v' :: pc))

    let assumption c = match c with Val (Val.Bool b) -> Some b | _ -> None

    let branch solver pc c =
      match c with
      | Val (Val.Bool b) -> ((b, None), (not b, None))
      | v ->
          let cond = Translator.translate v in
          let no = Translator.translate @@ Value.Bool.not_ v in
          let t_branch = Batch.check solver (cond :: pc) in
          let f_branch = Batch.check solver (no :: pc) in
          ((t_branch, Some cond), (f_branch, Some no))
  end
end

module P' : Eval_functor_intf.P = P
