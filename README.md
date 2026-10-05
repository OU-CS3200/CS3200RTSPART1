# RTS-1 · Read the board

CS 3200, Fall 2026 · the first of three assignments on the OCaml
[RTSArena](https://github.com/OU-CS3200/cs3200/tree/main/OCaml/RTSArena) engine.
**You will keep working in this same repository for RTS-2 and RTS-3**, so set it
up properly once.

In RTS-1 you write functions **over** a real-time strategy game: questions about
the board, a number that says who is winning, and a bot built from small rules.
You do not change the engine. In RTS-2 you will; in RTS-3 your bot will use
this assignment's `eval` to look ahead.

## Getting your copy

Click **Use this template** (top right), set the owner to **OU-CS3200**, and set
the visibility to **Private**. Clone *your* repository, not this one.

When you are done, push, then download a zip of your repository (green **Code**
button → *Download ZIP*) and submit that zip on Canvas. Also tag the commit you
are submitting:

```
git tag rts1 && git push origin rts1
```

## Setting up

Same switch as PA1. If you did PA1 you already have everything:

```
opam install dune alcotest qcheck qcheck-alcotest
eval $(opam env)
dune build
```

The handout builds cleanly and most tests fail with `Todo` — that is expected.

## Playing with it

```
dune exec bin/main.exe -- list
dune exec bin/main.exe -- play light-rush turtle --show
dune exec bin/main.exe -- play my-bot balanced
dune exec bin/main.exe -- tournament --turns 400
```

`my-bot` is the bot in `student/bot.ml`. Read `engine/rtsarena.ml` sections 6–8
(orders, views, bots) before you start — about 150 lines, and everything you
need is there. The full rules are in the course repo's
[`OCaml/RTSArena/docs/index.html`](https://github.com/OU-CS3200/cs3200/tree/main/OCaml/RTSArena/docs).

**Do not edit anything in `engine/`.** The grader uses its own copy.

## What to do

All of your code goes in `student/`. Each file says what it wants at the top.

| Part | File | Points | What |
| :--- | :--- | ---: | :--- |
| A | `queries.ml` | 30 | Six questions about the board — map/filter/fold only, **no `rec`, no `List.length`** |
| B | `eval.ml` | 20 | Who is winning, as one number, built from weighted features |
| C1 | `rules.ml` | 15 | Six rule combinators |
| C2 | `bot.ml` | 25 | A bot assembled from those combinators — **no `if`, no `match` in `bot.ml`** |
| D | `README.md` | 10 | The questions below |

Points for Part A, Part B and C1 come from the tests (visible ones here, plus
hidden ones on other positions). The rule checks under `style` are all-or-nothing
for their part: a `rec` in `queries.ml` costs Part A's style points even if
every answer is right.

**Part C2 is graded by winning.** Every match is on the default 16×16 map,
500 turns, and you must win **as player 0 and as player 1**. A draw is not a win.

| Points | Beat, on both sides |
| ---: | :--- |
| 10 | worker-rush, random, turtle |
| +8 | economy-boom and balanced |
| +7 | at least two of light-rush, heavy-rush, ranged-rush |

The eval test `predicts the winner from turn 100` asks that the sign of your
`eval`, taken at turn 100, calls the winner of at least 80% of the decisive games
in the built-in round robin that last that long. The starting weights in
`eval.ml` get 77%; tuning them is part of Part B. The hidden tests ask the same
question on other maps, so weights that only fit this one map will lose points
there.

Run everything with `dune test`. The slow groups (the eval prediction and the
bot matches) take a few seconds each. To run one group:

```
dune exec test/test_rts1.exe -- test queries
dune exec test/test_rts1.exe -- test bot
```

## Part D — answer here (10 pts)

Write your answers in this file, under this heading, replacing the prompts.

1. Feature: army weight: 4.0
   Feature: economy weight: 0.1
   Feature: workers weight: 0.0
   Feature: hp weight: 0.1
   Feature: base weight: 4.0
   Feature: barracks weight: 0.1
   Prediction rate 83%.
   One game where confidently wrong at turn 100 is random (player 0) vs turtle (player 1). At turn 100, eval was at +18.8, but turle won at 175. It was wrong because eval counts how much army cost and total health. So the cost of the heavies and the health look a lot stronger than the rangers. But eval can't account for the rangers shoot from 4 tiles and can back off. Eval doesn't have enough information to know how rangers and heavy fight and just get a score stronger from their cost.

2. The impure bot is the "Random_bot". With two calls with the same arguments you get different results. Shown below:
utop # b v;;
- : order list =
[Harvest_with 3; Build_barracks; Train (Light, 1); Attack (13, 14)]
─( 16:28:52 )─< command 5 >───────────────────────────────────────────{ counter: 0 }─
utop # b v;;
- : order list = [Harvest_with 1; Train (Heavy, 1); Defend]

This is because it has a hidden counter called "state" that changed with each call. For it to change it would have to be something more like this: view -> int -> order list * int" so it takes in the counter and gives the new value with the order list directly with the counter. No changing the state behind the scenes. The bin/main.ml works around it by building a brand new random bot for each match. That way it starts from the same seed.

3. My bots orders are two workers gathering, builds a barrack first, then trains one heavy every round & a worker tell I have four workers. It attacks as soon as it has two soldiers. The extra workers I us as cheap fighters. My-bot beats all the built in bots, but I suspect on a bigger map my plan would fail. The ranged-rush would be able to take down my heavies.

## Collaboration and AI

As in the syllabus: talk about the problems, not your code, and only after you
have started; list who you talked to here. Generative AI tools are allowed.
If you use one, say here which one, what for, and which parts of your
submission it shaped. Every answer in Part D has to be about **your own**
results — the numbers and the games you found.

## README (collaboration / AI use)

Jt Hepke, jh639423, I talked to nobody, And I used Chatgpt to help me understand the project and little pieces of ocaml basics. Claude helped me with bits and peices in eval and helped me tune my weights to get my percentage above 80.
