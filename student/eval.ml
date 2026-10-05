(************************************************************************
   RTS-1, Part B — An evaluation function (20 pts)

   [eval v] answers "how well am I doing?" as one number: positive means
   winning, negative means losing, 0.0 means even. RTS-3 will call it
   thousands of times to compare futures, so it has to mean something.

   Same rules as queries.ml: no rec, no List.length (comments are skipped).

   Build it in three steps:
     1. [side] measures ONE side: a record of plain numbers.
     2. [features] is my side minus their side, field by field.
     3. [eval] is the weighted sum of those differences.

   Built that way, eval is antisymmetric for free: whatever the position,
   what player 0 sees is exactly the negative of what player 1 sees. The
   tests check that on positions from real games.
 ************************************************************************)

open Rtsarena

(** What we measure about one side. Keep these fields; you may add more,
    but then add a matching weight below. *)
type side = {
  army : float;       (** total cost of combat units *)
  economy : float;    (** resources in the stockpile, plus what workers carry *)
  workers : float;    (** number of workers *)
  hp : float;         (** total hit points of everything *)
  base : float;       (** 1.0 if the base is standing, 0.0 if not *)
  barracks : float;   (** 1.0 if at least one barracks is standing *)
}

(** One weight per field of [side]. *)
type weights = {
  w_army : float;
  w_economy : float;
  w_workers : float;
  w_hp : float;
  w_base : float;
  w_barracks : float;
}

(** 1. (6 pts) [side units resources] measures one side, given all of its
    entities and its stockpile. Use [Queries.is_combat]. *)
let side (units : entity list) (resources : int) : side =
  let count_of_list list = List.fold_left (fun n _ -> n + 1) 0 list in (*Counter add 1 per item*)
  let army_cost = (*Total of all soldiers*)
    units (*look at every unit*)
    |> List.filter Queries.is_combat (*filter down to just soldiers*)
    (* add soldiers prices together 1 by 1, total starts at 0*)
    |> List.fold_left (fun total (e : entity) -> total + (stats_of_kind e.kind).cost) 0
  in
  let carried = (*amount of money workers have rn*)
    List.fold_left (fun total (e : entity) -> total + e.carrying) 0 units (*total added up starting at 0*)
  in
  let worker_count = 
    units (*look at all units*)
    |> List.filter is_worker (*filter to only workers*)
    |> count_of_list in (*count amout of workers*)
  let total_hp = (*total health of all units*)
    List.fold_left (fun total (e : entity) -> total + e.hp) 0 units
  in
  (*count of bases*)
  let base_count =
    units (*look at all units*)
    |> List.filter (fun (e : entity) -> e.kind = B Base) (*filter down to just bases*)
    |> count_of_list (*count bases amount in list*)
  in
  (*count of barracks*)
  let barracks_count =
    units 
    |> List.filter (fun (e : entity) -> e.kind = B Barracks) (*filter*)
    |> count_of_list (*count*)
  in { 
    army = float_of_int army_cost; (*into decimal*)
    economy = float_of_int (resources + carried); (*wants in bank + carried by workers into decimal*)
    workers = float_of_int worker_count; (*#workers into decimal*)
    hp = float_of_int total_hp; (*health into decimal*)
    base = (if base_count > 0 then 1.0 else 0.0); (*1 for a base, 0 for not*)
    barracks = (if barracks_count > 0 then 1.0 else 0.0) (*same thing*)
    }

(** 2. (6 pts) [features v] is (my side) minus (their side), field by field.
    Your units are [v.my_units] with [v.my_resources]; theirs are
    [v.enemy_units] with [v.enemy_resources]. *)
let features (v : view) : side =
  let mine = side v.my_units v.my_resources in (*get the values for my team*)
  let theirs = side v.enemy_units v.enemy_resources in (*get values for enemy *)
  {
    (*overall units = mine - theirs*)
    army = mine.army -. theirs.army;
    economy = mine.economy -. theirs.economy;
    workers = mine.workers -. theirs.workers;
    hp = mine.hp -. theirs.hp;
    base = mine.base -. theirs.base;
    barracks = mine.barracks -. theirs.barracks;
  }

(** 3. (4 pts) Your weights. The ones given here are a starting point that
    predicts some games; tune them. Say in README.md what you changed and
    why. *)
let weights : weights =
  { w_army = 4.0; w_economy = 0.1; w_workers = 0.0; w_hp = 0.1;
    w_base = 4.0; w_barracks = 0.1 }

(** 4. (4 pts) [eval_with w v] is the weighted sum of [features v]. *)
let eval_with (w : weights) (v : view) : float =
  let f = features v in (*get my features numbers*)
  (*the weight times the feature all added together with floats*)
  (w.w_army *. f.army) +. (w.w_economy *. f.economy) +. (w.w_workers *. f.workers) +. (w.w_hp *. f.hp) +. (w.w_base *. f.base) +. (w.w_barracks *. f.barracks)

(** Given. *)
let eval (v : view) : float = eval_with weights v
