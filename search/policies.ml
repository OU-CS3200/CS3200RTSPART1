(************************************************************************
   RTS-3, Part A1 — Candidate plans (10 pts)

   A search bot does not invent orders from nothing. At every consultation
   it chooses among a fixed menu of PLANS — each plan a whole bot — by
   trying each one in simulation. This file is the menu.

   Build the plans out of your RTS-1 combinators (Rules) and queries. A good
   menu is small (every plan costs a rollout at every consultation) and
   DIFFERENT (two plans that always give the same orders waste a rollout —
   though Part B's cache will make the second one nearly free).

   Requirements (the tests check the first two):
   - at least 6 plans, with distinct names;
   - your RTS-1 bot is one of them, named "my-bot";
   - no plan raises on any board.
 ************************************************************************)

[@@@warning "-32-33"]
open Rtsarena
open Queries
open Rules

(** Given: attack the enemy base, or whatever is left of the enemy. *)
let attack_enemy : rule =
 fun (v : view) -> Option.map (fun ((x, y) : int * int) -> [ Attack (x, y) ]) (enemy_target v)

let army (v : view) : int = count_of v Light + count_of v Heavy + count_of v Ranged

let candidates : (string * bot) list = [ ("my-bot", Bot.my_bot) ]
