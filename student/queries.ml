(************************************************************************
   RTS-1, Part A — Queries (30 pts)

   Fill in your name and Ohio ID in bot.ml, not here.

   Every function in this file takes what a player can see (a [view]) and
   answers one question about it. The rules for this file:

   - No [let rec]. No [List.length].
   - Every answer is a pipeline of List.map / List.filter / List.fold_left /
     List.sort / List.find_opt / ... joined with [|>].

   The autograder reads this file and rejects the keyword rec and the name
   List.length anywhere in the code. (Comments are skipped, so this one is
   fine.)

   Useful things from the engine (engine/rtsarena.ml):
     v.my_units, v.enemy_units : entity list   (both include buildings)
     is_building e, is_worker e : bool
     dist a b : int                            Manhattan distance
     unit_stats u, building_stats b, stats_of_kind k : stats   (.cost, .hp, ...)
 ************************************************************************)

open Rtsarena
open Util

(** A combat unit is anything that is neither a building nor a worker:
    Light, Heavy, or Ranged. Given — use it. *)
let is_combat (e : entity) : bool = (not (is_building e)) && not (is_worker e)

(** 1. (5 pts) [count_by_kind v] counts your own entities (units AND
    buildings) by kind. One pair per kind you actually have, sorted by kind
    with [compare]. Kinds you have none of do not appear.

    At the start of a game: [[(U Worker, 2); (B Base, 1)]]. *)
let count_by_kind (v : view) : (kind * int) list =
  todo v

(** 2. (5 pts) [army_value v] is the total [cost] of your combat units.
    Workers and buildings do not count. *)
let army_value (v : view) : int =
  todo v

(** 3. (5 pts) [nearest_enemy v u] is the enemy entity (unit or building)
    closest to [u] by Manhattan distance, or [None] if there are no enemies.
    Ties go to the smaller [id]. *)
let nearest_enemy (v : view) (u : entity) : entity option =
  todo (v, u)

(** 4. (5 pts) [threats_near v ~radius] is every enemy COMBAT unit within
    [radius] (inclusive) of your base, nearest to the base first, ties by
    smaller [id]. If you have no base, the answer is [[]]. *)
let threats_near (v : view) ~(radius : int) : entity list =
  todo (v, radius)

(** 5. (5 pts) [idle_workers v] is your workers whose [action] is [None],
    in the order they appear in [v.my_units]. *)
let idle_workers (v : view) : entity list =
  todo v

(** 6. (5 pts) [income evs ~player] is the total amount [player] deposited
    at their base, over a list of events (what [step] returns). Only
    [Deposited] events count. *)
let income (evs : event list) ~(player : int) : int =
  todo (evs, player)
