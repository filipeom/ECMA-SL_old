open EslBase
open EslSyntax
open EslBase.Fmt

type heap = Val.t Heap.t
type heapval = heap * Val.t

module Config = struct
  let trace_loc : bool ref = ref false
  let trace_depth : int option ref = ref None
  let width : int = Terminal.width Unix.stderr
end

module InterpreterCallbacks = struct
  type heapval_pp = (Loc.t, unit) Hashtbl.t -> heap -> Fmt.t -> Val.t -> unit
  type resolve_func_retval = Val.t -> (Val.t, string) Result.t

  type t =
    { heapval_pp : heapval_pp
    ; resolve_func_retval : resolve_func_retval
    }

  let heapval_pp : heapval_pp ref =
    let err = "tracer value printer not initialized" in
    ref (fun _ _ _ -> Internal_error.(throw __FUNCTION__ (Custom err)))

  let resolve_func_retval : resolve_func_retval ref =
    let err = "tracer retval resolver not initialized" in
    ref (fun _ -> Internal_error.(throw __FUNCTION__ (Custom err)))

  let set (interp_callbacks : t) : unit =
    heapval_pp := interp_callbacks.heapval_pp;
    resolve_func_retval := interp_callbacks.resolve_func_retval
end

let set_interp_callbacks (interp_callbacks : InterpreterCallbacks.t) : unit =
  InterpreterCallbacks.set interp_callbacks

