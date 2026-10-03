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

    The strategy is [Bot.my_bot] from student/bot.ml — the same function
    the OCaml engine runs offline, so whatever you beat locally is what the
    arena will run.  *)

open Rtsarena

(* Your entry: the bot from student/bot.ml. *)
let strategy : bot = Bot.my_bot

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
        carrying = Json.int_field "carrying" j }

(* Rebuild a [game] from the wire state so the offline strategies work
   unchanged on live data. *)
let view_of_json j =
  let turn = Json.int_field "turn" j in
  let max_turns = Json.int_field ~default:500 "maxTurns" j in
  let terrain_rows = Json.to_list (Json.member "terrain" j) in
  let amount_rows = Json.to_list (Json.member "resourceAmounts" j) in
  let size = match terrain_rows with [] -> 16 | r :: _ -> List.length (Json.to_list r) in
  let size = if size = 0 then 16 else size in
  let terrain = Array.make_matrix size size Empty in
  let res = ref PosMap.empty in
  List.iteri
    (fun y row ->
       List.iteri
         (fun x cell ->
            if y < size && x < size then
              match Json.to_int cell with
              | 1 -> terrain.(y).(x) <- Resource
              | 2 -> terrain.(y).(x) <- Wall
              | _ -> ())
         (Json.to_list row))
    terrain_rows;
  List.iteri
    (fun y row ->
       List.iteri
         (fun x cell ->
            let n = Json.to_int cell in
            if n > 0 && y < size && x < size then res := PosMap.add (x, y) n !res)
         (Json.to_list row))
    amount_rows;
  let mine = List.filter_map (entity_of_json 0) (Json.to_list (Json.member "myUnits" j)) in
  let theirs =
    List.filter_map (entity_of_json 1) (Json.to_list (Json.member "enemyUnits" j))
  in
  (* force sides, in case the runner omits playerId *)
  let mine = List.map (fun e -> { e with player = 0 }) mine in
  let theirs = List.map (fun e -> { e with player = 1 }) theirs in
  let my_res = Json.int_field "myResources" j in
  let their_res = Json.int_field "enemyResources" j in
  let g =
    { size; max_turns; turn;
      entities = mine @ theirs;
      resources = (my_res, their_res);
      terrain; res = !res;
      next_id = 10_000; over = false; winner = -1; reason = "" }
  in
  { v_turn = turn; v_max_turns = max_turns;
    my_resources = my_res; enemy_resources = their_res;
    my_units = mine; enemy_units = theirs;
    v_size = size; v_game = g }

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
