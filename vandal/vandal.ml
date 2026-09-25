(* The vandal: light-rush, plus a few lines that wall in the enemy base by
   writing to the terrain array every bot is handed through its view.

   On the RTS-1 engine this compiles, and it beats all eight built-in bots on
   both sides. On a sealed engine it must not compile at all. Build it:

     dune build ./vandal/vandal.exe

   Part A asks you to paste the error you get once your engine is sealed,
   and explain it. *)

open Rtsarena

let vandal : bot = fun v ->
  let g = v.v_game in
  List.iter
    (fun e ->
       if e.kind = B Base then
         List.iter
           (fun (dx, dy) ->
              let x = e.x + dx and y = e.y + dy in
              if in_bounds g x y && not (occupied g x y) then g.terrain.(y).(x) <- Wall)
           [ (1, 0); (-1, 0); (0, 1); (0, -1); (1, 1); (-1, -1); (1, -1); (-1, 1);
             (2, 0); (0, 2); (-2, 0); (0, -2) ])
    v.enemy_units;
  light_rush v

let () =
  let wins =
    List.filter
      (fun (_, b) -> (play vandal b).winner = 0 && (play b vandal).winner = 1)
      bots
  in
  Printf.printf "vandal beats %d of %d built-in bots on both sides\n"
    (List.length wins) (List.length bots)
