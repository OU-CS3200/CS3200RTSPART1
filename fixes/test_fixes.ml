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
  failwith "todo"

(** 2. Fairness. Two units that can kill each other in one blow must BOTH
    die in the same tick, whichever of them the engine looks at first. *)
let test_fair () =
  failwith "todo"

(** 3. Honest randomness. One [random_bot] value, played twice, plays the
    same game twice. *)
let test_random () =
  failwith "todo"

(** 4. Legal positions. Over real games, no unit ever stands on a wall and
    no two entities ever share a cell. (There is more than one way the old
    engine breaks this. Fixing the kiting is not enough.) *)
let test_legal () =
  failwith "todo"

let () =
  run "RTS-2 fixes"
    [ ( "fixes",
        [ test_case "1. the seal" `Quick test_seal;
          test_case "2. fairness" `Quick test_fair;
          test_case "3. honest randomness" `Quick test_random;
          test_case "4. legal positions" `Slow test_legal ] ) ]
