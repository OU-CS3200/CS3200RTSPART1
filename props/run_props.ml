(* Runs every property in properties.ml. Given. *)
let () = exit (QCheck_base_runner.run_tests ~verbose:true Props.Properties.all)
