type 'a t = (Field.t, 'a) Hashtbl.t

val create : unit -> 'a t
val get : 'a t -> Field.t -> 'a option
val set : 'a t -> Field.t -> 'a -> unit
val delete : 'a t -> Field.t -> unit
val to_list : 'a t -> (Field.t * 'a) list
val get_fields : 'a t -> Field.t list
