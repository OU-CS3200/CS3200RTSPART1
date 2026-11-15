(* RTS-3 tests. Run with:  dune test test
   One group:               dune exec test/test_rts3.exe -- test memo *)

open Alcotest
open Rtsarena
open Search

let snap g = (List.sort compare (entities g), resources_of g 0, resources_of g 1, turn g, to_ascii g 0)
let fresh n = if n = "random" then random_bot 42 else Option.get (bot_named n)

(* a few real positions to start rollouts from *)
let positions =
  lazy
    (List.map
       (fun (preset, a, b, t) -> rollout (make_game ~preset ()) (fresh a) (fresh b) ~ticks:t)
       [ ("default", "balanced", "turtle", 0); ("rich", "heavy-rush", "economy-boom", 45);
         ("corridors", "ranged-rush", "light-rush", 90); ("sparse", "random", "balanced", 130);
         ("default", "worker-rush", "heavy-rush", 470) ])

(* ------------------------------------------------------------------ *)
(* Part B — memo                                                      *)
(* ------------------------------------------------------------------ *)

let test_chunks_equal_rollout () =
  List.iter
    (fun g ->
       List.iter
         (fun ticks ->
            let a = rollout g balanced light_rush ~ticks in
            let b = Memo.rollout_chunks ~interval:20 g balanced light_rush ~ticks in
            if snap a <> snap b then
              failf "from turn %d, %d ticks: chunked rollout differs from rollout" (turn g) ticks)
         [ 0; 7; 20; 50; 100 ])
    (Lazy.force positions)

let test_cache_is_transparent () =
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun g ->
       List.iter
         (fun ticks ->
            let truth = rollout g heavy_rush turtle ~ticks in
            (* twice: the second time comes from the cache *)
            for _ = 1 to 2 do
              let c = Memo.rollout_chunks ~cache:tbl ~interval:20 g heavy_rush turtle ~ticks in
              if snap c <> snap truth then
                failf "from turn %d, %d ticks: the cached rollout is wrong" (turn g) ticks
            done)
         [ 100; 50; 20; 30 ])
    (Lazy.force positions)

let test_cache_hits () =
  let tbl = Hashtbl.create 64 in
  let g = List.nth (Lazy.force positions) 1 in
  Memo.stats.hits <- 0;
  ignore (Memo.rollout_chunks ~cache:tbl ~interval:20 g balanced balanced ~ticks:60);
  ignore (Memo.rollout_chunks ~cache:tbl ~interval:20 g balanced balanced ~ticks:60);
  (check int) "the second rollout is three hits" 3 Memo.stats.hits

let test_key_sees () =
  let g = make_game () in
  let later = fst (step g) in
  (* nobody has orders: one tick later, every entity is exactly where it was *)
  (check bool) "same entities" true (List.sort compare (entities g) = List.sort compare (entities later));
  (check bool) "a different turn is a different key" false
    (Memo.key ~len:20 g [] [] = Memo.key ~len:20 later [] []);
  (check bool) "a different length is a different key" false
    (Memo.key ~len:20 g [] [] = Memo.key ~len:10 g [] []);
  (check bool) "different orders are a different key" false
    (Memo.key ~len:20 g [ Defend ] [] = Memo.key ~len:20 g [ Retreat ] [])

(* ------------------------------------------------------------------ *)
(* Part A — search                                                    *)
(* ------------------------------------------------------------------ *)

let test_candidates () =
  let names = List.map fst Policies.candidates in
  (check bool) "at least 6 plans" true (List.compare_length_with names 6 >= 0);
  (check bool) "distinct names" true (List.length (List.sort_uniq compare names) = List.length names);
  (check bool) "my-bot is one of them" true (List.mem "my-bot" names);
  List.iter (fun g -> List.iter (fun (_, p) -> ignore (p (view g 0)); ignore (p (view g 1)))
                Policies.candidates) (Lazy.force positions)

let test_transparent () =
  (* the cache must never change what the bot decides *)
  let warm = Search_bot.make () in
  List.iter
    (fun g ->
       List.iter
         (fun side ->
            let v = view g side in
            let a = warm v in
            let b = warm v in
            let c = Search_bot.make ~cache:false () v in
            if a <> b || a <> c then failf "turn %d side %d: the bot changed its mind" (turn g) side)
         [ 0; 1 ])
    (Lazy.force positions)

(* per-consultation time, over everything the tier tests play *)
let consults = ref 0 and seconds = ref 0.0 and worst = ref 0.0
let timed (b : bot) : bot =
 fun v ->
  let t0 = Unix.gettimeofday () in
  let o = b v in
  let dt = Unix.gettimeofday () -. t0 in
  incr consults; seconds := !seconds +. dt; worst := max !worst dt;
  o

let wins_vs opp presets =
  List.concat_map
    (fun preset ->
       let a = play ~preset (timed (Search_bot.make ())) opp in
       let b = play ~preset opp (timed (Search_bot.make ())) in
       [ a.winner = 0; b.winner = 1 ])
    presets
  |> List.filter Fun.id |> List.length

let test_beats_own_bot () =
  let w = wins_vs Bot.my_bot [ "default"; "rich"; "sparse"; "corridors" ] in
  if w < 6 then failf "won %d of 8 against your RTS-1 bot; need 6" w

let test_beats_rushes () =
  List.iter
    (fun n ->
       let w = wins_vs (fresh n) [ "default" ] in
       if w < 2 then failf "against %s: won %d of 2" n w)
    [ "light-rush"; "heavy-rush"; "ranged-rush" ]

let test_budget () =
  if !consults = 0 then fail "run the other bot tests first (they are what gets timed)";
  let mean = 1000.0 *. !seconds /. float_of_int !consults in
  Printf.printf "  %d consultations: mean %.1f ms, worst %.1f ms\n%!" !consults mean (1000.0 *. !worst);
  if mean > 100.0 then failf "mean %.1f ms per consultation; the budget is 100 ms" mean

let () =
  run "RTS-3"
    [ ( "memo",
        [ test_case "chunked rollout = rollout" `Quick test_chunks_equal_rollout;
          test_case "the cache never changes a result" `Quick test_cache_is_transparent;
          test_case "the cache hits" `Quick test_cache_hits;
          test_case "the key sees turn, length and orders" `Quick test_key_sees ] );
      ( "search",
        [ test_case "candidates" `Quick test_candidates;
          test_case "the cache never changes a decision" `Quick test_transparent;
          test_case "tier 1: beats your RTS-1 bot (6 of 8)" `Slow test_beats_own_bot;
          test_case "tier 2: beats the three rushes" `Slow test_beats_rushes;
          test_case "tier 3: 100 ms per consultation" `Slow test_budget ] ) ]
