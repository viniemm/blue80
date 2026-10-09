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
records (peak chips, touchdowns, hands won, best hand) and settings (CRT scanlines, shoe counter, fullscreen, also `F11`)
persist in `user://blue80.cfg`. `godot --path godot res://scenes/quant.tscn` jumps straight into a run.

## How the card-betting game plays

Each down:
1. **Deal.** You and the defense each get 5 cards from a persistent 4-deck shoe (208 cards, reshuffled only when it runs low). There are 52 distinct plays: suit is the play
   family (RUN, RPO, PASS, SHOT) and rank sets its tier (2-6 bronze, 7-10 silver, J/Q/K gold, A platinum), with
   better expected yards but more variance at higher ranks.
2. **Draw.** Tap up to 3 cards to swap. The AI draws too. Two of the defense's final cards flip face-up.
3. **Bet.** The best poker combination's lead card is your play. Pick one of five lines (CHECKDOWN, SHORT, MEDIUM,
   LONG, HAIL MARY), priced at roughly 90 / 75 / 50 / 25 / 10% for that card, and a stake. Your hand's multiplier
   (pair x1.1 up to straight flush x8 and five of a kind x12) multiplies a winning bet's payout.
   Two **jokers** (PHILLY SPECIAL, FLEA FLICKER) ride in every deck as wild cards: they stand in for any card when
   you build a hand, and you may run one as a swingy trick play. After the draw, every card in your made hand (a pair
   gives 2, trips 3, two pair 4, straight/flush/full house 5, high card 1) may be chosen as the play: tap a gold-edged
   card or press `P`. Each card shows a `+` strength and a `-` weakness (the defense styles it beats and loses to);
   tap the (i) badge on a card (or hold it, or right-click) for its formation, routes and yards by defense. Ante is the forced one-chip hand
   stake (won or lost times the hand multipliers); the optional bet only plays on a won hand; `NO BET` is ante only.
4. **Showdown.** A versus banner pits your hand against the defense's and stamps YOU WIN, DEFENSE WINS or PUSH.
   Win the hand and your play spins on an outcome wheel (wedges sized by the play's real odds, a gold
   tick marking your bet line), then runs: yards come from the card's curve, bent by the defense's hidden
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
  data/       plays.json (52 play cards + 2 jokers: formations, routes, summaries, strength and weakness); older prototype JSON
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
godot --headless --path godot -s tests/qgame_test.gd -- 5000 0.5   # snaps per policy and the bet-multiplier share: edge by strategy (hand strength, read, choice, peek)
godot --headless --path godot -s tests/fit_check.gd    # bronze plays vs real football per-play averages, by tier and family
godot --headless --path godot -s tests/card_ev.gd      # expected yards per card and blind vs informed bet EV
godot --path godot --resolution 540x960 -s tests/qshot.gd -- <out_dir>   # plays one down through the UI, screenshots each phase
godot --path godot --resolution 540x960 -s tests/anim_shots.gd -- <out_dir>   # one down mid-animation: deal, lift, redeal, flips, verdict
godot --path godot --resolution 540x960 -s tests/cards_shots.gd -- <out_dir>   # joker hand, play choice and the card info popup
godot --path godot --resolution 540x960 -s tests/showdown_shots.gd -- <out_dir>   # wheel spin, field animation and the result panel
godot --path godot --resolution 540x960 -s tests/menu_shots.gd -- <out_dir>   # splash, every menu page and the pause overlay
godot --path godot --resolution 540x960 -s tests/make_icon.gd   # redraws godot/icon.png
godot --path godot --resolution 540x960 -s tests/qgallery.gd -- <out_dir>   # renders every card tier in every suit for a visual check
```

`godot/scripts/quant/` holds the card-betting game: `deck52` (52 plays from a few curve constants each plus the two
jokers, with the play info in `data/plays.json`), `yard_curve` (closed-form yardage distribution), `poker`, `lines` (the five yardage lines) and
`def_context` (hidden defense styles). It now powers the playable game via `qgame.gd` and `ui/qmain.gd`.

Run `godot --headless --path godot --import` once after adding new `class_name` scripts.
