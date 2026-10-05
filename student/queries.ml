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

(** A combat unit is anything that is neither a building nor a worker:
    Light, Heavy, or Ranged. Given — use it. *)
let is_combat (e : entity) : bool = (not (is_building e)) && not (is_worker e)

(** 1. (5 pts) [count_by_kind v] counts your own entities (units AND
    buildings) by kind. One pair per kind you actually have, sorted by kind
    with [compare]. Kinds you have none of do not appear.

    At the start of a game: [[(U Worker, 2); (B Base, 1)]]. *)

(*Helper function*)
let count_kind (v : view) (k : kind) : int =
  v.my_units(*view the list of all the stuff on board*)
  |> List.filter (fun (e : entity) -> e.kind = k) (*keep only units of kind k*)
  |> List.fold_left (fun n _ -> n + 1) 0 (*counts them, repleacment for list.length*)

let count_by_kind (v : view) : (kind * int) list =
  [ U Worker; U Light; U Heavy; U Ranged; B Base; B Barracks] (*goes through in this order based on value*)
  |> List.map (fun k -> (k, count_kind v k)) (*turns kind into a pair*)
  |> List.filter (fun (_, n ) -> n > 0) (*removes pairs of 0*)

(** 2. (5 pts) [army_value v] is the total [cost] of your combat units.
    Workers and buildings do not count. *)
let army_value (v : view) : int =
  v.my_units (*view the list of all the stuff on board*)
  |> List.filter is_combat (*filter down to just soldiers*)
  (*look up soldiers stats, grab only the cost and add it to total*)
  |> List.fold_left (fun total (e : entity) -> total + (stats_of_kind e.kind).cost) 0

(** 3. (5 pts) [nearest_enemy v u] is the enemy entity (unit or building)
    closest to [u] by Manhattan distance, or [None] if there are no enemies.
    Ties go to the smaller [id]. *)

(*Hepler function*)
let first_or_none (items : entity list) : entity option =
  match items with
  |[] -> None (*return none of list empty*)
  |first :: _ -> Some first (*grab the first entity in sorted list*)
let nearest_enemy (v : view) (u : entity) : entity option =
  v.enemy_units (*grab the view list of enemy entitys*)
  (*pair of (distance, id) compares the distance first look at the id second if tied*)
  |> List.sort (fun (a :entity) (b : entity) -> compare (dist a u, a.id) (dist b u, b.id))
  |> first_or_none (*call to helper to store first from sorted list*)

(** 4. (5 pts) [threats_near v ~radius] is every enemy COMBAT unit within
    [radius] (inclusive) of your base, nearest to the base first, ties by
    smaller [id]. If you have no base, the answer is [[]]. *)

(*Helper function*)
let find_base (v : view) : entity option =
  v.my_units
  (*look through list for the first item that matches with a entity base*)
  |> List.find_opt (fun (e : entity) -> e.kind = B Base) 
let threats_near (v : view) ~(radius : int) : entity list =
  match find_base v with
  | None -> [] 
  | Some base ->
    v.enemy_units
    |> List.filter is_combat (*get only soilders*)
    |> List.filter (fun (e : entity) -> dist e base <= radius) (*see if soldiers are in the radius*)
    |> List.sort (fun (a : entity) (b : entity) -> compare (dist a base, a.id) (dist b base, b.id)) (*sort by which is closest again, then sort by id value if tied*)

(** 5. (5 pts) [idle_workers v] is your workers whose [action] is [None],
    in the order they appear in [v.my_units]. *)
let idle_workers (v : view) : entity list =
  v.my_units
  |> List.filter is_worker (*no soldiers or buildings*)
  |> List.filter (fun (e : entity) -> e.action = None) (*check their action box if not working keep*)
(*Same order as the my units list*)

(** 6. (5 pts) [income evs ~player] is the total amount [player] deposited
    at their base, over a list of events (what [step] returns). Only
    [Deposited] events count. *)
let income (evs : event list) ~(player : int) : int =
  evs (*open list of events*)
  |> List.fold_left 
  (fun total ev -> 
    match ev with
    | Deposited { player = p; amount = a} -> if p = player then (*who deposited and how much, if out player add amount*)
      total + a else total
    | _ -> total) 0
