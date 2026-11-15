(************************************************************************
   RTS-3, Part B — Memoize the rollouts (30 pts, with bin/bench.ml and RTS3.md)

   A search bot spends nearly all its time in [rollout]: from a position,
   play [ticks] ticks of two bots against each other. Many of those
   rollouts overlap. Two candidate plans often give the SAME orders for the
   first 20 ticks, and the plan you picked last time usually predicted the
   position you are now in. So cache the work.

   The unit of caching is one CHUNK: both sides give orders, then [len]
   ticks pass. That is exactly what the engine's [rollout] does between two
   consultations. A chunk is a function of

       (its length, the position, player 0's orders, player 1's orders)

   so its result can be cached under a key built from those four.
   Getting the KEY right is the whole of this part.
 ************************************************************************)

open Rtsarena
[@@@warning "-26-27-32"]


(** Counters for the bench: every chunk is a hit or a miss. Given. *)
type stats = { mutable hits : int; mutable misses : int }

let stats = { hits = 0; misses = 0 }

(** One chunk: both sides issue orders, then [len] ticks pass (fewer if the
    game ends first). Given. *)
let chunk ~(len : int) (g : game) (o0 : order list) (o1 : order list) : game =
  let g = apply_orders (apply_orders g 0 o0) 1 o1 in
  let rec go (g : game) (n : int) : game =
    if n = 0 || is_over g then g else go (fst (step g)) (n - 1) in
  go g len

(** 1. (10 pts) [key ~len g o0 o1] names a chunk. Two chunks with the same
    key MUST produce the same result, or the cache will hand back wrong
    games — and nothing will crash to tell you.

    Think about everything that decides what [chunk] returns. All of it has
    to be in the key. What about the turn? What about things the engine
    keeps that you cannot observe through its functions at all?

    Hint: [Marshal.to_string] turns any value into a string, and sees
    through abstract types. [Digest.string] makes a string short. *)
let key ~(len : int) (g : game) (o0 : order list) (o1 : order list) : string =
  Digest.string (Marshal.to_string (len, g, o0, o1) [])

(** 2. (10 pts) [rollout_chunks ?cache ~interval g p0 p1 ~ticks] must give
    the same game as [rollout ~interval g p0 p1 ~ticks] — the tests check
    that — but is built out of chunks: at each consultation, ask both bots
    for their orders, then run one chunk, from the cache when you can.

    - No [cache]: every chunk is computed, and counts as a miss.
    - With a [cache]: look the chunk up by [key]. On a hit use the stored
      game ([stats.hits]); on a miss compute it, store it, count it.
    - The last chunk may be shorter than [interval]: stop at exactly
      [ticks] ticks from where you started.
    - Count chunks rather than trusting [turn] to end the loop. A wrong key
      can hand back a game from an EARLIER turn, and a loop that waits for
      the turn to reach its target then never ends. *)
let rollout_chunks ?(cache : (string, game) Hashtbl.t option) ~(interval : int) (g : game)
    (p0 : bot) (p1 : bot) ~(ticks : int) : game =
  let rec go (g : game) (left : int) : game =
    if left <= 0 || is_over g then g
    else begin
      let len = min interval left in
      let o0 = p0 (view g 0) in
      let o1 = p1 (view g 1) in
      let next =
        match cache with
        | None ->
          stats.misses <- stats.misses + 1;
          chunk ~len g o0 o1
        | Some tbl ->
          let k = key ~len g o0 o1 in
          (match Hashtbl.find_opt tbl k with
           | Some g' -> stats.hits <- stats.hits + 1; g'
           | None ->
             stats.misses <- stats.misses + 1;
             let g' = chunk ~len g o0 o1 in
             Hashtbl.replace tbl k g';
             g')
      in
      go next (left - len)
    end
  in
  go g ticks
