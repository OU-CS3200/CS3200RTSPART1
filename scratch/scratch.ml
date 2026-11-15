open Rtsarena
open Search

let players : (string * (unit -> bot)) list =
  [ ("basic", fun () -> Search_bot.make ());
    ("pro100", fun () -> Search_bot.make_pro ());
    ("pro150", fun () -> Search_bot.make_pro ~ticks:150 ());
    ("pro200", fun () -> Search_bot.make_pro ~ticks:200 ()) ]

let presets = [ "default"; "rich"; "corridors"; "sparse" ]

let () =
  List.iter (fun (an, a) ->
      let total = ref 0 and games = ref 0 in
      List.iter (fun (bn, b) ->
          if an <> bn then begin
            let w = ref 0 in
            List.iter (fun preset ->
                if (play ~preset (a ()) (b ())).winner = 0 then incr w;
                if (play ~preset (b ()) (a ())).winner = 1 then incr w) presets;
            Printf.printf "%-7s vs %-7s : %d / 8\n%!" an bn !w;
            total := !total + !w;
            games := !games + 8
          end) players;
      Printf.printf "== %-7s total %d / %d\n%!" an !total !games) players

      