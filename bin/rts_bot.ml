(** A competition-ready RTSArena bot.

    Speaks the RTSArena subprocess protocol: one JSON game state per line on
    stdin, one JSON array of commands per line on stdout, until the runner
    sends [{"gameOver":true}].

    Run it against the JavaScript arena:
    {v
      ocamlfind ocamlopt ... -o rts_bot        (or: dune build)
      node play_offline.js --player-type subprocess \
        --bot-cmd "./rts_bot" --opponent lightRush
    v}

    The strategy is [Search.Search_bot.bot] from search/search_bot.ml — the same function
    the OCaml engine runs offline, so whatever you beat locally is what the
    arena will run.  *)

open Rtsarena

(* Your entry: the search bot from search/search_bot.ml. *)
let strategy : bot = Search.Search_bot.bot

(* ------------------------------------------------------------------ *)
(* Protocol plumbing                                                  *)
(* ------------------------------------------------------------------ *)

let kind_of_string s is_bldg =
  if is_bldg then
    match s with
    | "barracks" -> Some (B Barracks)
    | "base" -> Some (B Base)
    | _ -> None
  else Option.map (fun u -> U u) (unit_type_of_string s)

(* The course tournament also sends what each unit is doing and what each
   building is making; the JavaScript arena does not, and then both are
   None, as before. *)
let action_of_json j =
  let int k = Json.int_field k j in
  match Json.str_field "kind" j with
  | "harvest" ->
    Some (Harvest (if Json.member "x" j = Json.Null then None else Some (int "x", int "y")))
  | "attack" -> Some (Attack_at (int "x", int "y"))
  | "move" -> Some (Move_to (int "x", int "y"))
  | "build" ->
    let btype = if Json.str_field "buildingType" j = "base" then Base else Barracks in
    Some (Building_it { btype; bx = int "x"; by = int "y"; progress = int "progress" })
  | _ -> None

let producing_of_json j =
  Option.map (fun u -> (u, Json.int_field "ticks" j))
    (unit_type_of_string (Json.str_field "unitType" j))

let entity_of_json me j =
  let t = Json.str_field "type" j in
  let is_bldg =
    Json.to_bool (Json.member "isBuilding" j) || t = "base" || t = "barracks"
  in
  match kind_of_string t is_bldg with
  | None -> None
  | Some kind ->
    let id = Json.int_field "id" j in
    let x = Json.int_field "x" j and y = Json.int_field "y" j in
    (* the protocol reports playerId 0 for us, 1 for them *)
    let player = Json.int_field ~default:me "playerId" j in
    let e = make_entity id kind player x y in
    Some
      { e with
        hp = Json.int_field ~default:e.hp "hp" j;
        max_hp = Json.int_field ~default:e.max_hp "maxHp" j;
        carrying = Json.int_field "carrying" j;
        action = action_of_json (Json.member "action" j);
        producing = producing_of_json (Json.member "producing" j) }

(* Rebuild a [game] from the wire state so the offline strategies work
   unchanged on live data. *)
let view_of_json j =
  let turn = Json.int_field "turn" j in
  let max_turns = Json.int_field ~default:500 "maxTurns" j in
  let rows k = List.map (fun r -> Array.of_list (List.map Json.to_int (Json.to_list r)))
                 (Json.to_list (Json.member k j)) |> Array.of_list in
  let terrain_codes = rows "terrain" and amounts = rows "resourceAmounts" in
  let size = if Array.length terrain_codes = 0 then 16 else Array.length terrain_codes.(0) in
  let size = if size = 0 then 16 else size in
  let terrain =
    Array.map (Array.map (function 1 -> Resource | 2 -> Wall | _ -> Empty)) terrain_codes in
  let mine = List.filter_map (entity_of_json 0) (Json.to_list (Json.member "myUnits" j)) in
  let theirs =
    List.filter_map (entity_of_json 1) (Json.to_list (Json.member "enemyUnits" j))
  in
  (* force sides, in case the runner omits playerId *)
  let mine = List.map (fun e -> { e with player = 0 }) mine in
  let theirs = List.map (fun e -> { e with player = 1 }) theirs in
  let resources = (Json.int_field "myResources" j, Json.int_field "enemyResources" j) in
  (* The course tournament says what order the engine keeps entities in,
     and what id the next unit gets; both change what happens next, so a
     rebuilt game needs them to predict the real one. The JavaScript arena
     sends neither. *)
  let seq_of = Hashtbl.create 64 in
  List.iter
    (fun j -> match Json.member "seq" j with
       | Json.Null -> ()
       | s -> Hashtbl.replace seq_of (Json.int_field "id" j) (Json.to_int s))
    (Json.to_list (Json.member "myUnits" j) @ Json.to_list (Json.member "enemyUnits" j));
  let ents = mine @ theirs in
  let ents =
    if Hashtbl.length seq_of = 0 then ents
    else
      List.stable_sort
        (fun a b ->
           compare (Hashtbl.find_opt seq_of a.id |> Option.value ~default:max_int)
             (Hashtbl.find_opt seq_of b.id |> Option.value ~default:max_int))
        ents
  in
  let next_id = match Json.member "nextId" j with Json.Null -> None | n -> Some (Json.to_int n) in
  let g = of_snapshot ?next_id ~size ~max_turns ~turn ~terrain ~amounts ~resources ents in
  view g 0

let json_of_order = function
  | Harvest_with n ->
    Json.Obj [ ("type", Json.Str "harvest"); ("count", Json.Num (float_of_int n)) ]
  | Build_barracks ->
    Json.Obj [ ("type", Json.Str "build"); ("buildingType", Json.Str "barracks") ]
  | Train (u, n) ->
    Json.Obj
      [ ("type", Json.Str "train");
        ("unitType", Json.Str (string_of_unit_type u));
        ("count", Json.Num (float_of_int n)) ]
  | Attack (x, y) ->
    Json.Obj
      [ ("type", Json.Str "attack");
        ("x", Json.Num (float_of_int x)); ("y", Json.Num (float_of_int y)) ]
  | Defend -> Json.Obj [ ("type", Json.Str "defend") ]
  | Retreat -> Json.Obj [ ("type", Json.Str "retreat") ]

let json_of_orders orders = Json.List (List.map json_of_order orders)

(* ------------------------------------------------------------------ *)

let () =
  let rec loop () =
    match input_line stdin with
    | exception End_of_file -> ()
    | line ->
      let line = String.trim line in
      if line = "" then loop ()
      else begin
        (match Json.parse line with
         | exception Json.Parse_error msg ->
           (* never die on bad input: keep the previous orders by saying nothing
              useful, and complain on stderr where the runner logs it *)
           Printf.eprintf "rts_bot: %s\n%!" msg;
           print_string "[]\n";
           flush stdout
         | j ->
           if Json.to_bool (Json.member "gameOver" j) then exit 0
           else begin
             let orders =
               try strategy (view_of_json j)
               with e ->
                 Printf.eprintf "rts_bot: strategy raised %s\n%!" (Printexc.to_string e);
                 [ Harvest_with 2; Defend ]
             in
             print_string (Json.to_string (json_of_orders orders));
             print_newline ();
             (* the single most common bug in a subprocess bot *)
             flush stdout
           end);
        loop ()
      end
  in
  loop ()
