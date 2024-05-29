let default_hashtbl_sz = ref 16

type counter = (unit -> int) * (unit -> unit)

let make_counter (init : int) (step : int) : counter =
  let counter = ref init in
  let next () =
    let n = !counter in
    counter := n + step;
    n
  and reset () = counter := init in
  (next, reset)

let make_name_generator (base : string) : unit -> string =
  let (next, _) = make_counter 0 1 in
  fun () -> base ^ string_of_int (next ())

type formated_time = int * int * int * int

let time () : float = Unix.gettimeofday ()

let format_time (time : float) : formated_time =
  let total_secs = int_of_float (floor time) in
  let hours = total_secs / 3600 in
  let minutes = (total_secs - (hours * 3600)) / 60 in
  let seconds = total_secs - ((hours * 3600) + (minutes * 60)) in
  let millis = int_of_float (Float.round ((time -. floor time) *. 1000.0)) in
  (hours, minutes, seconds, millis)

type formated_bytes = float * string

let format_bytes (bytes : int) : formated_bytes =
  let units = [| "bytes"; "kb"; "mb"; "gb"; "tb" |] in
  let rec expbt sz i = if sz < 1024 then i else expbt (sz / 1024) (i + 1) in
  let i = expbt bytes 0 in
  (float_of_int bytes /. (1024.0 ** float_of_int i), units.(i))
