# Blue 80

A pixel-art football roguelike built in Godot 4. You are the offensive coordinator: build a hand of play cards, chain
poker-style combos, and spin an outcome wheel that you can reshape before the snap.

## Run

Requires Godot 4.7 (`winget install GodotEngine.GodotEngine`).

```powershell
godot --path godot          # play
godot -e --path godot       # open the editor
```

Controls: tap a card to select it, **SNAP** to run it, **DISCARD** to swap up to 3 cards (2 per drive), **FG** / **PUNT**
on 4th down. Desktop shortcuts: `1`-`5` select, `Enter` snap, `D` discard.

## How it plays

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
    ui/       main, field_view, wheel_view, card_view, px helpers
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
```

Run `godot --headless --path godot --import` once after adding new `class_name` scripts.