module Truncate = struct
  let prepare (str_el : 'a -> string) (el : 'a) : string * int =
    str_el el |> fun s -> (s, String.length s)

  let limit_indent (lvl : int) : int = Config.width - (lvl * 2)

  let limit_el (lim : int) (factor : int) (weight : int) (rest : int) : int =
    max (lim * weight / factor) (lim - rest)

  let pp (lim : int) (pp_el : t -> 'a -> unit) (fmt : Fmt.t) (el : 'a) : unit =
    let extra = Font.str_text_err [ Font.Faint ] "..." in
    let text = asprintf "%a" pp_el el in
    let (text', trunc) = String.truncate (lim - 3) text in
    pp_str fmt (if trunc then text' ^ extra else text')
end

let indent_pp (fmt : Fmt.t) (lvl : int) : unit =
  let indent = Array.make lvl "| " |> Array.to_list |> String.concat "" in
  Font.pp_text_err [ Faint ] fmt indent

let region_pp (limit : int) (fmt : Fmt.t) (at : Source.region) : unit =
  let open Source in
  let pp_region' fmt at = fprintf fmt "(%s:%d)" at.file at.left.line in
  Font.pp_err [ Italic; Faint ] (Truncate.pp limit pp_region') fmt at

let cond_region_pp (lvl : int) (fmt : Fmt.t) (at : Source.region) : unit =
  let limit = Truncate.limit_indent lvl in
  let pp fmt () = fprintf fmt "\n%a%a" indent_pp lvl (region_pp limit) at in
  pp_cond !Config.trace_loc pp fmt ()

let highlight_pp (limit : int) (fmt : Fmt.t) (v_str : string) : unit =
  (Font.pp_err [ Cyan ] (Truncate.pp limit pp_str)) fmt v_str

let func_signature (f_str : string) : string =
  let regex = Str.regexp "function[ \n\r\x0c\t]*\\([^)]+)\\)" in
  ignore (Str.search_forward regex f_str 0);
  Str.matched_group 1 f_str

let heapval (heap : heap) (v : Val.t) : string =
  let pp_loc fmt = function
    | Val.Loc l -> fprintf fmt " (%a)" Loc.pp l
    | _ -> ()
  in
  let visited = Hashtbl.create !Base.default_hashtbl_sz in
  asprintf "%a%a" (!InterpreterCallbacks.heapval_pp visited heap) v pp_loc v

let log_level (lvl : int) : bool =
  let log_lvl' max_lvl = lvl < max_lvl in
  Option.fold ~none:true ~some:log_lvl' !Config.trace_depth

module type CODE_FMT = sig
  val log_expr : Expr.t -> bool
  val log_stmt : Stmt.t -> bool
  val expr_str : Expr.t -> string
  val func_str : Func.t -> string
  val stmt_pp : Fmt.t -> Stmt.t -> unit
end

module EslCodeFmt : CODE_FMT = struct
  let log_expr (e : Expr.t) : bool =
    e.at.real && match e.it with Val _ -> false | _ -> true

  let log_stmt (s : Stmt.t) : bool =
    s.at.real && match s.it with Skip | Merge | Block _ -> false | _ -> true

  let func_str (f : Func.t) : string = Source.Code.str f.at
  let expr_str (e : Expr.t) : string = Source.Code.str e.at
  let stmt_pp (fmt : Fmt.t) (s : Stmt.t) : unit = Source.Code.pp fmt s.at
end

module CeslCodeFmt : CODE_FMT = struct
  let log_expr (e : Expr.t) : bool =
    match e.it with Val _ -> false | _ -> true

  let log_stmt (s : Stmt.t) : bool =
    match s.it with Skip | Merge | Block _ -> false | _ -> true

  let func_str (f : Func.t) : string = Func.str ~simple:true f
  let expr_str (e : Expr.t) : string = Expr.str e
  let stmt_pp (fmt : Fmt.t) (s : Stmt.t) : unit = Stmt.pp fmt s
end

module CallFmt = struct
  let call_str (f : Func.t) (s : Stmt.t) : string =
    match s.it with
    | AssignCall _ | AssignECall _ -> Source.Code.str s.at
    | _ -> func_signature (Source.Code.str f.at)

  let pp_call (header : string) (fmt : Fmt.t)
    ((lvl, f, s) : int * Func.t * Stmt.t) : unit =
    let limit = Truncate.limit_indent lvl - 7 in
    let pp_call = Font.pp_err [ Cyan ] (Truncate.pp limit pp_str) in
    fprintf fmt "%a%a %s%a" indent_pp lvl pp_call (call_str f s) header
      (cond_region_pp lvl) s.at

  let pp_return (heap : heap) (fmt : Fmt.t)
    ((lvl, f, s, v) : int * Func.t * Stmt.t * Val.t) : unit =
    let retval_format v =
      match !InterpreterCallbacks.resolve_func_retval v with
      | Ok v' -> ("returned ", v')
      | Error err -> ("throwed ", Val.Str err)
    in
    let (header, v') = retval_format v in
    let (fn_str, fn_len) = Truncate.prepare Func.name' f in
    let (v_str, v_len) = Truncate.prepare (heapval heap) v' in
    let limit = Truncate.limit_indent lvl - String.length header - 1 in
    let limit_f = Truncate.limit_el limit 4 3 v_len in
    let limit_v = Truncate.limit_el limit 4 1 fn_len in
    let pp_fname = Font.pp_err [ Cyan ] (Truncate.pp limit_f pp_str) in
    fprintf fmt "%a%a %s%a%a" indent_pp lvl pp_fname fn_str header
      (highlight_pp limit_v) v_str (cond_region_pp lvl) s.at
end

module DefaultFmt (CodeFmt : CODE_FMT) = struct
  let pp_expr (heap : heap) (fmt : Fmt.t) ((lvl, e, v) : int * Expr.t * Val.t) :
    unit =
    let lvl' = lvl + 1 in
    let (e_str, e_len) = Truncate.prepare CodeFmt.expr_str e in
    let (v_str, v_len) = Truncate.prepare (heapval heap) v in
    let limit = Truncate.limit_indent lvl' - 11 in
    let limit_e = Truncate.limit_el limit 2 1 v_len in
    let limit_v = Truncate.limit_el limit 2 1 e_len in
    let pp_eval = Font.pp_text_err [ Italic ] in
    let pp_expr = Truncate.pp limit_e pp_str in
    fprintf fmt "%a- %a %a -> %a" indent_pp lvl' pp_eval "eval" pp_expr e_str
      (highlight_pp limit_v) v_str

  let pp_stmt (fmt : Fmt.t) ((lvl, s) : int * Stmt.t) : unit =
    let lvl' = lvl + 1 in
    let limit = Truncate.limit_indent lvl' in
    let pp_stmt = Font.pp_err [ Cyan ] (Truncate.pp limit CodeFmt.stmt_pp) in
    fprintf fmt "%a%a%a" indent_pp lvl' pp_stmt s (cond_region_pp lvl') s.at

  let pp_func (header : string) (fmt : Fmt.t) ((lvl, f) : int * Func.t) : unit =
    let limit = Truncate.limit_indent lvl - String.length header - 1 in
    let pp_func = Font.pp_err [ Cyan ] (Truncate.pp limit pp_str) in
    fprintf fmt "%a%s %a" indent_pp lvl header pp_func
      (func_signature (CodeFmt.func_str f))
end

module type M = sig
  type t

  val initial_state : unit -> t
  val trace_expr : t -> Expr.t -> heapval -> unit
  val trace_stmt : t -> Stmt.t -> unit
  val trace_call : t -> Func.t -> Stmt.t -> unit
  val trace_return : t -> Func.t -> Stmt.t -> heapval -> unit
  val trace_restore : t -> Func.t -> unit
end

module Disable : M = struct
  type t = unit

  let initial_state () : t = ()
  let trace_expr (_ : t) (_ : Expr.t) (_ : heapval) : unit = ()
  let trace_stmt (_ : t) (_ : Stmt.t) : unit = ()
  let trace_call (_ : t) (_ : Func.t) (_ : Stmt.t) : unit = ()
  let trace_return (_ : t) (_ : Func.t) (_ : Stmt.t) (_ : heapval) : unit = ()
  let trace_restore (_ : t) (_ : Func.t) : unit = ()
end

module Call : M = struct
  type t = { mutable lvl : int }

  open CallFmt

  let initial_state () : t = { lvl = -1 }
  let trace_expr (_ : t) (_ : Expr.t) (_ : heapval) : unit = ()
  let trace_stmt (_ : t) (_ : Stmt.t) : unit = ()

  let trace_call (tr : t) (f : Func.t) (s : Stmt.t) : unit =
    tr.lvl <- tr.lvl + 1;
    let call_f = if tr.lvl == 0 then pp_call "started" else pp_call "called" in
    if log_level tr.lvl then Log.err "%a@." call_f (tr.lvl, f, s)

  let trace_return (tr : t) (f : Func.t) (s : Stmt.t) ((heap, v) : heapval) :
    unit =
    if log_level tr.lvl then Log.err "%a@." (pp_return heap) (tr.lvl, f, s, v);
    tr.lvl <- tr.lvl - 1

  let trace_restore (_ : t) (_ : Func.t) : unit = ()
end

module Step : M = struct
  type t = { mutable lvl : int }

  open DefaultFmt (EslCodeFmt)
  open EslCodeFmt

  let initial_state () : t = { lvl = -1 }
  let trace_expr (_ : t) (_ : Expr.t) (_ : heapval) : unit = ()

  let trace_stmt (tr : t) (s : Stmt.t) : unit =
    if log_level tr.lvl && log_stmt s then Log.err "%a@." pp_stmt (tr.lvl, s)

  let trace_call (tr : t) (f : Func.t) (_ : Stmt.t) : unit =
    tr.lvl <- tr.lvl + 1;
    let pp_main_f = pp_func "starting on function" in
    let pp_call_f = pp_func "entering function" in
    let call_f = if tr.lvl == 0 then pp_main_f else pp_call_f in
    if log_level tr.lvl then Log.err "%a@." call_f (tr.lvl, f)

  let trace_return (tr : t) (f : Func.t) (_ : Stmt.t) (_ : heapval) : unit =
    let pp_return = pp_func "exiting function" in
    if log_level tr.lvl then Log.err "%a@." pp_return (tr.lvl, f);
    tr.lvl <- tr.lvl - 1

  let trace_restore (tr : t) (f : Func.t) : unit =
    let pp_restore = pp_func "returning to function" in
    if log_level tr.lvl then Log.err "%a@." pp_restore (tr.lvl, f)
end

module Full : M = struct
  type t = { mutable lvl : int }

  open DefaultFmt (EslCodeFmt)
  open EslCodeFmt

  let initial_state () : t = { lvl = -1 }

  let trace_expr (tr : t) (e : Expr.t) ((heap, v) : heapval) : unit =
    let pp_expr = pp_expr heap in
    if log_level tr.lvl && log_expr e then Log.err "%a@." pp_expr (tr.lvl, e, v)

  let trace_stmt (tr : t) (s : Stmt.t) : unit =
    if log_level tr.lvl && log_stmt s then Log.err "%a@." pp_stmt (tr.lvl, s)

  let trace_call (tr : t) (f : Func.t) (_ : Stmt.t) : unit =
    tr.lvl <- tr.lvl + 1;
    let pp_main_f = pp_func "starting on function" in
    let pp_call_f = pp_func "entering function" in
    let call_f = if tr.lvl == 0 then pp_main_f else pp_call_f in
    if log_level tr.lvl then Log.err "%a@." call_f (tr.lvl, f)

  let trace_return (tr : t) (f : Func.t) (_ : Stmt.t) (_ : heapval) : unit =
    let pp_return = pp_func "exiting function" in
    if log_level tr.lvl then Log.err "%a@." pp_return (tr.lvl, f);
    tr.lvl <- tr.lvl - 1

  let trace_restore (tr : t) (f : Func.t) : unit =
    let pp_restore = pp_func "returning to function" in
    if log_level tr.lvl then Log.err "%a@." pp_restore (tr.lvl, f)
end

module Core : M = struct
  type t = { mutable lvl : int }

  open DefaultFmt (CeslCodeFmt)
  open CeslCodeFmt

  let initial_state () : t = { lvl = -1 }

  let trace_expr (tr : t) (e : Expr.t) ((heap, v) : heapval) : unit =
    let pp_expr = pp_expr heap in
    if log_level tr.lvl && log_expr e then Log.err "%a@." pp_expr (tr.lvl, e, v)

  let trace_stmt (tr : t) (s : Stmt.t) : unit =
    if log_level tr.lvl && log_stmt s then Log.err "%a@." pp_stmt (tr.lvl, s)

  let trace_call (tr : t) (f : Func.t) (_ : Stmt.t) : unit =
    tr.lvl <- tr.lvl + 1;
    let pp_main_f = pp_func "starting on function" in
    let pp_call_f = pp_func "entering function" in
    let call_f = if tr.lvl == 0 then pp_main_f else pp_call_f in
    if log_level tr.lvl then Log.err "%a@." call_f (tr.lvl, f)

  let trace_return (tr : t) (f : Func.t) (_ : Stmt.t) (_ : heapval) : unit =
    let pp_return = pp_func "exiting function" in
    if log_level tr.lvl then Log.err "%a@." pp_return (tr.lvl, f);
    tr.lvl <- tr.lvl - 1

  let trace_restore (tr : t) (f : Func.t) : unit =
    let pp_restore = pp_func "returning to function" in
    if log_level tr.lvl then Log.err "%a@." pp_restore (tr.lvl, f)
end
