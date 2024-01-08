let log_stmt (s : Stmt.t) : bool =
  match s.it with Skip | Merge | Debug | Block _ -> false | _ -> true

module type M = sig
  val eval_expr_val : Expr.t -> Val.t -> unit
  val eval_small_step : Func.t -> Stmt.t -> unit
end

module Disable : M = struct
  let eval_expr_val (_ : Expr.t) (_ : Val.t) : unit = ()
  let eval_small_step (_ : Func.t) (_ : Stmt.t) : unit = ()
end

module Default : M = struct
  let eval_expr_val (e : Expr.t) (v : Val.t) : unit =
    Format.eprintf "» | %a | --> %a@." Expr.pp e Val.pp v

  let eval_small_step (f : Func.t) (s : Stmt.t) : unit =
    if log_stmt s then
      let divider_str = "----------------------------------------" in
      Format.eprintf "%s\nEvaluating >>>> %s() [line=%d]: %a@." divider_str
        (Func.name f) s.at.left.line Stmt.pp_simple s
end
