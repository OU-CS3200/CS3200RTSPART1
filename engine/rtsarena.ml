(** RTSArena — an OCaml implementation of the MicroRTS / RTSArena game engine.

    Ported from [RTSArena/lib/game-engine.js]. The rules are the same; the
    implementation is not a transliteration. The JavaScript engine mutates a
    world in place; this one is a pure function of state:

    {[ val step : game -> game * event list ]}

    Every tick produces a {i new} [game]. Nothing is assigned to. That makes
    a game a value you can save, replay, fork for lookahead search, or compare
    — which is exactly the property a tree search wants, and exactly the point
    CS 3200 spends the semester making.

    No external libraries. Standard library only. *)

(* ------------------------------------------------------------------ *)
(* 1. Units, buildings, and their statistics                          *)
(* ------------------------------------------------------------------ *)

type unit_type = Worker | Light | Heavy | Ranged
type building_type = Base | Barracks

type kind =
  | U of unit_type
  | B of building_type

(** Combat and economy statistics. [build_ticks] is how long a producer is
    occupied making one; [speed] is cells moved per tick. *)
type stats = {
  hp : int;
  cost : int;
  build_ticks : int;
  speed : int;
  damage : int;
  range : int;
}

(* These values mirror UNIT_STATS / BUILDING_STATS in game-engine.js, which is
   the single source of truth for balance. The tables printed in
   SUBPROCESS_PROTOCOL.md and CLAUDE.md are stale — see docs/index.html. *)
let unit_stats = function
  | Worker -> { hp = 1;  cost = 1; build_ticks = 4; speed = 1; damage = 1; range = 1 }
  | Light  -> { hp = 5;  cost = 2; build_ticks = 4; speed = 2; damage = 3; range = 1 }
  | Heavy  -> { hp = 10; cost = 3; build_ticks = 6; speed = 1; damage = 4; range = 1 }
  | Ranged -> { hp = 3;  cost = 2; build_ticks = 6; speed = 1; damage = 1; range = 4 }

let building_stats = function
  | Base     -> { hp = 10; cost = 10; build_ticks = 15; speed = 0; damage = 0; range = 0 }
  | Barracks -> { hp = 5;  cost = 5;  build_ticks = 10; speed = 0; damage = 0; range = 0 }

let stats_of_kind = function U u -> unit_stats u | B b -> building_stats b

let string_of_unit_type = function
  | Worker -> "worker" | Light -> "light" | Heavy -> "heavy" | Ranged -> "ranged"

let string_of_building_type = function Base -> "base" | Barracks -> "barracks"

let string_of_kind = function
  | U u -> string_of_unit_type u
  | B b -> string_of_building_type b

let unit_type_of_string = function
  | "worker" -> Some Worker | "light" -> Some Light
  | "heavy"  -> Some Heavy  | "ranged" -> Some Ranged
  | _ -> None

(* ------------------------------------------------------------------ *)
(* 2. Entities                                                        *)
(* ------------------------------------------------------------------ *)

