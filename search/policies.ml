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

(* small building blocks *)
let eco (n : int) : rule = always [ Harvest_with n ]

let barracks_first : rule =
  when_ (fun v -> not (has_barracks v)) [ Build_barracks ]

let train (u : unit_type) : rule = always [ Train (u, 1) ]

let push_at (n : int) : rule = guard (fun v -> army v >= n) attack_enemy

(* a plan = economy + production + posture *)
let plan (e : rule) (prod : rule) (post : rule) : bot =
  fun v -> to_bot (all_of [ e; prod; post ]) v

(* 1. tanks: slow, strong, attack late *)
let heavy_turtle : bot =
  plan (eco 2)
    (first_of [ barracks_first; train Heavy ])
    (first_of [ push_at 5; always [ Defend ] ])

(* 2. fast and cheap, attack early *)
let light_flood : bot =
  plan (eco 2)
    (first_of [ barracks_first; train Light ])
    (first_of [ push_at 3; always [ Defend ] ])

(* 3. shooters from far away *)
let ranged_line : bot =
  plan (eco 2)
    (first_of [ barracks_first; train Ranged ])
    (first_of [ push_at 4; always [ Defend ] ])

(* 4. more workers first, then big army *)
let boom : bot =
  plan (eco 4)
    (first_of
       [ when_ (fun v -> count_of v Worker < 6) [ Train (Worker, 1) ];
         barracks_first;
         train Heavy ])
    (first_of [ push_at 6; always [ Defend ] ])

(* 5. stay home if enemy is close, else push *)
let counter : bot =
  plan (eco 2)
    (first_of
       [ barracks_first;
         when_ (fun v -> army v < 2) [ Train (Light, 1) ];
         train Heavy ])
    (first_of
       [ when_ (Bot.under_attack 6) [ Defend ]; push_at 3; always [ Defend ] ])

let candidates : (string * bot) list =
  [ ("my-bot", Bot.my_bot);
    ("heavy-turtle", heavy_turtle);
    ("light-flood", light_flood);
    ("ranged-line", ranged_line);
    ("boom", boom);
    ("counter", counter) ]