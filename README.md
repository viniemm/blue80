# Blue 80

A pixel-art football card game built in Godot 4. Play the computer: win poker hands to run plays on offense or to
call coverages on defense, and a wheel decides how many yards are gained or lost. Edge comes from math: hand equity,
reading the other side from partial information, and counting a small shoe.

## Run

Requires Godot 4.7 (`winget install GodotEngine.GodotEngine`).

```powershell
godot --path godot                          # play the game
godot --path godot res://scenes/quant.tscn  # jump straight into a game, skipping the menus
godot -e --path godot                       # open the editor
```

## Web build for testers (no Apple fee)

iOS testers play the web build: open the link in Safari, tap Share, then **Add to Home Screen**, and it launches
full-screen like an app. `.github/workflows/deploy-web.yml` builds the Godot web export (single-threaded, so it needs no
special server headers) and publishes it to GitHub Pages on every push to `main`.

One-time setup: push the repo to GitHub, then in **Settings > Pages** set **Source** to **GitHub Actions**. The link is
`https://<user>.github.io/<repo>/`. To build locally instead, install the web export templates (Editor >
Manage Export Templates), then `cd godot` and run `godot --headless --export-release "Web" ../build/web/index.html` and
serve `build/web` with any static server. Records and settings are kept in the browser's storage on the device.
The home-screen icon is `godot/icon.png`, drawn by `tests/make_icon.gd`.

## Sound

All audio is synthesized, with no recorded samples: `godot --headless --path godot -s tests/make_audio.gd` renders 25 sound
effects and two chiptune music loops (menu and in-game) into `godot/assets/audio/`, then run `godot --headless --path godot --import`.
`Sfx.play("click")` and `Sfx.play_music("game")` (`scripts/audio/sfx.gd`) play them; Settings has SOUND EFFECTS and MUSIC toggles, and
the app mutes itself in the background. Per-sound loudness is the `LEVELS` table in the generator; master levels are `SFX_DB` and
`MUSIC_DB` in `sfx.gd`. On iOS the first tap (the splash screen) unlocks audio.

## Menus and flow

`scenes/app.tscn` is the entry point: an animated splash (any tap or key skips it) fades into the main menu (PLAY or
RESUME RUN, HOW TO PLAY, PAYTABLE, RECORDS, SETTINGS, QUIT; Up/Down/Enter or mouse). During a run, `MENU` or `Esc`
pauses with RESUME, RESTART RUN and MAIN MENU; a run left through the menu stays alive for RESUME RUN. Lifetime
records (best touchdowns and net yards, hands won, best hand) and settings (CRT scanlines, shoe counter, fullscreen, also `F11`)
persist in `user://blue80.cfg`. `godot --path godot res://scenes/quant.tscn` jumps straight into a run.

## How the card game plays

You play the computer. Drives alternate (3 each by default, four downs per drive) and each side's touchdowns are its score.
When you have the ball you pick the **play**; when the computer has it you are on **defense** and pick the **defensive call**.
Win poker hands to run football plays; a wheel decides how many yards are gained or lost. No chips, no points, no betting.

Every number below (decks, hand size, discards, face-up tells, reshuffle point, drives per side, the turnover gap) lives in
`godot/data/config.json` (read by `GameConfig`), so the rules can be changed without touching code.

Each down:
1. **Deal.** You and the computer each get 7 cards from a 1-deck shoe (52 plays plus 2 jokers; reshuffled when it runs low).
   Suit is the play family (RUN, RPO, PASS, SHOT) and rank sets its tier (2-6 bronze: white with red or black details,
   7-10 silver, J/Q/K gold, A platinum in a teal gem look), with better expected yards but more variance at higher ranks. The two
   **jokers** (PHILLY SPECIAL, FLEA FLICKER) are wild: they stand in for any card when you build a hand.
