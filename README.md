# Blue 80

A pixel-art football game built in Godot 4, now a quantitative card game: win poker hands to run football plays, and
bet on how many yards each play gains. Edge comes from math: hand equity, reading the defense from partial
information, and sizing bets.

## Run

Requires Godot 4.7 (`winget install GodotEngine.GodotEngine`).

```powershell
godot --path godot                          # play the card-betting game
godot -e --path godot                       # open the editor
godot --path godot res://scenes/main.tscn   # the earlier card-drive prototype (play-card combos and jokers)
```

## How the card-betting game plays

Each down:
1. **Deal.** You and the defense each get 5 cards from a persistent 4-deck shoe (208 cards, reshuffled only when it runs low). There are 52 distinct plays: suit is the play
   family (RUN, RPO, PASS, SHOT) and rank sets its tier (2-6 bronze, 7-10 silver, J/Q/K gold, A platinum), with
   better expected yards but more variance at higher ranks.
2. **Draw.** Tap up to 3 cards to swap. The AI draws too. Two of the defense's final cards flip face-up.
3. **Bet.** The best poker combination's lead card is your play. Pick one of five lines (CHECKDOWN, SHORT, MEDIUM,
   LONG, HAIL MARY), priced at roughly 90 / 75 / 50 / 25 / 10% for that card, and a stake. Your hand's multiplier
   (pair x1.1 up to straight flush x8 and five of a kind x12) multiplies a winning bet's payout.
4. **Showdown.** Win the hand and your play runs: yards come from the card's curve, bent by the defense's hidden
   style (the suit of its lead card: BLITZ, ZONE, MAN or BALANCED), and the bet settles on those yards. Lose the hand
   and the bet is refunded, but the defense's hand decides the damage (a stuff, loss, sack, fumble or pick six).

The house prices each card's own curve averaged over all defense styles, so an uninformed bettor has no edge. The
edge is reading the two face-up cards (what the defense's lead suit probably is), sizing by hand strength, and tracking the
shoe: the strip under the tells shows copies left by rank, so a rank-rich shoe means more pairs and trips for both hands.
Controls: tap cards, line rows and buttons. Desktop shortcuts: `1`-`5` (select a card or line), `Enter` (advance).

**Live editing:** open the editor (`godot -e --path godot`), press `F5` to run, and keep **Debug > Synchronize Script
Changes** ticked. Edited `.gd` files then reload inside the running game, so drawing and game logic changes show up
immediately. Layout built in `main.gd`'s `_build_ui()` only runs at startup, so after changing positions just stop and
press `F5` again (about a second). Text uses `canvas_items` stretching, so it stays sharp at any window size.

## How the earlier card-drive prototype plays (main.tscn)

- **Deck and hand:** a deck of 12 play cards, dealt 5 at a time. Each card has a suit (play family: RUN, QUICK, MID,
  DEEP, PA, SCREEN) and a rank (how aggressive the call is).
- **Combos** read the last two plays plus the card you are about to play: PAIR, TRIPS, STRAIGHT, BUILD-UP, RUN FAKE.
  Each one visibly reshapes the wheel.
- **Jokers:** three passive modifiers per run (less pressure, deeper routes, fewer fumbles, sharper defense curve...).
- **Defense:** 10 defensive plays in 5 aggression tiers (deep shell to all-out). The defense picks from a probability
  curve that moves with down, distance, field position and what it has seen you do. The curve is shown before the snap.
- **Outcome wheel:** a continuous disaster-to-jackpot gradient sized by Monte Carlo odds for your card against the
  defense mix. The real simulation result decides where the pointer lands.

## Layout

```
godot/
  data/       rosters, 20 offensive plays, 10 defensive plays, scheme matrix (JSON)
  scripts/
    engine/   mathx, sim (pocket, routes, resolvers, yardage, rules), evaluator, game_data
    game/     cards (deck, combos, jokers), defense_curve, drive
    quant/    card-betting game: deck52, yard_curve, poker, lines, def_context, qgame
    ui/       qmain + qcard_view (betting game); main, wheel_view, card_view (earlier prototype); field_view, px
  assets/     VT323 + Press Start 2P fonts (SIL OFL), wheel shader
  tests/      headless calibration and drive tests, UI autoplay with screenshots
docs/DEVELOPMENT_PLAN.md   the math specification behind the simulation
```

## Tests

```powershell
godot --headless --path godot -s tests/calib.gd        # engine calibration (mean yards, completion, sack rates)
godot --headless --path godot -s tests/drive_test.gd   # 300 random drives: rules and scoring smoke test
godot --path godot -s tests/autoplay.gd -- <out_dir>   # plays a drive through the UI and screenshots it
godot --path godot -s tests/discard_test.gd -- <out_dir>
godot --headless --path godot -s tests/quant_lab.gd    # math lab: pricing, edges, value of information (about 3 minutes)
godot --headless --path godot -s tests/qgame_test.gd    # plays 12k snaps per betting policy through the real game rules
godot --path godot --resolution 540x960 -s tests/qshot.gd -- <out_dir>   # plays one down through the UI, screenshots each phase
godot --path godot --resolution 540x960 -s tests/qgallery.gd -- <out_dir>   # renders every card tier in every suit for a visual check
```

`godot/scripts/quant/` holds the prototype for the card-betting redesign: `deck52` (52 plays from a few curve
constants each), `yard_curve` (closed-form yardage distribution), `poker`, `lines` (the five yardage lines) and
`def_context` (hidden defense styles). It now powers the playable game via `qgame.gd` and `ui/qmain.gd`.

Run `godot --headless --path godot --import` once after adding new `class_name` scripts.
