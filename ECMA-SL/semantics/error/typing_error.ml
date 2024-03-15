open EslBase
open EslSyntax
module ErrSrc = Error_source

type msg =
  | Default
  | Custom of string
  | BadCongruency of EType.t * EType.t
  | BadSubtyping of EType.t * EType.t
  | MissingField of Id.t
  | ExtraField of Id.t
  | IncompatibleField of Id.t
  | IncompatibleOptionalField of Id.t
  | IncompatibleSummaryField of Id.t
  | MissingSummaryField of EType.t
  | ExtraSummaryField
  | NExpectedElements of int * int
  | IncompatibleElement of int
  | IncompatibleSigmaDiscriminant
  | MissingSigmaCase of EType.t
  | ExtraSigmaCase of EType.t
  | IncompatibleSigmaCase of EType.t
  | MissingSigmaCaseDiscriminant of Id.t
  | UnknownSigmaCaseDiscriminant of EType.t

module TypingErr : Error_type.ERROR_TYPE with type t = msg = struct
  type t = msg

  let header : string = "TypeError"
  let font : Font.t = [ Red ]

  let equal (msg1 : t) (msg2 : t) : bool =
    match (msg1, msg2) with
    | (Default, Default) -> true
    | (Custom msg1', Custom msg2') -> String.equal msg1' msg2'
    | (BadCongruency (tref1, tsrc1), BadCongruency (tref2, tsrc2)) ->
      EType.equal tref1 tref2 && EType.equal tsrc1 tsrc2
    | (BadSubtyping (tref1, tsrc1), BadSubtyping (tref2, tsrc2)) ->
      EType.equal tref1 tref2 && EType.equal tsrc1 tsrc2
    | (MissingField fn1, MissingField fn2) -> Id.equal fn1 fn2
    | (ExtraField fn1, ExtraField fn2) -> Id.equal fn1 fn2
    | (IncompatibleField fn1, IncompatibleField fn2) -> Id.equal fn1 fn2
    | (IncompatibleOptionalField fn1, IncompatibleOptionalField fn2) ->
      Id.equal fn1 fn2
    | (IncompatibleSummaryField fn1, IncompatibleSummaryField fn2) ->
      Id.equal fn1 fn2
    | (MissingSummaryField ft1, MissingSummaryField ft2) -> EType.equal ft1 ft2
    | (ExtraSummaryField, ExtraSummaryField) -> true
    | (NExpectedElements (nref1, nsrc1), NExpectedElements (nref2, nsrc2)) ->
      Int.equal nref1 nref2 && Int.equal nsrc1 nsrc2
    | (IncompatibleElement i1, IncompatibleElement i2) -> Int.equal i1 i2
    | (IncompatibleSigmaDiscriminant, IncompatibleSigmaDiscriminant) -> true
    | (MissingSigmaCase tdsc1, MissingSigmaCase tdsc2) ->
      EType.equal tdsc1 tdsc2
    | (ExtraSigmaCase tdsc1, ExtraSigmaCase tdsc2) -> EType.equal tdsc1 tdsc2
    | (IncompatibleSigmaCase tdsc1, IncompatibleSigmaCase tdsc2) ->
      EType.equal tdsc1 tdsc2
    | (MissingSigmaCaseDiscriminant dsc1, MissingSigmaCaseDiscriminant dsc2) ->
      Id.equal dsc1 dsc2
    | (UnknownSigmaCaseDiscriminant t1, UnknownSigmaCaseDiscriminant t2) ->
      EType.equal t1 t2
    | _ -> false

  let pp (fmt : Fmt.t) (msg : t) : unit =
    let open Fmt in
    match msg with
    | Default -> fprintf fmt "Generic type error."
    | Custom msg' -> fprintf fmt "%s" msg'
    | BadCongruency (tref, tsrc) ->
      fprintf fmt "Value of type '%a' is not congruent with type '%a'." EType.pp
        tsrc EType.pp tref
    | BadSubtyping (tref, tsrc) ->
      fprintf fmt "Value of type '%a' is not assignable to type '%a'." EType.pp
        tsrc EType.pp tref
    | MissingField fn ->
      fprintf fmt "Field '%a' is missing from the object's type." Id.pp fn
    | ExtraField fn ->
      fprintf fmt "Field '%a' is not defined in the object's type." Id.pp fn
    | IncompatibleField fn ->
      fprintf fmt "Types of field '%a' are incompatible." Id.pp fn
    | IncompatibleOptionalField fn ->
      fprintf fmt "Types of optional field '%a' are incompatible." Id.pp fn
    | IncompatibleSummaryField fn ->
      fprintf fmt "Type of field '%a' is incompatible with the summary type."
        Id.pp fn
    | MissingSummaryField ft ->
      fprintf fmt "Summary field '%a' is missing from the object's type."
        EType.pp ft
    | ExtraSummaryField ->
      fprintf fmt "Summary field is not defined in the object's type."
    | NExpectedElements (ntsref, ntssrc) ->
      fprintf fmt "Expecting %d elements, but %d were provided." ntsref ntssrc
    | IncompatibleElement i ->
      fprintf fmt "Types of the %s element are incompatible."
        (String.ordinal_suffix i)
    | IncompatibleSigmaDiscriminant ->
      fprintf fmt "Discriminant fields are incompatible."
    | MissingSigmaCase tdsc ->
      fprintf fmt
        "Sigma case of discriminant '%a' is missing from the sigma type."
        EType.pp tdsc
    | ExtraSigmaCase tdsc ->
      fprintf fmt
        "Sigma case of discriminant '%a' is not defined in the sigma type."
        EType.pp tdsc
    | IncompatibleSigmaCase tdsc ->
      fprintf fmt "Sigma cases of discriminants '%a' are incompatible." EType.pp
        tdsc
    | MissingSigmaCaseDiscriminant dsc ->
      fprintf fmt "Missing discriminant '%a' from the sigma type case." Id.pp
        dsc
    | UnknownSigmaCaseDiscriminant tdsc ->
      fprintf fmt "Cannot find discriminant '%a' in the sigma type." EType.pp
        tdsc

  let str (msg : t) : string = Fmt.asprintf "%a" pp msg
end

type t =
  { msgs : msg list
  ; src : ErrSrc.t
  }

exception Error of t

let create ?(src : ErrSrc.t = ErrSrc.none ()) (msgs : msg list) : exn =
  Error { msgs; src }

let throw ?(src : ErrSrc.t = ErrSrc.none ()) (msg : msg) : 'a =
  raise @@ create ~src [ msg ]

let pp (fmt : Fmt.t) (err : t) : unit =
  let module MsgFmt = Error_type.ErrorTypeFmt (TypingErr) in
  let module ErrSrcFmt = ErrSrc.ErrSrcFmt (TypingErr) in
  Fmt.fprintf fmt "%a%a" MsgFmt.pp err.msgs ErrSrcFmt.pp err.src

let str (err : t) = Fmt.asprintf "%a" pp err

let push (msg : msg) (exn : exn) : exn =
  match exn with
  | Error err -> Error { err with msgs = msg :: err.msgs }
  | _ -> Internal_error.(throw __FUNCTION__ (Expecting "typing error"))

let src (exn : exn) : ErrSrc.t =
  match exn with
  | Error err -> err.src
  | _ -> Internal_error.(throw __FUNCTION__ (Expecting "typing error"))

let set_src (src : ErrSrc.t) (exn : exn) : exn =
  match exn with
  | Error err -> Error { err with src }
  | _ -> Internal_error.(throw __FUNCTION__ (Expecting "typing error"))