2. **Draw.** Tap up to 3 cards to swap. The computer draws too, and two of its cards flip face-up.
3. **Select.** Your hand is the best five of your seven cards. Nothing is preselected: tap one of the gold-edged cards
   yourself (a pair gives 2 choices, trips 3, straight/flush/full house 5, high card 1). **SNAP** in the middle of the wheel
   stays locked until you do, and the strip below the wheel shows what is being called.
   - **Offense:** the card is your play. Each card shows a `+` strength and a `-` weakness (the defense styles it beats and
     loses to); tap the (i) badge (or hold it, or right-click) for its formation, routes and yards by defense. The wheel previews
     the play's odds.
   - **Defense:** the suit of the card you call with is your style (RUN = BLITZ, RPO = ZONE, PASS = MAN, SHOT = BALANCED, joker =
     BALANCED). The computer's face-up cards show what it may run and what each fears.
4. **SNAP.** A versus banner pits the hands against each other and stamps YOU WIN, THEY WIN or PUSH. The offense wins when its
   hand beats the defense's, and then the wheel spins:
   - **Offense wins:** a gain wheel (positive yards only), times the offense's hand multiplier (pair x1.1 up to straight flush x8).
   - **Defense wins:** a loss wheel, times the defense's multiplier. If its hand is 5 or more classes higher it is a turnover with no spin.
   - Wedges are sized by the play's real odds, bent by the defensive style.

The skill is in the draw, in reading the face-up cards, in choosing the card that suits the situation, and in counting the small
shoe (the strip under the tells shows copies left by rank). Controls: tap cards and buttons. Desktop shortcuts: `1`-`7` (mark a
card while drawing, select one while choosing), `P` (cycle the selection), `Enter` (advance).

**Live editing:** open the editor (`godot -e --path godot`), press `F5` to run, and keep **Debug > Synchronize Script
Changes** ticked. Edited `.gd` files then reload inside the running game, so drawing and game logic changes show up
immediately. Layout built in `main.gd`'s `_build_ui()` only runs at startup, so after changing positions just stop and
press `F5` again (about a second). Text uses `canvas_items` stretching, so it stays sharp at any window size.

## Layout

```
godot/
  data/       config.json (decks, hand size, discards, drives...), plays.json (52 play cards + 2 jokers:
              formations, routes, summaries, strength and weakness)
  scripts/
    quant/    game rules: game_config, deck52, yard_curve, poker, def_context, qgame
    ui/       qmain (the game screen), qcard_view, wheel_view, field_view, versus_fx, card_detail, play_diagram,
              app + menu / help / paytable / records / settings screens, save, px helpers
    audio/    sfx (the static player for the generated sounds)
  assets/     VT323 + Press Start 2P fonts (SIL OFL), wheel shader, generated audio
  tests/      rules simulation, curve calibration, screenshot walkthroughs, asset generators
```

## Tests

```powershell
godot --headless --path godot -s tests/qgame_test.gd -- 300   # plays whole games vs the computer: touchdowns each, win rate, how drives end
godot --headless --path godot -s tests/fit_check.gd    # bronze plays vs real football per-play averages, by tier and family
godot --path godot --resolution 540x960 -s tests/qshot.gd -- <out_dir>   # plays one down through the UI, screenshots each phase
godot --path godot --resolution 540x960 -s tests/anim_shots.gd -- <out_dir>   # one down mid-animation: deal, lift, redeal, flips, verdict
godot --path godot --resolution 540x960 -s tests/cards_shots.gd -- <out_dir>   # joker hand, play choice and the card info popup
godot --path godot --resolution 540x960 -s tests/defense_shots.gd -- <out_dir>   # one down with the computer on offense
godot --path godot --resolution 540x960 -s tests/showdown_shots.gd -- <out_dir>   # wheel spin, field animation and the result panel
godot --path godot --resolution 540x960 -s tests/menu_shots.gd -- <out_dir>   # splash, every menu page and the pause overlay
godot --path godot --resolution 540x960 -s tests/make_icon.gd   # redraws godot/icon.png
godot --path godot --resolution 540x960 -s tests/qgallery.gd -- <out_dir>   # renders every card tier in every suit for a visual check
```

`godot/scripts/quant/` holds the game rules: `deck52` (52 plays from a few curve constants each plus the two
jokers, with the play info in `data/plays.json`), `yard_curve` (closed-form yardage distribution), `poker`, `def_context` (defensive styles), and `qgame` (possession, drives, the showdown and the wheel yards), which `ui/qmain.gd` presents.

Run `godot --headless --path godot --import` once after adding new `class_name` scripts.
