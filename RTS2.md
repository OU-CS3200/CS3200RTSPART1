# RTS-2 · Seal the engine

CS 3200, Fall 2026 · Chapters 5 (modules) and 6 (mutability). The second of
three assignments on RTSArena, in **the same repository** as RTS-1.

In RTS-1 you wrote functions over the engine. Now you own it. The engine says
it is pure — *"every tick produces a new game; nothing is assigned to"* — and
it is almost true. This assignment is about the places where it is not.

Exhibit A is `vandal/vandal.ml`, which arrives with this assignment. It is
light-rush plus five lines that write walls into the terrain array its view
hands it. Against the RTS-1 engine it **beats all eight built-in bots, on both
sides**. By the end of RTS-2 it will not compile.

## Getting RTS-2 into your repository

Your RTS-1 work stays where it is. RTS-2 arrives as a branch of the template;
merge it in once:

```
git remote add template https://github.com/OU-CS3200/ou-cs3200-fall-2026-rts.git
git fetch template
git merge template/rts2
```

The merge only adds or replaces files you were told not to edit (`engine/`,
`bin/`, `test/`) and adds new ones. `student/` and `README.md` are untouched, so
it should merge cleanly. If git reports a conflict, you edited something in
`engine/`, `bin/` or `test/` — keep the template's version.

**After the merge, `dune build` fails. That is the assignment.** There is a new
file, `engine/rtsarena.mli`, and the engine does not match it yet. The compiler
errors are your to-do list for Part A.

## What to do

| Part | Where | Points | What |
| :--- | :--- | ---: | :--- |
| A | `engine/`, `bin/` | 30 | Make the engine match the given interface — the seal |
| B | `engine/`, `fixes/test_fixes.ml` | 40 | Four fixes, each with a test committed **before** the fix |
| C | `props/properties.ml` | 20 | Five QCheck properties, graded against engines with planted bugs |
| D | this file | 10 | The questions at the end |

In RTS-2 you may edit `engine/` and `bin/`. Do **not** edit
`engine/rtsarena.mli`, `test/`, `props/gen.ml` or `props/run_props.ml`: the
grader replaces them with its own copies.

### Part A — The seal (30 pts)

`engine/rtsarena.mli` is given. Make `engine/rtsarena.ml` implement it, then
make everything else build again.

- `game` is **abstract**. Everything outside the engine reads a game through
  functions: `turn`, `entities`, `resources_of`, `cell_at`, and so on. The
  interface lists them all; implement each one.
- A `view` no longer has a `v_game` field. It has `world : game`, which is
  safe to hand out *only because* nothing outside the engine can change a
  `game`. Think about why that is true once `game` is abstract — and make
  sure it is: no function may hand out anything mutable from inside a game.
- `fork`, `rollout` and `of_snapshot` are new. Their comments in the `.mli`
  say what they must do.
- `bin/rts_bot.ml` built a game record by hand from the JSON. It can't any
  more; use `of_snapshot`. `bin/main.ml` needs small changes.
- **Your RTS-1 code in `student/` must compile without any change.** If it
  doesn't, your engine does not match the interface.

**Getting started.** Abstract does not mean "no record". Keep
`type game = { ... }` in `rtsarena.ml` as it is: the `.mli` hides its fields
from everything outside the engine, and inside the engine you still write
`g.turn`. What you add are the accessors the `.mli` lists, most of them one
line:

```ocaml
let turn g = g.turn
```

Only `game` is hidden. `entity`, `view` and `stats` are still spelled out in
the `.mli`, so `v.my_units` and `e.hp` work everywhere — which is why
`student/` compiles unchanged. Those types must match the `.mli` exactly:
`view`'s `v_game` field is now `world`. Then build, and work down the errors.

When `dune build` is clean, try the vandal:

```
dune build ./vandal/vandal.exe
```

It must fail to compile. Paste the error in Part D.

### Part B — Four fixes, test first (40 pts, 10 each)

For each flaw: write the test in `fixes/test_fixes.ml` and **commit it while it
fails**, then fix the engine and commit again. We read `git log`: a fix whose
failing test did not come first loses half its points. Each test's comment
says exactly what it must check. Run them with `dune test fixes`.

1. **The seal.** Simulating a fork must leave the original untouched, and
   `of_snapshot` must copy the arrays it is given.
2. **Fairness.** The engine resolves one entity at a time, so whoever comes
   first in the entity list can kill a unit before it hits back. Make combat
   **simultaneous**: every attack in a tick is chosen from the state at the
   *start* of the tick, and all damage lands together at the end. A unit that
   dies this tick still gets its shot. Two units that can kill each other in
   one blow must both die, whichever is listed first.
3. **Honest randomness.** `random_bot 42` returns one function with a hidden
   `ref` inside, so a bot *value* remembers every game it has played. The same
   bot value must play the same game every time. Keep the type
   `int -> bot` — the fix is in how the randomness is derived.
4. **Legal positions.** No unit may stand on a wall, and no two entities may
   share a cell. The kiting code breaks this. **It is not the only thing that
   does** — your test will tell you when you have found the other one.

Our own hidden tests ask the same four questions on other units, seeds and maps.

### Part C — Properties (20 pts)

In `props/properties.ml`, write five QCheck properties: determinism, purity,
conservation of resources, legal positions, and one of your own. `props/gen.ml`
gives you random games that the engine could really reach, and `snapshot` for
comparing them. Run them with `dune test props`.

**How this is graded:** we run *your* properties against three engines, each
with one bug planted in it. You get the 20 points if your properties pass on a
correct engine and fail on at least **two of the three** buggy ones. You will not
see the buggy engines. Think about what could go wrong in `step`, and check for
it — a property that only restates your own fix will not catch much.

### What still runs

`dune test test` runs the RTS-1 tests against your sealed engine. They are not
graded again, but they must still *compile* — that is part of Part A. Your
bot's results may change: fixing fairness changes who wins some fights.

## Part D — answer here (10 pts)

1. **(3 pts) The vandal's error.** Paste the compiler's error from building
   `vandal/vandal.ml` against your engine. Explain it in your own words: which
   line of the `.mli` makes it impossible, and why is that a stronger
   guarantee than a comment saying "do not modify the terrain"?

   File "vandal/vandal.ml", line 15, characters 12-18:
15 |   let g = v.v_game in
                 ^^^^^^
Error: This expression has type view
       There is no field v_game within type view

2. **(3 pts) What had to change.** Which files outside `engine/` did you have
   to change to make the build pass? Your `student/` code did not change —
   what did the `.mli` promise that made that true?

3. **(2 pts) `fork`.** In the reference engine, `fork v` is just `v.world`,
   with no copy. Why is that safe now, when copying a game in the RTS-1 engine
   would not have been enough?

4. **(2 pts) Your fifth property.** Name it, and say what bug it would catch
   that the other four would not.

## Collaboration and AI

Same as RTS-1: document who you talked to, and which AI tools you used for
what, under the heading below.

## README (collaboration / AI use)

*Who you talked to, and what AI tools you used for what.*

## Submitting

Commit and push everything, then tag it and upload the zip on Canvas:

```
git tag rts2 && git push origin rts2
```
