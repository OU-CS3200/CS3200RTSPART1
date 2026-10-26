(************************************************************************
   RTS-2, Part C — Properties (20 pts)

   Five QCheck properties of the engine. Each one takes a [Gen.recipe],
   builds the game with [Gen.game_of], and returns [true] when the engine
   behaves. Compare positions with [Gen.snapshot].

   How this is graded: we run YOUR properties against three engines, each
   with a different bug planted in it. A property suite that is any good
   fails on a buggy engine. You get the points if your suite catches at
   least two of the three (and passes on a correct engine). You do not get
   to see the buggy engines — that is the point. Think about what could go
   wrong, and check for it.

   Run:  dune test props
 ************************************************************************)

[@@@warning "-26-27-32-33"]
open Rtsarena

let count = 200

let numbers g = List.init (size g) (fun i -> i)  (* 0, 1, 2, ... up to size - 1 *)

let all_cells g =  (* every (x, y) square on the board *)
  List.concat (List.map (fun y -> List.map (fun x -> (x, y)) (numbers g)) (numbers g))

let map_total g =  (* all the resources still lying on the map *)
  List.fold_left (fun total (x, y) -> total + resource_left g x y) 0 (all_cells g)

let harvested evs =  (* how many Harvested events *)
  List.fold_left (fun n ev -> match ev with Harvested _ -> n + 1 | _ -> n) 0 evs

let deposited evs p =  (* how much player p deposited *)
  List.fold_left
    (fun total ev ->
       match ev with
       | Deposited { player; amount } -> if player = p then total + amount else total
       | _ -> total)
    0 evs

let carried g =  (* how much all the units are carrying *)
  List.fold_left (fun total (e : entity) -> total + e.carrying) 0 (entities g)

let worker_ids g =  (* the ids of all workers *)
  List.map (fun (e : entity) -> e.id) (List.filter is_worker (entities g))

let has_id g id = List.exists (fun (e : entity) -> e.id = id) (entities g)  (* is this id in the game? *)

let find_id g id = List.find_opt (fun (e : entity) -> e.id = id) (entities g)  (* look an entity up by id *)

let legal_game g =  (* everyone on the board, nobody on a wall, nobody sharing a square *)
  let es = entities g in
  let on_board = List.for_all (fun (e : entity) -> in_bounds g e.x e.y) es in (*is it true for all*)
  let off_walls = List.for_all (fun (e : entity) -> in_bounds g e.x e.y && cell_at g e.x e.y <> Wall) es in
  let alone =
    List.for_all
      (fun (a : entity) ->
         List.for_all (fun (b : entity) -> a.id = b.id || a.x <> b.x || a.y <> b.y) es)
      es in
  on_board && off_walls && alone

(** 1. (4 pts) Determinism: stepping the same game twice gives the same
    position and the same events. *)
let deterministic =
  QCheck.Test.make ~count ~name:"step is deterministic" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      let g1, events1 = step g in  (*once*)
      let g2, events2 = step g in (*same game*)
      Gen.snapshot g1 = Gen.snapshot g2 && events1 = events2 (*must be identical if not bug*)
  )

(** 2. (4 pts) Purity: stepping a game, or simulating a fork of it, does not
    change it. Take a snapshot before and after. *)
let pure =
  QCheck.Test.make ~count ~name:"step and rollout leave their argument alone" Gen.recipe
    (fun r ->
       let g = Gen.game_of r in
       let before = Gen.snapshot g in (*capture game*)
       let total_before = map_total g in (*what's on map*)
       let _ = step g in
       let _ = rollout (fork (view g 0)) light_rush heavy_rush ~ticks:30 in (*simulate*)
       let _ = rollout (fork (view g 1)) (random_bot 7) turtle ~ticks:30 in (*another simulation*)
       let fresh = make_game ~preset:r.Gen.preset () in (*same map not played on *)
       let terrain_same = List.for_all (fun (x,y) -> cell_at g x y = cell_at fresh x y) (all_cells g) in
       Gen.snapshot g = before && map_total g = total_before && terrain_same)


(** 3. (4 pts) Conservation, over one tick. Resources are never created or
    destroyed, only moved:
      - what left the map this tick is what workers picked up
        ([Harvested] events, one each);
      - on a tick where no worker died, what workers picked up either went
        into a stockpile ([Deposited]) or is still being carried (a worker
        that dies still acts first, so on those ticks you cannot see what it
        was carrying when it went — skip this check then);
      - each stockpile grew by exactly what was deposited for that player
        (spending happens in [apply_orders], never inside [step]).
    Hint: [resource_left]; and a worker of [g] missing from [g'] died. *)
let conserved =
  QCheck.Test.make ~count ~name:"resources are conserved" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      
      (*Orginial amounts*)
      let map_before = map_total g in
      let carried_before = carried g in
      let stock0_before = Rtsarena.resources_of g 0 in
      let stock1_before = Rtsarena.resources_of g 1 in
      let workers_before = worker_ids g in
      let g', events = step g in
      let map_after = map_total g' in
      let map_removed = map_before - map_after in
      let harvest_total = harvested events in
      let map_ok = map_removed = harvest_total in
      let worker_died = 
        List.exists (fun id -> not (has_id g' id)) workers_before in 
      let carry_ok = 
        worker_died || harvest_total = carried g' - carried_before + deposited events 0 + deposited events 1 in
      let stock0_ok = Rtsarena.resources_of g' 0 = 
        stock0_before + deposited events 0 in
      let stock1_ok = Rtsarena.resources_of g' 1 =
        stock1_before + deposited events 1 in
          
      map_ok && carry_ok && stock0_ok && stock1_ok
  )

(** 4. (4 pts) Legal positions: every entity is on the board, no unit
    stands on a wall, and no two entities share a cell. Check the game the
    recipe gives you and the one after it. *)
let legal =
  QCheck.Test.make ~count ~name:"every position is legal" Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

(** 5. (4 pts) One of your own. Name it, say in RTS2.md what it catches that
    the four above do not, and make it pass. *)
let mine =
  QCheck.Test.make ~count
    ~name:
      "TODO: name your property"
    Gen.recipe (fun r ->
      let g = Gen.game_of r in
      failwith "todo")

let all = [ deterministic; pure; conserved; legal; mine ]
