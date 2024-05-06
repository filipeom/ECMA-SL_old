module ExecutionTime = struct
  type t =
    { start : float
    ; stop : float
    ; diff : float
    }

  let create () : t = { start = -1.0; stop = -1.0; diff = -1.0 } [@@inline]
  let start (ts : t) : t = { ts with start = Sys.time () } [@@inline]
  let diff (ts : t) : t = { ts with diff = ts.stop -. ts.start } [@@inline]
  let stop (ts : t) : t = diff @@ { ts with stop = Sys.time () } [@@inline]
  let json (ts : t) : Yojson.t = `Assoc [ ("exec_time", `Float ts.diff) ]
end

module MemoryUsage = struct
  type t =
    { heap_n : int
    ; heap_sz : int
    }

  let create () : t = { heap_n = 0; heap_sz = 0 } [@@inline]

  let calculate (heap : 'a Heap.t) : t =
    let heap_n = Heap.length heap in
    let heap_sz = Obj.(reachable_words (repr heap.map)) in
    { heap_n; heap_sz }

  let json (mem : t) : Yojson.t =
    `Assoc
      [ ("objs_allocated", `Int mem.heap_n); ("heap_size", `Int mem.heap_sz) ]
end

module ProgCounter = struct
  type t =
    { calls : int
    ; stmts : int
    ; exprs : int
    }

  type item =
    [ `Call
    | `Stmt
    | `Expr
    ]

  let create () : t = { calls = 0; stmts = 0; exprs = 0 } [@@inline]

  let count (ctr : t) (item : item) : t =
    match item with
    | `Call -> { ctr with calls = ctr.calls + 1 }
    | `Stmt -> { ctr with stmts = ctr.stmts + 1 }
    | `Expr -> { ctr with exprs = ctr.exprs + 1 }

  let json (ctr : t) : Yojson.t =
    `Assoc
      [ ("func_calls", `Int ctr.calls)
      ; ("stmt_evals", `Int ctr.stmts)
      ; ("expr_evals", `Int ctr.exprs)
      ]
end

module type M = sig
  type t'
  type t = t' ref

  val initial_state : unit -> t
  val start : t -> unit
  val stop : t -> 'a Heap.t -> unit
  val count : t -> ProgCounter.item -> unit
  val json : t -> Yojson.t
end

module Disable : M = struct
  type t' = unit
  type t = t' ref

  let initial_state () : t = ref ()
  let start (_ : t) : unit = ()
  let stop (_ : t) (_ : 'a Heap.t) : unit = ()
  let count (_ : t) (_ : ProgCounter.item) : unit = ()
  let json (_ : t) : Yojson.t = `Assoc []
end

module Time : M = struct
  type t' = { timer : ExecutionTime.t }
  type t = t' ref

  let initial_state' () : t' = { timer = ExecutionTime.create () }
  let initial_state () : t = ref (initial_state' ())

  let start (metrics : t) : unit =
    let timer = ExecutionTime.start !metrics.timer in
    metrics := { timer }

  let stop (metrics : t) (_ : 'a Heap.t) : unit =
    let timer = ExecutionTime.stop !metrics.timer in
    metrics := { timer }

  let count (_ : t) (_ : ProgCounter.item) : unit = ()

  let json (metrics : t) : Yojson.t =
    `Assoc [ ("timer", ExecutionTime.json !metrics.timer) ]
end

module Full : M = struct
  type t' =
    { timer : ExecutionTime.t
    ; memory : MemoryUsage.t
    ; counter : ProgCounter.t
    }

  type t = t' ref

  let initial_state' () : t' =
    { timer = ExecutionTime.create ()
    ; memory = MemoryUsage.create ()
    ; counter = ProgCounter.create ()
    }

  let initial_state () : t = ref (initial_state' ())

  let start (metrics : t) : unit =
    let timer = ExecutionTime.start !metrics.timer in
    metrics := { !metrics with timer }

  let stop (metrics : t) (heap : 'a Heap.t) : unit =
    let timer = ExecutionTime.stop !metrics.timer in
    let memory = MemoryUsage.calculate heap in
    metrics := { !metrics with timer; memory }

  let count (metrics : t) (item : ProgCounter.item) : unit =
    let counter = ProgCounter.count !metrics.counter item in
    metrics := { !metrics with counter }

  let json (metrics : t) : Yojson.t =
    `Assoc
      [ ("timer", ExecutionTime.json !metrics.timer)
      ; ("memory", MemoryUsage.json !metrics.memory)
      ; ("counter", ProgCounter.json !metrics.counter)
      ]
end
