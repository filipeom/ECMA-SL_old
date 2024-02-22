module Internal = struct
  type t =
    | Default
    | Custom of string
    | Expecting of string
    | UnexpectedEval of string option
    | NotImplemented of string option
end

module Compile = struct
  type t =
    | Default
    | Custom of string
    | UnknownDependency of string
    | CyclicDependency of string
    | DuplicatedTdef of string
    | DuplicatedFunc of string
    | DuplicatedMacro of string
    | DuplicatedField of string
    | DuplicatedSwitchCase of Val.t
    | UnknownMacro of string
    | BadNArgs of int * int
end

module Runtime = struct
  type t =
    | Default
    | Custom of string
    | Unexpected of string
    | UnexpectedExitVal of Val.t
    | Failure of string
    | UncaughtExn of string
    | OpEvalErr of string
    | UnknownVar of string
    | UnknownFunc of string
    | BadNArgs of int * int
    | BadVal of string * Val.t
    | BadExpr of string * Val.t
    | BadFuncId of Val.t
    | BadOpArgs of string * Val.t list
    | MissingReturn of string
end

module ErrFmt = Eslerr_fmt

module InternalFmt : ErrFmt.ERR_TYPE_FMT with type msg = Internal.t = struct
  type msg = Internal.t

  let font () : Font.t = Font.Red
  let header () : string = "InternalError"

  let pp (fmt : Fmt.t) (msg : msg) : unit =
    let open Fmt in
    match msg with
    | Default -> fprintf fmt "generic internal error"
    | Custom msg' -> fprintf fmt "%s" msg'
    | Expecting msg' -> fprintf fmt "expecting %s" msg'
    | UnexpectedEval msg' -> (
      match msg' with
      | None -> fprintf fmt "unexpected evaluation"
      | Some msg'' -> fprintf fmt "unexpected evaluation of '%s'" msg'' )
    | NotImplemented msg' -> (
      match msg' with
      | None -> fprintf fmt "not implemented"
      | Some msg'' -> fprintf fmt "'%s' not implemented" msg'' )

  let str (msg : msg) : string = Fmt.asprintf "%a" pp msg
end

module CompileFmt : ErrFmt.ERR_TYPE_FMT with type msg = Compile.t = struct
  type msg = Compile.t

  let font () : Font.t = Font.Red
  let header () : string = "CompileError"

  let pp (fmt : Fmt.t) (msg : msg) : unit =
    let open Fmt in
    match msg with
    | Default -> fprintf fmt "Generic compilation error."
    | Custom msg' -> fprintf fmt "%s" msg'
    | UnknownDependency file -> fprintf fmt "Cannot find dependency '%s'." file
    | CyclicDependency file ->
      fprintf fmt "Cyclic dependency of file '%s'." file
    | DuplicatedTdef tn ->
      fprintf fmt "Duplicated definition for typedef '%s'." tn
    | DuplicatedFunc fn ->
      fprintf fmt "Duplicated definition for function '%s'." fn
    | DuplicatedMacro mn ->
      fprintf fmt "Duplicated definition for macro '%s'." mn
    | DuplicatedField fn ->
      fprintf fmt
        "Object literals cannot have two fields with the same name '%s'." fn
    | DuplicatedSwitchCase v ->
      fprintf fmt
        "Switch statements cannot have two cases with the same value '%a'."
        Val.pp v
    | UnknownMacro mn -> fprintf fmt "Cannot find macro '%s'." mn
    | BadNArgs (nparams, nargs) ->
      fprintf fmt "Expected %d arguments, but got %d." nparams nargs

  let str (msg : msg) : string = Fmt.asprintf "%a" pp msg
end

module RuntimeFmt : ErrFmt.ERR_TYPE_FMT with type msg = Runtime.t = struct
  type msg = Runtime.t

  let font () : Font.t = Font.Red
  let header () : string = "RuntimeError"

  let pp (fmt : Fmt.t) (msg : Runtime.t) : unit =
    let open Fmt in
    match msg with
    | Default -> fprintf fmt "Generic runtime error."
    | Custom msg' -> fprintf fmt "%s" msg'
    | Unexpected msg -> fprintf fmt "Unexpected %s." msg
    | UnexpectedExitVal v -> fprintf fmt "Unexpected exit value '%a'." Val.pp v
    | Failure msg -> fprintf fmt "Failure %s." msg
    | UncaughtExn msg -> fprintf fmt "Uncaught exception %s." msg
    | OpEvalErr op_lbl -> fprintf fmt "Exception in Operator.%s." op_lbl
    | UnknownVar x -> fprintf fmt "Cannot find variable '%s'." x
    | UnknownFunc fn -> fprintf fmt "Cannot find function '%s'." fn
    | BadNArgs (nparams, nargs) ->
      fprintf fmt "Expected %d arguments, but got %d." nparams nargs
    | BadVal (texp, v) ->
      fprintf fmt "Expecting %s value, but got '%a'." texp Val.pp v
    | BadExpr (texp, v) ->
      fprintf fmt "Expecting %s expression, but got '%a'." texp Val.pp v
    | BadFuncId v ->
      fprintf fmt "Expecting a function identifier, but got '%a'." Val.pp v
    | BadOpArgs (texp, vals) when List.length vals = 1 ->
      fprintf fmt "Expecting argument of type '%s', but got '%a'." texp
        (pp_lst ", " Val.pp) vals
    | BadOpArgs (texp, vals) ->
      fprintf fmt "Expecting arguments of types '%s', but got '(%a)'." texp
        (pp_lst ", " Val.pp) vals
    | MissingReturn fn -> fprintf fmt "Missing return in function '%s'." fn

  let str (msg : msg) : string = Fmt.asprintf "%a" pp msg
end