(** What an entity is currently doing. Actions persist across ticks until
    replaced — they are the unit-level consequence of a player's orders. *)
type action =
  | Harvest of (int * int) option        (** remembered resource tile *)
  | Attack_at of int * int               (** march on a position, hit what is in range *)
  | Move_to of int * int
  | Building_it of { btype : building_type; bx : int; by : int; progress : int }

type entity = {
  id : int;
  kind : kind;
  player : int;                          (** 0 or 1 *)
  x : int;
  y : int;
  hp : int;
  max_hp : int;
  damage : int;
  range : int;
  speed : int;
  carrying : int;                        (** resources a worker is holding *)
  action : action option;
  producing : (unit_type * int) option;  (** what a building is making, ticks left *)
}

let is_building e = match e.kind with B _ -> true | U _ -> false
let is_worker e = e.kind = U Worker

let make_entity id kind player x y =
  let s = stats_of_kind kind in
  { id; kind; player; x; y;
    hp = s.hp; max_hp = s.hp;
    damage = s.damage; range = s.range; speed = s.speed;
    carrying = 0; action = None; producing = None }

(* ------------------------------------------------------------------ *)
(* 3. The map                                                         *)
(* ------------------------------------------------------------------ *)

type cell = Empty | Resource | Wall

module Pos = struct
  type t = int * int
  let compare = compare
end

module PosMap = Map.Make (Pos)

(** A game is a value. [step] returns a new one; nothing here is mutable.

    [terrain] never changes during play, so it stays a plain array. What a
    harvest consumes is [res], a map from a tile to the amount left. *)
type game = {
  size : int;
  max_turns : int;
  turn : int;
  entities : entity list;
  resources : int * int;                 (** stockpile for player 0, player 1 *)
  terrain : cell array array;            (** [terrain.(y).(x)] *)
  res : int PosMap.t;                    (** remaining amount per resource tile *)
  next_id : int;
  over : bool;
  winner : int;                          (** 0, 1, or -1 for a draw *)
  reason : string;
}

type event =
  | Produced of { player : int; what : unit_type; x : int; y : int }
  | Deposited of { player : int; amount : int }
  | Harvested of { player : int; x : int; y : int }
  | Combat of { attacker : int; target : int; damage : int }
  | Built of { player : int; what : building_type; x : int; y : int }
  | Destroyed of { player : int; what : kind }

let resources_of g p = let a, b = g.resources in if p = 0 then a else b

let set_resources g p v =
  let a, b = g.resources in
  { g with resources = (if p = 0 then (v, b) else (a, v)) }

let spend g p n = set_resources g p (resources_of g p - n)

let in_bounds g x y = x >= 0 && x < g.size && y >= 0 && y < g.size
let dist a b = abs (a.x - b.x) + abs (a.y - b.y)
let dist_xy x1 y1 x2 y2 = abs (x1 - x2) + abs (y1 - y2)

let cell_at g x y = if in_bounds g x y then g.terrain.(y).(x) else Wall

(** A tile still worth walking to: marked [Resource] and not yet exhausted. *)
let has_resource g x y =
  cell_at g x y = Resource
  && (match PosMap.find_opt (x, y) g.res with Some n -> n > 0 | None -> false)

let occupied ?(except = -1) g x y =
  cell_at g x y = Wall
  || List.exists (fun e -> e.x = x && e.y = y && e.id <> except) g.entities

let entities_of g ?kind ?building player =
  List.filter
    (fun e ->
       e.player = player
       && (match kind with None -> true | Some k -> e.kind = k)
       && (match building with None -> true | Some b -> is_building e = b))
    g.entities

let find_building g player bt =
  List.find_opt (fun e -> e.player = player && e.kind = B bt) g.entities

(* ---- map presets -------------------------------------------------- *)

(* Mirrors MAP_PRESETS_BY_SIZE. Each listed tile is placed, then mirrored
   through the centre so both players face the same map. *)
let preset_resources size preset =
  match size, preset with
  | 8, "rich"      -> [ 1,1; 2,0; 0,2; 3,3; 2,2; 1,3; 3,1 ], 10
  | 8, "sparse"    -> [ 3,3; 2,2 ], 10
  | 8, _           -> [ 1,1; 2,0; 0,2; 3,3 ], 10
  | 16, "rich"     -> [ 2,2; 3,1; 1,3; 5,5; 6,4; 4,6; 4,2; 2,4; 7,7 ], 15
  | 16, "sparse"   -> [ 2,2; 5,5; 6,4 ], 15
  | 16, _          -> [ 2,2; 3,1; 1,3; 5,5; 6,4; 4,6 ], 15
  | 32, "sparse"   -> [ 2,2; 5,5; 10,10; 14,3; 3,14 ], 20
  | 32, _          -> [ 2,2; 3,1; 1,3; 5,5; 6,4; 4,6; 10,10; 11,9; 9,11;
                        14,3; 3,14; 8,15; 15,8 ], 20
  | _              -> [ 2,2; 5,5 ], 10

let preset_walls size preset =
  match size, preset with
  | 8, "corridors"  -> [ 3,1; 3,2; 4,5; 4,6 ]
  | 16, "corridors" -> [ 7,3; 7,4; 7,5; 8,11; 8,10; 8,9 ]
  | _ -> []

(** Build the starting position: a mirrored map, one base and two workers each. *)
let make_game ?(size = 16) ?(max_turns = 500) ?(preset = "default") () =
  let terrain = Array.make_matrix size size Empty in
  let tiles, amount = preset_resources size preset in
  let res = ref PosMap.empty in
  let place x y =
    if x >= 0 && x < size && y >= 0 && y < size then begin
      terrain.(y).(x) <- Resource;
      res := PosMap.add (x, y) amount !res
    end
  in
  List.iter (fun (rx, ry) -> place rx ry; place (size - 1 - rx) (size - 1 - ry)) tiles;
  List.iter
    (fun (wx, wy) ->
       if wx >= 0 && wx < size && wy >= 0 && wy < size then
         terrain.(wy).(wx) <- Wall;
       let mx = size - 1 - wx and my = size - 1 - wy in
       if mx >= 0 && mx < size && my >= 0 && my < size then terrain.(my).(mx) <- Wall)
    (preset_walls size preset);
  let s = size in
  let entities =
    [ make_entity 1 (B Base) 0 1 1;
      make_entity 2 (U Worker) 0 2 1;
      make_entity 3 (U Worker) 0 1 2;
      make_entity 4 (B Base) 1 (s - 2) (s - 2);
      make_entity 5 (U Worker) 1 (s - 3) (s - 2);
      make_entity 6 (U Worker) 1 (s - 2) (s - 3) ]
  in
  { size; max_turns; turn = 0; entities; resources = (5, 5);
    terrain; res = !res; next_id = 7;
    over = false; winner = -1; reason = "" }

(* ------------------------------------------------------------------ *)
(* 4. Movement                                                        *)
(* ------------------------------------------------------------------ *)

(** Breadth-first search for the first step of a shortest path.

    Returns the neighbour of [(sx,sy)] to step onto, or [None] when the target
    is unreachable. Occupied cells are impassable, except the target itself —
    so a unit can walk up to something and stop next to it. *)
let bfs_next_step g (sx, sy) (tx, ty) id =
  if sx = tx && sy = ty then None
  else begin
    let n = g.size in
    let visited = Array.make_matrix n n false in
    let parent = Array.make_matrix n n (-1, -1) in
    let q = Queue.create () in
    Queue.add (sx, sy) q;
    visited.(sy).(sx) <- true;
    let found = ref false in
    while (not !found) && not (Queue.is_empty q) do
      let cx, cy = Queue.pop q in
      List.iter
        (fun (dx, dy) ->
           if not !found then begin
             let nx = cx + dx and ny = cy + dy in
             if in_bounds g nx ny
             && (not visited.(ny).(nx))
             && cell_at g nx ny <> Wall
             && ((not (occupied ~except:id g nx ny)) || (nx = tx && ny = ty))
             then begin
               visited.(ny).(nx) <- true;
               parent.(ny).(nx) <- (cx, cy);
               if nx = tx && ny = ty then found := true else Queue.add (nx, ny) q
             end
           end)
        [ (0, -1); (0, 1); (-1, 0); (1, 0) ]
    done;
    if not !found then None
    else begin
      (* walk the parent chain back until the step next to the start *)
      let bx = ref tx and by = ref ty in
      let continue_ = ref true in
      while !continue_ do
        let px, py = parent.(!by).(!bx) in
        if px = sx && py = sy then continue_ := false
        else if px = -1 then continue_ := false
        else begin bx := px; by := py end
      done;
      Some (!bx, !by)
    end
  end

(** Take up to [speed] steps toward a target. Returns the moved entity. *)
let move_toward g e (tx, ty) =
  let rec go e n =
    if n = 0 then e
    else
      match bfs_next_step g (e.x, e.y) (tx, ty) e.id with
      | Some (nx, ny) when not (occupied ~except:e.id g nx ny) ->
        go { e with x = nx; y = ny } (n - 1)
      | _ -> e
  in
  go e (max 1 e.speed)

(** The first free cell around [(x,y)], used for placing produced units and
    new buildings. Mirrors findBuildSpot's search order. *)
let find_build_spot g x y =
  let dirs = [ (1,0);(0,1);(-1,0);(0,-1);(1,1);(-1,1);(1,-1);(-1,-1);
               (2,0);(0,2);(-2,0);(0,-2) ] in
  List.find_map
    (fun (dx, dy) ->
       let nx = x + dx and ny = y + dy in
       if in_bounds g nx ny && (not (occupied g nx ny)) && cell_at g nx ny = Empty
       then Some (nx, ny) else None)
    dirs

let nearest_resource g x y =
  PosMap.fold
    (fun (rx, ry) amount best ->
       if amount <= 0 then best
       else
         let d = dist_xy rx ry x y in
         match best with
         | Some (_, bd) when bd <= d -> best
         | _ -> Some ((rx, ry), d))
    g.res None
  |> Option.map fst

(* ------------------------------------------------------------------ *)
(* 5. One tick of the world                                           *)
(* ------------------------------------------------------------------ *)

(* Replace an entity in the world by id. Entities are resolved one at a time,
   each seeing the effects of the ones before it — the same sequential
   resolution the JavaScript engine gets from mutating in place. *)
let replace g e =
  { g with entities = List.map (fun o -> if o.id = e.id then e else o) g.entities }

let damage_entity g id amount =
  { g with
    entities =
      List.map (fun o -> if o.id = id then { o with hp = o.hp - amount } else o)
        g.entities }

let step_building g e evs =
  match e.producing with
  | None -> (g, evs)
  | Some (what, ticks_left) ->
    let ticks_left = ticks_left - 1 in
    if ticks_left > 0 then (replace g { e with producing = Some (what, ticks_left) }, evs)
    else
      let g = replace g { e with producing = None } in
      (match find_build_spot g e.x e.y with
       | None -> (g, evs)
       | Some (nx, ny) ->
         let baby = make_entity g.next_id (U what) e.player nx ny in
         ({ g with entities = g.entities @ [ baby ]; next_id = g.next_id + 1 },
          Produced { player = e.player; what; x = nx; y = ny } :: evs))

let step_harvest g e remembered evs =
  if e.carrying > 0 then
    (* carrying: walk home and drop it off *)
    match find_building g e.player Base with
    | None -> (replace g { e with action = None }, evs)
    | Some base ->
      if dist e base <= 1 then
        let g = set_resources g e.player (resources_of g e.player + e.carrying) in
        (replace g { e with carrying = 0 },
         Deposited { player = e.player; amount = e.carrying } :: evs)
      else (replace g (move_toward g e (base.x, base.y)), evs)
  else
    (* empty-handed: go to a resource tile and pick one up *)
    let target =
      match remembered with
      | Some (tx, ty) when has_resource g tx ty -> Some (tx, ty)
      | _ -> nearest_resource g e.x e.y
    in
    match target with
    | None -> (replace g { e with action = None }, evs)
    | Some (tx, ty) ->
      if e.x = tx && e.y = ty then
        if has_resource g tx ty then
          let left = PosMap.find (tx, ty) g.res - 1 in
          let g = { g with res = PosMap.add (tx, ty) left g.res } in
          (replace g { e with carrying = 1; action = Some (Harvest None) },
           Harvested { player = e.player; x = tx; y = ty } :: evs)
        else (replace g { e with action = Some (Harvest None) }, evs)
      else
        let e = move_toward g e (tx, ty) in
        (replace g { e with action = Some (Harvest (Some (tx, ty))) }, evs)

(* Ranged units kite: after firing they back away from an adjacent slow melee
   unit, which is what makes range 4 worth having. *)
let kite g e pool =
  if e.range <= 1 then e
  else
    let melee = List.filter (fun en -> en.range <= 1 && en.speed < 2) pool in
    let nearest =
      List.fold_left
        (fun best m ->
           let d = dist e m in
           match best with Some (_, bd) when bd <= d -> best | _ -> Some (m, d))
        None melee
    in
    match nearest with
    | Some (m, d) when d <= e.range + 2 ->
      let sgn v = compare v 0 in
      let dx = sgn (e.x - m.x) and dy = sgn (e.y - m.y) in
      let clamp v = max 0 (min (g.size - 1) v) in
      if dx <> 0 then { e with x = clamp (e.x + dx) }
      else if dy <> 0 then { e with y = clamp (e.y + dy) }
      else e
    | _ -> e

let step_attack g e ax ay evs =
  let enemies = List.filter (fun en -> en.player <> e.player && en.hp > 0) g.entities in
  (* prefer real soldiers; fall back to whatever is left *)
  let military =
    List.filter (fun en -> (not (is_building en)) && not (is_worker en)) enemies
  in
  let pool = if military <> [] then military else enemies in
  let nearest =
    List.fold_left
      (fun best en ->
         let d = dist e en in
         match best with Some (_, bd) when bd <= d -> best | _ -> Some (en, d))
      None pool
  in
  match nearest with
  | Some (target, d) when d <= e.range ->
    let g = damage_entity g target.id e.damage in
    let e = kite g e pool in
    (replace g e, Combat { attacker = e.id; target = target.id; damage = e.damage } :: evs)
  | Some (target, _) -> (replace g (move_toward g e (target.x, target.y)), evs)
  | None -> (replace g (move_toward g e (ax, ay)), evs)

let step_build g e bt bx by progress evs =
  if dist_xy e.x e.y bx by <= 1 then
    let progress = progress + 1 in
    if progress >= (building_stats bt).build_ticks then
      let b = make_entity g.next_id (B bt) e.player bx by in
      let g = replace g { e with action = None } in
      ({ g with entities = g.entities @ [ b ]; next_id = g.next_id + 1 },
       Built { player = e.player; what = bt; x = bx; y = by } :: evs)
    else
      (replace g { e with action = Some (Building_it { btype = bt; bx; by; progress }) }, evs)
  else (replace g (move_toward g e (bx, by)), evs)

let step_entity (g, evs) id =
  (* look the entity up again: an earlier entity this tick may have killed it *)
  match List.find_opt (fun e -> e.id = id && e.hp > 0) g.entities with
  | None -> (g, evs)
  | Some e ->
    if is_building e then step_building g e evs
    else
      match e.action with
      | None -> (g, evs)
      | Some (Harvest remembered) -> step_harvest g e remembered evs
      | Some (Attack_at (ax, ay)) -> step_attack g e ax ay evs
      | Some (Move_to (mx, my)) ->
        if e.x = mx && e.y = my then (replace g { e with action = None }, evs)
        else (replace g (move_toward g e (mx, my)), evs)
      | Some (Building_it { btype; bx; by; progress }) ->
        step_build g e btype bx by progress evs

let check_game_over g =
  let alive p = List.filter (fun e -> e.player = p) g.entities in
  let p0 = alive 0 and p1 = alive 1 in
  let total_hp l = List.fold_left (fun s e -> s + e.hp) 0 l in
  if p0 = [] && p1 = [] then
    { g with over = true; winner = -1; reason = "Mutual destruction" }
  else if p0 = [] then { g with over = true; winner = 1; reason = "All Blue forces destroyed" }
  else if p1 = [] then { g with over = true; winner = 0; reason = "All Red forces destroyed" }
  else if g.turn >= g.max_turns then
    let h0 = total_hp p0 and h1 = total_hp p1 in
    if h0 > h1 then { g with over = true; winner = 0; reason = "Time" }
    else if h1 > h0 then { g with over = true; winner = 1; reason = "Time" }
    else { g with over = true; winner = -1; reason = "Time limit (draw)" }
  else g

(** Advance the world one tick. Pure: the argument is untouched. *)
let step g =
  if g.over then (g, [])
  else begin
    let g = { g with turn = g.turn + 1 } in
    let ids = List.map (fun e -> e.id) g.entities in
    let g, evs = List.fold_left step_entity (g, []) ids in
    let dead = List.filter (fun e -> e.hp <= 0) g.entities in
    let evs =
      List.fold_left
        (fun acc d -> Destroyed { player = d.player; what = d.kind } :: acc) evs dead
    in
    let g = { g with entities = List.filter (fun e -> e.hp > 0) g.entities } in
    (check_game_over g, List.rev evs)
  end

(* ------------------------------------------------------------------ *)
(* 6. Orders — the layer a player actually controls                   *)
(* ------------------------------------------------------------------ *)

(** A player does not command individual units. Each consultation it issues
    {i standing orders}, which persist until the next consultation. *)
type order =
  | Harvest_with of int                  (** assign N workers to gather *)
  | Build_barracks
  | Train of unit_type * int
  | Attack of int * int
  | Defend
  | Retreat

let string_of_order = function
  | Harvest_with n -> Printf.sprintf "harvest %d" n
  | Build_barracks -> "build barracks"
  | Train (u, n) -> Printf.sprintf "train %d %s" n (string_of_unit_type u)
  | Attack (x, y) -> Printf.sprintf "attack %d,%d" x y
  | Defend -> "defend"
  | Retreat -> "retreat"

(* Turn standing orders into per-unit actions. Mirrors TacticalAI.execute. *)
let apply_orders g player orders =
  let harvest_count =
    List.fold_left (fun acc o -> match o with Harvest_with n -> n | _ -> acc) 0 orders
  in
  let wants_barracks = List.exists (fun o -> o = Build_barracks) orders in
  let trains =
    List.filter_map (function Train (u, n) -> Some (u, n) | _ -> None) orders
  in
  let attack_at =
    List.fold_left (fun acc o -> match o with Attack (x, y) -> Some (x, y) | _ -> acc)
      None orders
  in
  let defending = List.exists (fun o -> o = Defend) orders in
  let retreating = List.exists (fun o -> o = Retreat) orders in

  (* --- workers to the mines --- *)
  let workers = List.filter (fun e -> e.player = player && is_worker e) g.entities in
  let g, _ =
    List.fold_left
      (fun (g, assigned) w ->
         if assigned >= harvest_count then (g, assigned)
         else
           match w.action with
           | Some (Building_it _) -> (g, assigned)
           | Some (Harvest _) -> (g, assigned + 1)
           | _ -> (replace g { w with action = Some (Harvest None) }, assigned + 1))
      (g, 0) workers
  in

  (* --- a barracks, once --- *)
  let g =
    if not wants_barracks then g
    else
      let have = entities_of g ~kind:(B Barracks) player <> [] in
      let building_one =
        List.exists
          (fun w -> match w.action with Some (Building_it _) -> true | _ -> false)
          workers
      in
      if have || building_one || resources_of g player < (building_stats Barracks).cost
      then g
      else
        match find_building g player Base with
        | None -> g
        | Some base ->
          (match find_build_spot g base.x base.y with
           | None -> g
           | Some (bx, by) ->
             let builder =
               match List.find_opt
                       (fun w -> match w.action with
                          | None | Some (Harvest _) -> true | _ -> false) workers with
               | Some w -> Some w
               | None -> (match workers with w :: _ -> Some w | [] -> None)
             in
             (match builder with
              | None -> g
              | Some w ->
                let g =
                  replace g
                    { w with action = Some (Building_it { btype = Barracks; bx; by; progress = 0 }) }
                in
                spend g player (building_stats Barracks).cost))
  in

  (* --- production --- *)
  let g =
    List.fold_left
      (fun g (what, count) ->
         let s = unit_stats what in
         let producer_kind = if what = Worker then B Base else B Barracks in
         let rec queue g n =
           if n <= 0 || resources_of g player < s.cost then g
           else
             match
               List.find_opt
                 (fun b -> b.player = player && b.kind = producer_kind && b.producing = None)
                 g.entities
             with
             | None -> g
             | Some b ->
               let g = replace g { b with producing = Some (what, s.build_ticks) } in
               queue (spend g player s.cost) (n - 1)
         in
         queue g count)
      g trains
  in

  (* --- army posture --- *)
  let mine () = List.filter (fun e -> e.player = player && not (is_building e)) g.entities in
  let combat_units () =
    List.filter
      (fun u -> (not (is_worker u))
                || match u.action with Some (Attack_at _) -> true | _ -> false)
      (mine ())
  in
  if retreating then
    match find_building g player Base with
    | None -> g
    | Some base ->
      List.fold_left
        (fun g u ->
           let keep_harvesting =
             is_worker u && (match u.action with Some (Harvest _) -> true | _ -> false)
           in
           if keep_harvesting then g
           else replace g { u with action = Some (Move_to (base.x, base.y)) })
        g (mine ())
  else if defending then
    match find_building g player Base with
    | None -> g
    | Some base ->
      let enemies = List.filter (fun e -> e.player <> player && e.hp > 0) g.entities in
      let near = List.find_opt (fun en -> dist en base <= 5) enemies in
      List.fold_left
        (fun g u ->
           match u.action with
           | Some (Attack_at _) -> g
           | _ ->
             let a =
               match near with
               | Some en -> Attack_at (en.x, en.y)
               | None ->
                 (* hold a loose ring around the base *)
                 let off = if (u.id + g.turn) land 1 = 0 then 1 else -1 in
                 Move_to (max 0 (min (g.size - 1) (base.x + off)),
                          max 0 (min (g.size - 1) (base.y + off)))
             in
             replace g { u with action = Some a })
        g (combat_units ())
  else
    match attack_at with
    | None -> g
    | Some (ax, ay) ->
      let g =
        List.fold_left (fun g u -> replace g { u with action = Some (Attack_at (ax, ay)) })
          g (combat_units ())
      in
      (* workers beyond the harvest quota join the push *)
      let workers = List.filter (fun e -> e.player = player && is_worker e) g.entities in
      List.fold_left
        (fun (g, i) w ->
           if i >= harvest_count then
             (replace g { w with action = Some (Attack_at (ax, ay)) }, i + 1)
           else (g, i + 1))
        (g, 0) workers
      |> fst

(* ------------------------------------------------------------------ *)
(* 7. What a player is allowed to see                                 *)
(* ------------------------------------------------------------------ *)

type view = {
  v_turn : int;
  v_max_turns : int;
  my_resources : int;
  enemy_resources : int;
  my_units : entity list;
  enemy_units : entity list;
  v_size : int;
  v_game : game;                         (** the whole world; full information *)
}

let view g player =
  { v_turn = g.turn; v_max_turns = g.max_turns;
    my_resources = resources_of g player;
    enemy_resources = resources_of g (1 - player);
    my_units = List.filter (fun e -> e.player = player) g.entities;
    enemy_units = List.filter (fun e -> e.player <> player) g.entities;
    v_size = g.size; v_game = g }

(** The board as text, from [player]'s side: your pieces upper-case, theirs
    lower-case, [$] a resource tile, [#] a wall. This is exactly the rendering
    an LLM player is shown. *)
let to_ascii g player =
  let ch_of e =
    let c = match e.kind with
      | B Base -> 'B' | B Barracks -> 'K'
      | U Worker -> 'W' | U Light -> 'L' | U Heavy -> 'H' | U Ranged -> 'R'
    in
    if e.player = player then c else Char.lowercase_ascii c
  in
  let grid = Array.make_matrix g.size g.size '.' in
  for y = 0 to g.size - 1 do
    for x = 0 to g.size - 1 do
      match g.terrain.(y).(x) with
      | Resource -> if has_resource g x y then grid.(y).(x) <- '$'
      | Wall -> grid.(y).(x) <- '#'
      | Empty -> ()
    done
  done;
  List.iter (fun e -> grid.(e.y).(e.x) <- ch_of e) g.entities;
  let buf = Buffer.create ((g.size + 4) * (g.size + 1)) in
  Buffer.add_string buf "   ";
  for x = 0 to g.size - 1 do Buffer.add_string buf (string_of_int (x mod 10)) done;
  Buffer.add_char buf '\n';
  for y = 0 to g.size - 1 do
    Buffer.add_string buf (Printf.sprintf "%2d " y);
    for x = 0 to g.size - 1 do Buffer.add_char buf grid.(y).(x) done;
    Buffer.add_char buf '\n'
  done;
  Buffer.contents buf

(* ------------------------------------------------------------------ *)
(* 8. Bots                                                            *)
(* ------------------------------------------------------------------ *)

(** A bot is a function from what it can see to the orders it wants. That is
    the whole interface — no classes, no inheritance, no mutable state. *)
type bot = view -> order list

let has_barracks v =
  List.exists (fun e -> e.kind = B Barracks) v.my_units

let enemy_target v =
  let bases = List.filter (fun e -> e.kind = B Base) v.enemy_units in
  match bases, v.enemy_units with
  | b :: _, _ -> Some (b.x, b.y)
  | [], e :: _ -> Some (e.x, e.y)
  | [], [] -> None

let count_of v u =
  List.length (List.filter (fun e -> e.kind = U u) v.my_units)

let attack_or_defend v ready =
  if ready then
    match enemy_target v with Some (x, y) -> [ Attack (x, y) ] | None -> [ Defend ]
  else [ Defend ]

(* A rush: one barracks, then a stream of one unit type, attack at [n]. *)
let rush_bot unit_type batch threshold : bot =
  fun v ->
  Harvest_with 2
  :: (if has_barracks v then Train (unit_type, batch) else Build_barracks)
  :: attack_or_defend v (count_of v unit_type >= threshold)

let worker_rush : bot = fun v ->
  let cmds = [ Harvest_with 1; Train (Worker, 3) ] in
  if v.v_turn > 30 then
    match enemy_target v with Some (x, y) -> cmds @ [ Attack (x, y) ] | None -> cmds
  else cmds

let light_rush : bot = rush_bot Light 3 3
let heavy_rush : bot = rush_bot Heavy 2 2
let ranged_rush : bot = rush_bot Ranged 3 3

let economy_boom : bot = fun v ->
  if v.v_turn < 120 then
    [ Harvest_with 4; Train (Worker, 2);
      (if has_barracks v then Train (Light, 1) else Build_barracks); Defend ]
  else
    Harvest_with 3 :: Train (Heavy, 2)
    :: attack_or_defend v (count_of v Heavy + count_of v Light >= 4)

let turtle : bot = fun v ->
  [ Harvest_with 3;
    (if has_barracks v then Train (Ranged, 2) else Build_barracks);
    Defend ]

let balanced : bot = fun v ->
  let army = count_of v Light + count_of v Heavy + count_of v Ranged in
  Harvest_with 3
  :: (if has_barracks v then Train ((if army land 1 = 0 then Light else Ranged), 2)
      else Build_barracks)
  :: attack_or_defend v (army >= 4)

(** Deterministic pseudo-random bot: seeded, so games stay reproducible. *)
let random_bot seed : bot =
  let state = ref seed in
  let next () = state := ((!state * 1103515245) + 12345) land 0x3FFFFFFF; !state in
  fun v ->
    let r n = next () mod n in
    let cmds = [ Harvest_with (1 + r 3) ] in
    let cmds = if r 10 < 3 then cmds @ [ Build_barracks ] else cmds in
    let t = match r 4 with 0 -> Worker | 1 -> Light | 2 -> Heavy | _ -> Ranged in
    let cmds = cmds @ [ Train (t, 1) ] in
    if r 10 < 4 then
      match v.enemy_units with
      | [] -> cmds @ [ Defend ]
      | l -> let e = List.nth l (r (List.length l)) in cmds @ [ Attack (e.x, e.y) ]
    else cmds @ [ Defend ]

let bots : (string * bot) list =
  [ "worker-rush", worker_rush;
    "light-rush", light_rush;
    "heavy-rush", heavy_rush;
    "ranged-rush", ranged_rush;
    "economy-boom", economy_boom;
    "turtle", turtle;
    "balanced", balanced;
    "random", random_bot 42 ]

let bot_named name = List.assoc_opt name bots
let bot_names () = List.map fst bots

(* ------------------------------------------------------------------ *)
(* 9. Running a match                                                 *)
(* ------------------------------------------------------------------ *)

type result = {
  winner : int;                          (** 0, 1, or -1 for a draw *)
  turns : int;
  final_reason : string;
  final : game;
}

(** Play one match. Bots are consulted on turn 0 and every [interval] ticks —
    the same cadence as the JavaScript runner's default. *)
let play ?(size = 16) ?(max_turns = 500) ?(preset = "default") ?(interval = 20)
    ?(on_tick = fun _ _ -> ()) (p0 : bot) (p1 : bot) =
  let rec loop g since =
    if g.over then g
    else
      let consult = g.turn = 0 || since >= interval in
      let g =
        if not consult then g
        else
          let g = apply_orders g 0 (p0 (view g 0)) in
          apply_orders g 1 (p1 (view g 1))
      in
      let g, evs = step g in
      on_tick g evs;
      loop g (if consult then 1 else since + 1)
  in
  let final = loop (make_game ~size ~max_turns ~preset ()) 0 in
  { winner = final.winner; turns = final.turn;
    final_reason = final.reason; final }
