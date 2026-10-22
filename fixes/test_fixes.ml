(************************************************************************
   RTS-2, Part B — the four fixes, test first (40 pts, 10 each)

   For each flaw below:
     1. write the test here and COMMIT it while it still fails
        (git log is part of the grade — the failing test must come first);
     2. fix the engine;
     3. commit again, with the test passing.

   Each test must fail on the RTS-1 engine for the reason it names, and pass
   on yours. We also run our own hidden tests for each fix.

   Run:  dune test fixes
 ************************************************************************)

open Alcotest
open Rtsarena
[@@@warning "-26-27-32-33"]

let blank = make_game ()
let e id kind player x y = make_entity id kind player x y

let state g =
  (List.sort compare (entities g), resources_of g 0, resources_of g 1, turn g, to_ascii g 0)

(** 1. The seal. A game you were handed cannot be changed: not through a
    fork you simulate, and not through the arrays you built it from. *)
let test_seal () =
  let g = make_game () in (*new game*)
  let before = state g in (* pull state to new game*)
  let forked = fork (view g 0) in (* copy to play with*)
  let _ = rollout forked light_rush heavy_rush ~ticks:100 in (* run through the pretend game*)
  check bool "the original game is unchanged" true 
    (state g = before); (*real game the same*)
  let terrain = Array.make_matrix 4 4 Empty in (* a small board of empty tiles*)
  let amounts = Array.make_matrix 4 4 0 in (* a small board of 0*)
  let snap = of_snapshot ~size: 4 ~max_turns: 10 ~turn: 0 ~terrain ~amounts ~resources: (0,0) [] in (*build game*)
  terrain.(1).(1) <- Wall; (*now scribble a wall on our original board *)
  amounts.(2).(2) <- 5; (*amount for wall*)
  check bool "a wall scribbled on the terrain does not make game" true
    (cell_at snap 1 1 = Empty); (* The game must see empty tile*)
  check int " the amount on terrain does not make game " 0
    (resource_left snap 2 2) (* the game sees 0*)

(** 2. Fairness. Two units that can kill each other in one blow must BOTH
    die in the same tick, whichever of them the engine looks at first. *)
let test_fair () =
  let a = { (e 1 (U Heavy) 0 5 5) with hp = 4; action = Some (Attack_at (6, 5)) } in  (* red heavy, one hit from death *)
  let b = { (e 2 (U Heavy) 1 6 5) with hp = 4; action = Some (Attack_at (5, 5)) } in  (* blue heavy, one hit from death *)
  let after list = fst (step (with_entities blank list)) in  (* play one tick with these units *)
  check int "both die when a is listed first" 0 (List.length (entities (after [ a; b ])));  (* nobody left *)
  check int "both die when b is listed first" 0 (List.length (entities (after [ b; a ])));  (* nobody left *)
  let c = { (e 3 (U Heavy) 0 5 5) with hp = 4; action = Some (Attack_at (6, 5)) } in  (* red heavy, one hit from death *)
  let d = { (e 4 (U Heavy) 1 6 5) with action = Some (Attack_at (5, 5)) } in  (* blue heavy, full health *)
  check bool "the result does not depend on who is listed first" true
    (List.sort compare (entities (after [ c; d ]))
     = List.sort compare (entities (after [ d; c ])))  (* same units, same health *)

(** 3. Honest randomness. One [random_bot] value, played twice, plays the
    same game twice. *)
let test_random () =
  let b = random_bot 42 in (*one random bot*)
  let first = play b turtle in (*play game*)
  let second = play b turtle in (* same bot*)
  check bool "the same bot value plays the same game " true
    (first.turns = second. turns && state first.final = state second.final); (*both games match*)
  let v = view blank 0 in (* one view of board*)
  check bool "the same view always gets the same orders" true (b v = b v)

(** 4. Legal positions. Over real games, no unit ever stands on a wall and
    no two entities ever share a cell. (There is more than one way the old
    engine breaks this. Fixing the kiting is not enough.) *)
let legal g =  (* is every entity on a legal square? *)
  let es = entities g in  (* everything on the board *)
  let on_wall = List.exists (fun (a : entity) -> cell_at g a.x a.y = Wall) es in  (* anyone on a wall? *)
  let shared =  (* any two different entities on the same square? *)
    List.exists
      (fun (a : entity) ->
         List.exists (fun (b : entity) -> a.id <> b.id && a.x = b.x && a.y = b.y) es)
      es in
  (not on_wall) && not shared  (* legal means neither happened *)

let test_legal () =
  let play_checked preset name0 name1 =  (* play one whole game, checking every tick *)
    let _ =
      play ~preset
        ~on_tick:(fun g _ -> check bool "nobody on a wall, nobody sharing a square" true (legal g))
        (Option.get (bot_named name0)) (Option.get (bot_named name1)) in
    () in
  List.iter  (* every map, every pair of built-in bots *)
    (fun preset ->
       List.iter
         (fun name0 -> List.iter (fun name1 -> play_checked preset name0 name1) (bot_names ()))
         (bot_names ()))
    [ "default"; "corridors" ];
  let builder =  (* a worker standing ON the square where it is building a barracks *)
    { (e 50 (U Worker) 0 8 8) with
      action = Some (Building_it { btype = Barracks; bx = 8; by = 8; progress = 4 }) } in
  let start = with_entities blank [ builder; e 51 (B Base) 1 14 14 ] in  (* a small hand-made game *)
  let later = List.fold_left (fun g _ -> fst (step g)) start (List.init 12 (fun i -> i)) in  (* 12 ticks *)
  check bool "a new building never lands on an occupied square" true (legal later)

let () =
  run "RTS-2 fixes"
    [ ( "fixes",
        [ test_case "1. the seal" `Quick test_seal;
          test_case "2. fairness" `Quick test_fair;
          test_case "3. honest randomness" `Quick test_random;
          test_case "4. legal positions" `Slow test_legal ] ) ]
