open Smtml
open EslBase
open EslSyntax
module ErrSrc = Error_source

type msg =
  | Default
  | Custom of string
  | UnknownDependency of Id.t
  | CyclicDependency of Id.t
  | DuplicatedField of Id.t
  | DuplicatedParam of Id.t
  | DuplicatedTDef of Id.t
  | DuplicatedFunc of Id.t
  | DuplicatedMacro of Id.t
  | UnknownMacro of Id.t
  | BadNArgs of int * int
  | DuplicatedSwitchCase of Value.t
  | DuplicatedTField of Id.t
  | DuplicatedSigmaDiscriminant of EType.t
  | MissingSigmaDiscriminant of Id.t
  | UnexpectedSigmaDiscriminant
  | UnexpectedSigmaCase

module CompileErr : Error_type.ERROR_TYPE with type t = msg = struct
  type t = msg

  let header : string = "CompileError"
  let font : Font.t = [ Red ]

  let equal (msg1 : t) (msg2 : t) : bool =
    match (msg1, msg2) with
    | (Default, Default) -> true
    | (Custom msg1', Custom msg2') -> String.equal msg1' msg2'
    | (UnknownDependency file1, UnknownDependency file2) -> Id.equal file1 file2
    | (CyclicDependency file1, CyclicDependency file2) -> Id.equal file1 file2
    | (DuplicatedField fn1, DuplicatedField fn2) -> Id.equal fn1 fn2
    | (DuplicatedParam px1, DuplicatedParam px2) -> Id.equal px1 px2
    | (DuplicatedTDef tn1, DuplicatedTDef tn2) -> Id.equal tn1 tn2
    | (DuplicatedFunc fn1, DuplicatedFunc fn2) -> Id.equal fn1 fn2
    | (DuplicatedMacro mn1, DuplicatedMacro mn2) -> Id.equal mn1 mn2
    | (UnknownMacro mn1, UnknownMacro mn2) -> Id.equal mn1 mn2
    | (BadNArgs (npxs1, nargs1), BadNArgs (npxs2, nargs2)) ->
      Int.equal npxs1 npxs2 && Int.equal nargs1 nargs2
    | (DuplicatedSwitchCase v1, DuplicatedSwitchCase v2) -> Value.equal v1 v2
    | (DuplicatedTField fn1, DuplicatedTField fn2) -> Id.equal fn1 fn2
    | (DuplicatedSigmaDiscriminant lt1, DuplicatedSigmaDiscriminant lt2) ->
      EType.equal lt1 lt2
    | (MissingSigmaDiscriminant dsc1, MissingSigmaDiscriminant dsc2) ->
      Id.equal dsc1 dsc2
    | (UnexpectedSigmaDiscriminant, UnexpectedSigmaDiscriminant) -> true
    | (UnexpectedSigmaCase, UnexpectedSigmaCase) -> true
    | _ -> false

  let pp (ppf : Fmt.t) (msg : t) : unit =
    let open Fmt in
    match msg with
    | Default -> format ppf "Generic compilation error."
    | Custom msg' -> format ppf "%s" msg'
    | UnknownDependency file ->
      format ppf "Cannot find dependency '%a'." Id.pp file
    | CyclicDependency file ->
      format ppf "Cyclic dependency of file '%a'." Id.pp file
    | DuplicatedField fn ->
      format ppf "Duplicated field name '%a' for object literal." Id.pp fn
    | DuplicatedParam px ->
      format ppf "Duplicated parameter '%a' for function definition." Id.pp px
    | DuplicatedTDef tn ->
      format ppf "Duplicated definition for typedef '%a'." Id.pp tn
    | DuplicatedFunc fn ->
      format ppf "Duplicated definition for function '%a'." Id.pp fn
    | DuplicatedMacro mn ->
      format ppf "Duplicated definition for macro '%a'." Id.pp mn
    | UnknownMacro mn -> format ppf "Cannot find macro '%a'." Id.pp mn
    | BadNArgs (npxs, nargs) ->
      format ppf "Expected %d arguments, but got %d." npxs nargs
    | DuplicatedSwitchCase v ->
      format ppf "Duplicated case value '%a' for switch statement." EExpr.pp_val v
    | DuplicatedTField fn ->
      format ppf "Duplicated field name '%a' for object type." Id.pp fn
    | DuplicatedSigmaDiscriminant lt ->
      format ppf "Duplicated discriminant '%a' for multiple sigma cases."
        EType.pp lt
    | MissingSigmaDiscriminant dsc ->
      format ppf "Missing discriminant '%a' from sigma case." Id.pp dsc
    | UnexpectedSigmaDiscriminant ->
      format ppf "Expecting literal type for sigma case discriminant."
    | UnexpectedSigmaCase ->
      format ppf "Expecting union of object types for sigma type."

  let str (msg : t) : string = Fmt.str "%a" pp msg
end

type t =
  { msgs : msg list
  ; src : ErrSrc.t
  }

exception Error of t

let raise (err : t) : 'a = Stdlib.raise_notrace (Error err)

let create ?(src : ErrSrc.t = ErrSrc.none ()) (msgs : msg list) : t =
  { msgs; src }

let throw ?(src : ErrSrc.t = ErrSrc.none ()) (msg : msg) : 'a =
  raise @@ create ~src [ msg ]

let push (msg : msg) (err : t) : t = { err with msgs = msg :: err.msgs }
let src (err : t) : ErrSrc.t = err.src
let set_src (src : ErrSrc.t) (err : t) : t = { err with src }

let pp (ppf : Fmt.t) (err : t) : unit =
  let module MsgFmt = Error_type.ErrorTypeFmt (CompileErr) in
  let module ErrSrcFmt = ErrSrc.ErrSrcFmt (CompileErr) in
  Fmt.format ppf "%a%a" MsgFmt.pp err.msgs ErrSrcFmt.pp err.src

let str (err : t) = Fmt.str "%a" pp err
