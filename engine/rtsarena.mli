(** RTSArena — the sealed engine. RTS-2.

    This interface is given: your job is to make [rtsarena.ml] match it,
    not to change it. Everyone's engine implements exactly this, so any
    engine can be swapped for any other — which is how RTS-3's tournament
    runs every bot on one reference engine.

    The one decision that matters: [game] is {b abstract}. Nothing outside
    this module can see how a game is represented, and nothing here hands
    out anything mutable. That is what makes a game a value you can share,
    fork, and simulate without a copy. *)

(** {1 Units and buildings} *)

type unit_type = Worker | Light | Heavy | Ranged
type building_type = Base | Barracks
type kind = U of unit_type | B of building_type

type stats = {
  hp : int;
  cost : int;
  build_ticks : int;
  speed : int;
  damage : int;
  range : int;
}

val unit_stats : unit_type -> stats
val building_stats : building_type -> stats
val stats_of_kind : kind -> stats
val string_of_unit_type : unit_type -> string
val string_of_building_type : building_type -> string
val string_of_kind : kind -> string
val unit_type_of_string : string -> unit_type option

(** {1 Entities}

    Entities stay concrete: they are immutable records, so there is nothing
    to protect. A bot may read every field. *)

type action =
  | Harvest of (int * int) option
  | Attack_at of int * int
  | Move_to of int * int
  | Building_it of { btype : building_type; bx : int; by : int; progress : int }

type entity = {
  id : int;
  kind : kind;
  player : int;
  x : int;
  y : int;
  hp : int;
  max_hp : int;
  damage : int;
  range : int;
  speed : int;
  carrying : int;
  action : action option;
  producing : (unit_type * int) option;
}

val is_building : entity -> bool
val is_worker : entity -> bool
val make_entity : int -> kind -> int -> int -> int -> entity
val dist : entity -> entity -> int
val dist_xy : int -> int -> int -> int -> int

(** {1 The game} *)

type cell = Empty | Resource | Wall

type game
(** Abstract. Read it through the functions below. *)

type event =
  | Produced of { player : int; what : unit_type; x : int; y : int }
  | Deposited of { player : int; amount : int }
  | Harvested of { player : int; x : int; y : int }
  | Combat of { attacker : int; target : int; damage : int }
  | Built of { player : int; what : building_type; x : int; y : int }
  | Destroyed of { player : int; what : kind }

val make_game : ?size:int -> ?max_turns:int -> ?preset:string -> unit -> game

(** Rebuild a game from what the JSON protocol sends ([bin/rts_bot.ml]).
    [terrain] and [amounts] are rows, [terrain.(y).(x)]; the arrays are
    copied, so changing them afterwards does not change the game. *)
val of_snapshot :
  size:int -> max_turns:int -> turn:int ->
  terrain:cell array array -> amounts:int array array ->
  resources:int * int -> entity list -> game

(** Reading a game. *)

val size : game -> int
val turn : game -> int
val max_turns : game -> int
val entities : game -> entity list
val resources_of : game -> int -> int
val cell_at : game -> int -> int -> cell
val has_resource : game -> int -> int -> bool
val resource_left : game -> int -> int -> int
val in_bounds : game -> int -> int -> bool
val occupied : ?except:int -> game -> int -> int -> bool
val entities_of : game -> ?kind:kind -> ?building:bool -> int -> entity list
val find_building : game -> int -> building_type -> entity option
val is_over : game -> bool
val winner : game -> int
val reason : game -> string

(** A new game, identical except for its entities. For tests and for
    building positions by hand. *)
val with_entities : game -> entity list -> game

(** Advance one tick. The argument is untouched — as it must be, since
    nothing can touch it. *)
val step : game -> game * event list

(** {1 Orders} *)

type order =
  | Harvest_with of int
  | Build_barracks
  | Train of unit_type * int
  | Attack of int * int
  | Defend
  | Retreat

val string_of_order : order -> string
val apply_orders : game -> int -> order list -> game

(** {1 What a player sees} *)

type view = {
  v_turn : int;
  v_max_turns : int;
  my_resources : int;
  enemy_resources : int;
  my_units : entity list;
  enemy_units : entity list;
  v_size : int;
  world : game;  (** the whole game — safe to hand out now that it is sealed *)
}

val view : game -> int -> view
val to_ascii : game -> int -> string

(** {1 Bots} *)

type bot = view -> order list

val has_barracks : view -> bool
val enemy_target : view -> (int * int) option
val count_of : view -> unit_type -> int
val attack_or_defend : view -> bool -> order list
val rush_bot : unit_type -> int -> int -> bot
val worker_rush : bot
val light_rush : bot
val heavy_rush : bot
val ranged_rush : bot
val economy_boom : bot
val turtle : bot
val balanced : bot

(** [random_bot seed]: the same seed must give the same game, every time
    it is played. *)
val random_bot : int -> bot

val bots : (string * bot) list
val bot_named : string -> bot option
val bot_names : unit -> string list

(** {1 Running games} *)

(** [fork v] is a game you may simulate freely: whatever you do to it, the
    real game is unaffected. *)
val fork : view -> game

(** [rollout g p0 p1 ~ticks] plays [ticks] more ticks from [g], consulting
    the bots every [interval] ticks starting now. It stops early if the game
    ends. *)
val rollout : ?interval:int -> game -> bot -> bot -> ticks:int -> game

type result = { winner : int; turns : int; final_reason : string; final : game }

val play :
  ?size:int -> ?max_turns:int -> ?preset:string -> ?interval:int ->
  ?on_tick:(game -> event list -> unit) -> bot -> bot -> result
