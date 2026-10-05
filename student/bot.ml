(************************************************************************
   RTS-1, Part C2 — Your bot (25 pts)

   Fill in your name and Ohio ID: *)
let name = "Jt Hepke"
let id = "jh639423@ohio.edu"

(* Build [my_bot] out of the combinators in rules.ml and the queries in
   queries.ml. Two rules for this file:

   - No [if] and no [match] anywhere in it (the tests check). Decisions are
     made by [when_], [guard] and [first_of], with predicates like the ones
     below.
   - [my_bot] stays a function: keep the [fun v -> ... v] around it, so that
     nothing runs until the game asks.

   The starter below gathers, builds a barracks, and then never trains a
   single soldier. It loses to every built-in bot. Graded matches are on the default 16x16 map,
   500 turns, and you must win on both sides. Try things with:

     dune exec bin/main.exe -- play my-bot light-rush --show
     dune exec test/test_rts1.exe -- test bot
 ************************************************************************)

open Rtsarena
open Queries
open Rules

(* ---- Given: predicates and board-dependent rules ------------------- *)

(** How many Light, Heavy and Ranged units you have. *)
let army (v : view) : int = count_of v Light + count_of v Heavy + count_of v Ranged

(** Enemy soldiers within [r] of your base. *)
let under_attack (r : int) (v : view) : bool = threats_near v ~radius:r <> []

(** Attack the enemy base (or, once it is gone, whatever is left). *)
let attack_enemy : rule = fun v ->
  Option.map (fun (x, y) -> [ Attack (x, y) ]) (enemy_target v)

(* ---- Your bot ------------------------------------------------------- *)

let economy : rule = always [ Harvest_with 2 ] (*2 workers always gather*)

let production : rule =
  first_of [ 
    when_ (fun v -> not (has_barracks v)) [ Build_barracks ]; (*No barracks, build one*)
    when_ (fun v -> count_of v Worker < 4) (*whens there is less than 4 workers*)
      [Train (Worker, 1); Train (Heavy, 1) ]; (*train worker and heavy*)
    always [ Train (Heavy, 1)] (*otherwise one heavy per turn*)
  ]

let posture : rule = 
  first_of
    [
      guard (fun v -> army v >= 2) attack_enemy; (*if you have 2 or more solfiers, attack them*)
      always [Defend] (*fewer stay home*)
    ]

let my_bot : bot = fun v -> to_bot (all_of [ economy; production; posture ]) v
