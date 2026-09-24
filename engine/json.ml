(** A very small JSON reader and writer — no dependencies.

    RTSArena talks to external bots in JSON lines, so a competition bot needs
    to parse JSON. Rather than pull in a library, this is a hand-written
    recursive-descent parser, about a hundred lines. It is the same shape as
    the parser you will write later in the course for Scheme0: a tokenizer
    scanning characters, and one function per grammar production. *)

type t =
  | Null
  | Bool of bool
  | Num of float
  | Str of string
  | List of t list
  | Obj of (string * t) list

exception Parse_error of string

(* ------------------------------------------------------------------ *)
(* Reading                                                            *)
(* ------------------------------------------------------------------ *)

type cursor = { src : string; mutable pos : int }

let peek c = if c.pos < String.length c.src then Some c.src.[c.pos] else None
let advance c = c.pos <- c.pos + 1

let fail c msg =
  raise (Parse_error (Printf.sprintf "%s at offset %d" msg c.pos))

let rec skip_ws c =
  match peek c with
  | Some (' ' | '\t' | '\n' | '\r') -> advance c; skip_ws c
  | _ -> ()

let expect c ch =
  skip_ws c;
  match peek c with
  | Some x when x = ch -> advance c
  | _ -> fail c (Printf.sprintf "expected %C" ch)

let parse_literal c word value =
  let n = String.length word in
  if c.pos + n <= String.length c.src && String.sub c.src c.pos n = word then begin
    c.pos <- c.pos + n; value
  end else fail c (Printf.sprintf "expected %s" word)

let parse_string c =
  expect c '"';
  let buf = Buffer.create 16 in
  let rec go () =
    match peek c with
    | None -> fail c "unterminated string"
    | Some '"' -> advance c; Buffer.contents buf
    | Some '\\' ->
      advance c;
      (match peek c with
       | None -> fail c "unterminated escape"
       | Some e ->
         advance c;
         (match e with
          | 'n' -> Buffer.add_char buf '\n'
          | 't' -> Buffer.add_char buf '\t'
          | 'r' -> Buffer.add_char buf '\r'
          | 'b' -> Buffer.add_char buf '\b'
          | 'f' -> Buffer.add_char buf '\012'
          | 'u' ->
            (* keep it simple: accept the escape, emit '?' for non-ASCII *)
            let hex = String.sub c.src c.pos 4 in
            c.pos <- c.pos + 4;
            let code = int_of_string ("0x" ^ hex) in
            if code < 128 then Buffer.add_char buf (Char.chr code)
            else Buffer.add_char buf '?'
          | ch -> Buffer.add_char buf ch);
         go ())
    | Some ch -> advance c; Buffer.add_char buf ch; go ()
  in
  go ()

let parse_number c =
  let start = c.pos in
  let is_num_char = function
    | '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' -> true
    | _ -> false
  in
  let rec go () = match peek c with
    | Some ch when is_num_char ch -> advance c; go ()
    | _ -> ()
  in
  go ();
  if c.pos = start then fail c "expected a number";
  let text = String.sub c.src start (c.pos - start) in
  match float_of_string_opt text with
  | Some f -> f
  | None -> fail c (Printf.sprintf "bad number %S" text)

let rec parse_value c =
  skip_ws c;
  match peek c with
  | None -> fail c "unexpected end of input"
  | Some '{' -> parse_object c
  | Some '[' -> parse_array c
  | Some '"' -> Str (parse_string c)
  | Some 't' -> parse_literal c "true" (Bool true)
  | Some 'f' -> parse_literal c "false" (Bool false)
  | Some 'n' -> parse_literal c "null" Null
  | Some _ -> Num (parse_number c)

and parse_object c =
  expect c '{';
  skip_ws c;
  if peek c = Some '}' then (advance c; Obj [])
  else
    let rec members acc =
      skip_ws c;
      let k = parse_string c in
      expect c ':';
      let v = parse_value c in
      let acc = (k, v) :: acc in
      skip_ws c;
      match peek c with
      | Some ',' -> advance c; members acc
      | Some '}' -> advance c; Obj (List.rev acc)
      | _ -> fail c "expected ',' or '}'"
    in
    members []

and parse_array c =
  expect c '[';
  skip_ws c;
  if peek c = Some ']' then (advance c; List [])
  else
    let rec elements acc =
      let v = parse_value c in
      let acc = v :: acc in
      skip_ws c;
      match peek c with
      | Some ',' -> advance c; elements acc
      | Some ']' -> advance c; List (List.rev acc)
      | _ -> fail c "expected ',' or ']'"
    in
    elements []

let parse s =
  let c = { src = s; pos = 0 } in
  let v = parse_value c in
  skip_ws c;
  v

(* ------------------------------------------------------------------ *)
(* Writing                                                            *)
(* ------------------------------------------------------------------ *)

let escape s =
  let buf = Buffer.create (String.length s + 2) in
  String.iter
    (fun ch ->
       match ch with
       | '"' -> Buffer.add_string buf "\\\""
       | '\\' -> Buffer.add_string buf "\\\\"
       | '\n' -> Buffer.add_string buf "\\n"
       | '\t' -> Buffer.add_string buf "\\t"
       | '\r' -> Buffer.add_string buf "\\r"
       | c when Char.code c < 32 ->
         Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
       | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let rec to_string = function
  | Null -> "null"
  | Bool b -> if b then "true" else "false"
  | Num f ->
    if Float.is_integer f && Float.abs f < 1e15
    then string_of_int (int_of_float f)
    else Printf.sprintf "%g" f
  | Str s -> "\"" ^ escape s ^ "\""
  | List l -> "[" ^ String.concat "," (List.map to_string l) ^ "]"
  | Obj kvs ->
    "{"
    ^ String.concat ","
        (List.map (fun (k, v) -> "\"" ^ escape k ^ "\":" ^ to_string v) kvs)
    ^ "}"

(* ------------------------------------------------------------------ *)
(* Lookups — total functions, so a malformed field cannot crash a bot  *)
(* ------------------------------------------------------------------ *)

let member key = function
  | Obj kvs -> (match List.assoc_opt key kvs with Some v -> v | None -> Null)
  | _ -> Null

let to_int_opt = function
  | Num f -> Some (int_of_float f)
  | Str s -> int_of_string_opt s
  | _ -> None

let to_int ?(default = 0) j = match to_int_opt j with Some i -> i | None -> default
let to_str ?(default = "") j = match j with Str s -> s | _ -> default
let to_bool ?(default = false) j = match j with Bool b -> b | _ -> default
let to_list = function List l -> l | _ -> []
let int_field ?(default = 0) key j = to_int ~default (member key j)
let str_field ?(default = "") key j = to_str ~default (member key j)
