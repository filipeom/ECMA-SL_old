include Stdlib.String

let substr ?(left : int option) ?(right : int option) (text : string) : string =
  let left' = Option.value ~default:0 left in
  let right' = Option.value ~default:(length text) right in
  sub text left' (right' - left')

let ordinal_suffix (n : int) : string =
  let suffix =
    if n mod 100 / 10 = 1 then "th"
    else match n mod 10 with 1 -> "st" | 2 -> "nd" | 3 -> "rd" | _ -> "th"
  in
  string_of_int n ^ suffix

let truncate ?(extra : string option) (limit : int) (text : string) : string =
  let extra' = Option.value ~default:"" extra in
  let add_extra (line, trunc) = line ^ if trunc then extra' else "" in
  let truncate_line line trunc =
    try if length line > limit then (sub line 0 limit, true) else (line, trunc)
    with Invalid_argument _ -> ("", true)
  in
  match split_on_char '\n' text with
  | [] -> ""
  | line :: [] -> truncate_line line false |> add_extra
  | line :: _ -> truncate_line line true |> add_extra
