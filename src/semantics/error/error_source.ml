open EslBase
open EslSyntax

type t = Source.at

module ErrSrcFmt (ErrorType : Error_type.ERROR_TYPE) = struct
  type location =
    { file : string
    ; line : int
    ; lpos : int
    ; rpos : int
    }

  let location (at : Source.at) : location =
    let (file, line, lpos) = (at.file, at.lpos.line, at.lpos.col) in
    let rpos = if at.lpos.line == at.rpos.line then at.rpos.col else -1 in
    { file; line; lpos; rpos }

  let format_code (line : string) : int * string =
    let start = Str.search_forward (Str.regexp "[^ \t\r\n]") line 0 in
    let line = String.sub line start (String.length line - start) in
    (start, line)

  let pp_loc : location Fmt.t =
    Font.pp_err [ Font.Italic; Font.Faint ] @@ fun ppf loc ->
    Fmt.pf ppf "File %S, line %d, characters %d-%d" loc.file loc.line loc.lpos
      loc.rpos

  let pp_indent (ppf : Format.formatter) (lineno : int) : unit =
    let lineno_sz = String.length (string_of_int lineno) in
    Fmt.string ppf (String.make (lineno_sz + 5) ' ')

  let pp_hglt (ppf : Format.formatter) ((code, lpos, rpos) : string * int * int)
    : unit =
    let pp_font = Font.pp_text_err ErrorType.font in
    let code' = Str.global_replace (Str.regexp "[^ \t\r\n]") " " code in
    Fmt.pf ppf "%s%a" (String.sub code' 0 lpos) pp_font
      (String.make (rpos - lpos) '^')

  let pp (ppf : Format.formatter) (at : t) : unit =
    if not (Source.is_none at) then
      let loc = location at in
      let (_, line) = Code_utils.(line (file loc.file) loc.line) in
      let rpos' = if loc.rpos != -1 then loc.rpos else String.length line in
      let (start, code) = format_code line in
      let (lpos, rpos) = (loc.lpos - start, rpos' - start) in
      Fmt.pf ppf "@\n%a@\n%d |   %s@\n%a%a" pp_loc loc loc.line code pp_indent
        loc.line pp_hglt (code, lpos, rpos)

  let str (src : t) : string = Fmt.str "%a" pp src [@@inline]
end
