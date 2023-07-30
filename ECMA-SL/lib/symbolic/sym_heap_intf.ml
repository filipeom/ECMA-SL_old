module type S = sig
  type t
  type value
  type object_

  val create : unit -> t
  val clone : t -> t
  val insert : t -> object_ -> value
  val remove : t -> Loc.t -> unit
  val set : t -> Loc.t -> object_ -> unit
  val get : t -> Loc.t -> object_ option
  val has_field : t -> Loc.t -> value -> value
  val set_field : t -> Loc.t -> field:value -> data:value -> unit
  val get_field : t -> Loc.t -> value -> value option
  val delete_field : t -> Loc.t -> value -> unit
  val to_string : t -> string
  val loc : value -> ((value option * string) list, string) Result.t
end
