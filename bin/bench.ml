(* RTS-3 Part B: the table for RTS3.md. Given.

     dune exec bin/bench.exe

   Plays your search bot, with and without its cache, at three rollout
   lengths, against your RTS-1 bot and the three rushes on the default map,
   both sides. Paste the table into RTS3.md. *)

open Rtsarena
open Search

let opponents = [ ("my-bot", Bot.my_bot); ("light-rush", light_rush);
                  ("heavy-rush", heavy_rush); ("ranged-rush", ranged_rush) ]

let row ~(ticks : int) ~(cache : bool) : unit =
  Memo.stats.hits <- 0;
  Memo.stats.misses <- 0;
  let consults = ref 0 and seconds = ref 0.0 and wins = ref 0 in
  let timed (b : bot) : bot = fun (v : view) ->
    let t0 = Unix.gettimeofday () in
    let o = b v in
    seconds := !seconds +. (Unix.gettimeofday () -. t0);
    incr consults;
    o
  in
  List.iter
    (fun ((_, opp) : string * bot) ->
       if (play (timed (Search_bot.make ~ticks ~cache ())) opp).winner = 0 then incr wins;
       if (play opp (timed (Search_bot.make ~ticks ~cache ()))).winner = 1 then incr wins)
    opponents;
  let h = Memo.stats.hits and m = Memo.stats.misses in
  Printf.printf "| %3d | %-5s | %8.1f | %7s | %d / %d |\n%!" ticks
    (if cache then "on" else "off")
    (1000.0 *. !seconds /. float_of_int (max 1 !consults))
    (if cache then Printf.sprintf "%.1f%%" (100.0 *. float_of_int h /. float_of_int (max 1 (h + m)))
     else "—")
    !wins (2 * List.length opponents)

let () =
  print_endline "| ticks | cache | ms / consultation | hit rate | wins |";
  print_endline "| ---: | :--- | ---: | ---: | ---: |";
  List.iter (fun (ticks : int) -> row ~ticks ~cache:false; row ~ticks ~cache:true) [ 20; 50; 100 ]
