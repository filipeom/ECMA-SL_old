(*
  The first section is
    an optional chunk of OCaml code that is bounded by a pair of curly braces.
  Define utility functions used by later snippets of OCaml code and
    set up the environment by opening useful modules and define exceptions.
*)
{
  open Lexing
  open E_Parser



  exception Syntax_error of string
}

(*
  The second section is
    a collection of named regular expressions.
*)
let digit   = ['0' - '9']
let letter  = ['a' - 'z' 'A' - 'Z']
let int     = '-'?digit+
let frac    = '.' digit*
let exp     = ['e' 'E'] ['-' '+']? digit+
let float   = digit* frac? exp?
let bool    = "true"|"false"
let var     = (letter | '_'*letter)(letter|digit|'_'|'\'')*
let gvar    = '|'(var)'|'
let symbol  = '\''(var|int)
let white   = (' '|'\t')+
let newline = '\r'|'\n'|"\r\n"
let loc     = "$loc_"(digit|letter|'_')+

(*
  The third section is
    the one with the lexing rules: functions that consume the data,
    producing OCaml expressions that evaluate to tokens.
  The rules are structured very similarly to pattern matches,
    except that the variants are replaced by regular expressions on the left-hand side.
    The righthand-side clause is the parsed OCaml return value of that rule.
    The OCaml code for the rules has a parameter called lexbuf that defines the input,
    including the position in the input file, as well as the text that was matched
    by the regular expression.
  "Lexing.lexeme lexbuf" returns the complete string matched by the regular expression.
*)
rule read =
  parse

  | white          { read lexbuf }
  | newline        { new_line lexbuf; read lexbuf }
  | ":="           { DEFEQ }
  | '@'            { AT_SIGN }
  | '.'            { PERIOD }
  | ';'            { SEMICOLON }
  | ':'            { COLON }
  | ','            { COMMA }
  | '+'            { PLUS }
  | '-'            { MINUS }
  | '*'            { TIMES }
  | '/'            { DIVIDE }
  | '%'            { MODULO }
  | '='            { EQUAL }
  | '>'            { GT }
  | '<'            { LT }
  | ">="           { EGT }
  | "<="           { ELT }
  | "in_obj"       { IN_OBJ }
  | "in_list"      { IN_LIST }
  | '!'            { NOT }
  | '~'            { BITWISE_NOT }
  | '&'            { BITWISE_AND }
  | '|'            { PIPE }
  | '^'            { BITWISE_XOR }
  | "<<"           { SHIFT_LEFT }
  | ">>"           { SHIFT_RIGHT }
  | ">>>"          { SHIFT_RIGHT_LOGICAL }
  | "&&&"          { SCLAND }
  | "|||"          { SCLOR }
  | "&&"           { LAND }
  | "||"           { LOR }
  | "l_len"        { LLEN }
  | "l_nth"        { LNTH }
  | "l_add"        { LADD }
  | "l_prepend"    { LPREPEND }
  | "l_concat"     { LCONCAT }
  | "hd"           { HD }
  | "tl"           { TL }
  | "t_len"        { TLEN }
  | "t_nth"        { TNTH }
  | "fst"          { FST }
  | "snd"          { SND }
  | "s_concat"     { SCONCAT }
  | "s_len"        { SLEN }
  | "s_nth"        { SNTH }
  | "int_to_float"    { INT_TO_FLOAT }
  | "int_to_string"   { INT_TO_STRING }
  | "int_of_string"   { INT_OF_STRING }
  | "int_of_float"    { INT_OF_FLOAT }
  | "float_to_string" { FLOAT_TO_STRING }
  | "float_of_string" { FLOAT_OF_STRING }
  | "obj_to_list"     { OBJ_TO_LIST }
  | "obj_fields"      { OBJ_FIELDS }
  | "to_int"          { TO_INT }
  | "to_int32"        { TO_INT32 }
  | "to_uint32"       { TO_UINT32 }
  | "to_uint16"       { TO_UINT16 }
  | "from_char_code"  { FROM_CHAR_CODE }
  | "to_char_code"    { TO_CHAR_CODE }
  | "to_lower_case"   { TO_LOWER_CASE }
  | "to_upper_case"   { TO_UPPER_CASE }
  | "trim"            { TRIM }
  | "abs"             { ABS }
  | "acos"            { ACOS }
  | "asin"            { ASIN }
  | "atan"            { ATAN }
  | "atan2"           { ATAN_2 }
  | "ceil"            { CEIL }
  | "cos"             { COS }
  | "exp"             { EXP }
  | "floor"           { FLOOR }
  | "log_e"           { LOG_E }
  | "log_10"          { LOG_10 }
  | "max"             { MAX }
  | "min"             { MIN }
  | "**"              { POW }
  | "random"          { RANDOM }
  | "round"           { ROUND }
  | "sin"             { SIN }
  | "sqrt"            { SQRT }
  | "tan"             { TAN }
  | "PI"              { PI }
  | '('               { LPAREN }
  | ')'               { RPAREN }
  | '{'               { LBRACE }
  | '}'               { RBRACE }
  | '['               { LBRACK }
  | ']'               { RBRACK }
  | "typeof"          { TYPEOF }
  | "__$"             { read_type lexbuf }
  | "throw"           { THROW }
  | "import"          { IMPORT }
  | "->"              { RIGHT_ARROW }
  | "None"            { NONE }
  | "default"         { DEFAULT }
  | "if"              { IF }
  | "else"            { ELSE }
  | "while"           { WHILE }
  | "return"          { RETURN }
  | "function"        { FUNCTION }
  | "macro"           { MACRO }
  | "delete"          { DELETE }
  | "null"            { NULL }
  | "\"'null\""       { SYMBOL ("'null") }
  | "undefined"       { SYMBOL ("'undefined") }
  | "repeat"          { REPEAT }
  | "until"           { UNTIL }
  | "match"           { MATCH }
  | "with"            { WITH }
  | "print"           { PRINT }
  | "assert"          { ASSERT }
  | "NaN"             { FLOAT (float_of_string "nan") }
  | "Infinity"        { FLOAT (float_of_string "infinity") }
  | int               { INT (int_of_string (Lexing.lexeme lexbuf)) }
  | float             { FLOAT (float_of_string (Lexing.lexeme lexbuf)) }
  | bool              { BOOLEAN (bool_of_string (Lexing.lexeme lexbuf)) }
  | '"'               { read_string (Buffer.create 16) lexbuf }
  | gvar              { GVAR (String_Utils.trim_ends (Lexing.lexeme lexbuf))}
  | var               { VAR (Lexing.lexeme lexbuf) }
  | symbol            { SYMBOL (Lexing.lexeme lexbuf) }
  | loc               { LOC (Lexing.lexeme lexbuf) }
  | "/*"              { read_comment lexbuf }
  | _                 { raise (Syntax_error ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }
  | eof               { EOF }


(* Read strings *)
and read_string buf =
  parse
  | '"'                  { STRING (Buffer.contents buf) }
  | '\\' '/'             { Buffer.add_char buf '/'; read_string buf lexbuf }
  | '\\' '\\'            { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' 'b'             { Buffer.add_char buf '\b'; read_string buf lexbuf }
  | '\\' 'f'             { Buffer.add_char buf '\012'; read_string buf lexbuf }
  | '\\' 'n'             { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 'r'             { Buffer.add_char buf '\r'; read_string buf lexbuf }
  | '\\' 't'             { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | '\\' '\"'            { Buffer.add_char buf '\"'; read_string buf lexbuf }
  | '\\' '\''            { Buffer.add_char buf '\''; read_string buf lexbuf }
  | [^ '"' '\\']+        {
                           Buffer.add_string buf (Lexing.lexeme lexbuf);
                           read_string buf lexbuf
                         }
  | _                    { raise (Syntax_error ("Illegal string character: " ^ Lexing.lexeme lexbuf)) }
  | eof                  { raise (Syntax_error ("String is not terminated")) }


and read_comment =
(* Read comments *)
  parse
  | "*/"      { read lexbuf }
  | newline   { new_line lexbuf; read_comment lexbuf }
  | _         { read_comment lexbuf }
  | eof       { raise (Syntax_error ("Comment is not terminated."))}

and read_type =
(* Read Language Types *)
  parse
  | "Int"    { INT_TYPE }
  | "Flt"    { FLT_TYPE }
  | "Bool"   { BOOL_TYPE }
  | "Str"    { STR_TYPE }
  | "Obj"    { LOC_TYPE }
  | "List"   { LIST_TYPE }
  | "Tuple"  { TUPLE_TYPE }
  | "Null"   { NULL_TYPE }
  | "Symbol" { SYMBOL_TYPE }
  | _        { raise (Syntax_error ("Unexpected type: " ^ Lexing.lexeme lexbuf)) }
