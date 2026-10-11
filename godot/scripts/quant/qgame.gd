class_name QGame
extends RefCounted
## A game against the computer: drives alternate (you on offense, then the computer, and so on) and each side's
## touchdowns are its score. Yardage is the only currency, and the wheel decides it.
##   DRAW   deal HAND_SIZE cards each, you discard up to MAX_DISCARDS
##   BET    the computer draws, FACE_UP of its cards flip face-up; you SELECT which card of your made hand to use
##          (offense: the play; defense: the defensive call, whose suit is the style), then SNAP
##   RESULT showdown. The offense wins when its hand beats the defense's: the wheel spins a gain (positive yards only)
##          times the offense's hand multiplier. Otherwise the wheel spins a loss times the DEFENSE's multiplier, and a
##          loss by PICK_SIX_GAP or more hand classes is a turnover with no spin.
## The defensive style (BLITZ / ZONE / MAN / BALANCED) is the suit of the defense's chosen card and bends the offense's
## curve. Cards come from a persistent shoe, reshuffled only when it runs low, so what has been dealt tells you
## something about what is left. Deck count, hand size and the rest live in data/config.json (see GameConfig).

const STYLE_OF_SUIT := ["BLITZ", "ZONE", "MAN", "BALANCED"]

static var DECKS: int = GameConfig.get_int("decks", 1)
static var HAND_SIZE: int = GameConfig.get_int("hand_size", 7)
static var MAX_DISCARDS: int = GameConfig.get_int("max_discards", 3)
static var FACE_UP: int = GameConfig.get_int("face_up", 2)
static var RESHUFFLE_AT: int = GameConfig.get_int("reshuffle_at", 20)    # reshuffle when fewer cards remain before a deal
static var DRIVES_PER_SIDE: int = GameConfig.get_int("drives_per_side", 3)
static var PICK_SIX_GAP: int = GameConfig.get_int("pick_six_gap", 4)    # lose the hand by this many classes: turnover
static var STYLE_STRENGTH: float = GameConfig.get_float("style_strength", 2.0)

var rng := RandomNumberGenerator.new()
var cards: Array                 # one deck: the 52 distinct plays plus the 2 jokers
var phase := "DRAW"              # DRAW -> BET -> RESULT -> (DRAW | OVER)
var shoe: Array = []
var shoe_pos := 0
var seen_id := {}                # card id -> copies the player has seen since the last shuffle
var shuffles := 0
var mine: Array = []
var theirs: Array = []
var _def_seen: Array = []        # which of the computer's cards the player has seen
var face_up: Array = []          # indices into `theirs` that are visible
var my_eval: Dictionary = {}
var their_eval: Dictionary = {}
var play_idx := -1               # the card YOU selected (-1 until you choose; you must pick before the snap)
var cpu_idx := -1                # the card the computer chose
var player_off := true           # true while you have the ball
var st := {}                     # down, distance, yardline_to_opponent_goal (distance to the goal being attacked)
var drive_no := 1
var tds := 0                     # your touchdowns
var cpu_tds := 0
var yards_total := 0             # your net yards on your own drives
var best_cat := -1               # best hand category won this game
var last: Dictionary = {}
var history: Array = []          # one record per snap, for analytics
var log: Array = []


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	DefContext.strength = STYLE_STRENGTH
	cards = Deck52.build_all()
	_shuffle_shoe()
	_new_drive()


static func total_drives() -> int:
	return DRIVES_PER_SIDE * 2


# ------------------------------------------------------------------ the shoe
func _shuffle_shoe() -> void:
	shoe = []
	for d in DECKS:
		shoe.append_array(cards)
	for i in range(shoe.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = shoe[i]
		shoe[i] = shoe[j]
		shoe[j] = t
	shoe_pos = 0
	seen_id = {}
	shuffles += 1
	if shuffles > 1:
		log.push_front("SHOE SHUFFLED")


func _take() -> Dictionary:
	var c: Dictionary = shoe[shoe_pos]
	shoe_pos += 1
	return c


func _see(c: Dictionary) -> void:
	seen_id[c.id] = int(seen_id.get(c.id, 0)) + 1


func shoe_left() -> int:
	return shoe.size() - shoe_pos


## Copies of this card the player has not seen (some may be in the computer's hidden cards).
func copies_left(card_id: int) -> int:
	return maxi(0, DECKS - int(seen_id.get(card_id, 0)))


func rank_left(rank: int) -> int:
	var n := 0
	for s in 4:
		n += copies_left(s * 13 + (rank - 2))
	return n


func wild_left() -> int:
	return copies_left(52) + copies_left(53)


# ------------------------------------------------------------------ setup
func _new_drive() -> void:
	st = {"down": 1, "distance": 10.0, "yardline_to_opponent_goal": 75.0, "period": 1, "clock_seconds": 900,
			"possession_team": "EAST" if player_off else "WEST"}
	_deal()


func _deal() -> void:
	if shoe_left() < maxi(RESHUFFLE_AT, 2 * (HAND_SIZE + MAX_DISCARDS)):
		_shuffle_shoe()
	mine = []
	theirs = []
	for i in HAND_SIZE:
		var c := _take()
		mine.append(c)
		_see(c)
	for i in HAND_SIZE:
		theirs.append(_take())
	_def_seen = []
	for i in HAND_SIZE:
		_def_seen.append(false)
	face_up = []
	my_eval = Poker.evaluate(mine)
	their_eval = {}
	play_idx = -1
	cpu_idx = -1
	phase = "DRAW"


# ------------------------------------------------------------------ the draw
## Discard the hand positions in `idx` (up to MAX_DISCARDS), the computer draws, FACE_UP of its cards flip face-up and
## it makes its own choice. You have nothing selected until you tap a card.
func draw(idx: Array) -> void:
	if phase != "DRAW":
		return
	for i in idx.slice(0, MAX_DISCARDS):
		var c := _take()
		mine[i] = c
		_see(c)
	for i in Poker.discards(theirs, MAX_DISCARDS):
		theirs[i] = _take()                      # the computer's discards and new cards stay unseen
	my_eval = Poker.evaluate(mine)
	their_eval = Poker.evaluate(theirs)
	play_idx = -1
	cpu_idx = _cpu_choose()
	var order: Array = range(HAND_SIZE)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	face_up = order.slice(0, FACE_UP)
	face_up.sort()
	for i in face_up:
		_def_seen[i] = true
		_see(theirs[i])
	phase = "BET"


## The computer's pick. On offense it runs the card with the best average yards over the four defense styles (it cannot
## see your call); on defense it simply calls with the lead card of its best hand.
func _cpu_choose() -> int:
	if player_off:
		return int(their_eval.lead_idx)
	var best: int = their_eval.lead_idx
	var best_v := -1e9
	for i in their_eval.eligible:
		var v := 0.0
		for style in DefContext.STYLES:
			v += YardCurve.mean(DefContext.apply(theirs[i].theta, style)) * 0.25
		if v > best_v:
			best_v = v
			best = int(i)
	return best


# ------------------------------------------------------------------ info for the UI
func has_selection() -> bool:
	return play_idx >= 0


## The card you selected, or an empty dictionary before you choose.
func my_lead() -> Dictionary:
	return mine[play_idx] if play_idx >= 0 else {}


## Hand positions you may select: every card in your best five, plus any joker.
func eligible() -> Array:
	return my_eval.eligible


func set_play(i: int) -> void:
	if phase == "BET" and my_eval.eligible.has(i):
		play_idx = i


func my_mult() -> float:
	return Poker.multiplier(int(my_eval.cat))


func style_of(card: Dictionary) -> String:
	return STYLE_OF_SUIT[card.suit] if card.suit < 4 else "WILD"


## The defensive style in play. Computer on defense: the suit of its lead card (hidden until the snap). You on defense:
## the suit of the card you called with (a joker calls BALANCED).
func style_in_play() -> String:
	if player_off:
		return STYLE_OF_SUIT[their_eval.lead_suit]
	var c: Dictionary = my_lead()
	return STYLE_OF_SUIT[c.suit] if (not c.is_empty() and c.suit < 4) else "BALANCED"


## The play being run, whoever is on offense.
func offense_card() -> Dictionary:
	return my_lead() if player_off else theirs[cpu_idx]


# ------------------------------------------------------------------ showdown
func showdown() -> Dictionary:
	if phase != "BET" or (player_off and play_idx < 0) or (not player_off and play_idx < 0):
		return {}
	for i in HAND_SIZE:                           # the computer's hand is turned over
		if not _def_seen[i]:
			_def_seen[i] = true
			_see(theirs[i])
	var off_eval: Dictionary = my_eval if player_off else their_eval
	var def_eval: Dictionary = their_eval if player_off else my_eval
	var off_m := Poker.multiplier(int(off_eval.cat))
	var def_m := Poker.multiplier(int(def_eval.cat))
	var style := style_in_play()
	var play := offense_card()
	var res := {"player_off": player_off, "off_win": 0, "win": 0, "my_cat": my_eval.cat, "their_cat": their_eval.cat,
			"style": style, "play": play, "my_lead": my_lead(), "their_lead": theirs[cpu_idx],
			"my_mult": Poker.multiplier(int(my_eval.cat)), "their_mult": Poker.multiplier(int(their_eval.cat)),
			"spin": 0, "spin_kind": "none", "mult": 1.0, "yards": 0, "turnover": false, "event": ""}
	if off_eval.score == def_eval.score:
		res.event = "PUSH"
		return _settle(res)
	var theta_true := DefContext.apply(play.theta, style)
	if off_eval.score > def_eval.score:
		res.off_win = 1
		res.spin_kind = "gain"
		res.spin = YardCurve.sample_gain(theta_true, rng)             # the wheel: positive yards only
		res.mult = off_m
		res.yards = int(round(float(res.spin) * off_m))
	else:
		res.off_win = -1
		var gap: int = int(def_eval.cat) - int(off_eval.cat)
		if gap >= PICK_SIX_GAP:
			res.event = "PICK SIX"
			res.turnover = true
		else:
			res.spin_kind = "loss"
			res.spin = YardCurve.sample_loss(theta_true, rng)
			res.mult = def_m
			res.yards = -int(round(float(res.spin) * def_m))
			res.event = "LOSS"
	res.win = res.off_win if player_off else -res.off_win              # from YOUR side
	if res.win == 1:
		best_cat = maxi(best_cat, int(my_eval.cat))
	_advance_field(res)
	return _settle(res)


func _advance_field(res: Dictionary) -> void:
	var y: int = res.yards
	var yl: float = st.yardline_to_opponent_goal - y
	if res.event == "":
		res.event = "GAIN"
	res.drive_over = false
	if res.turnover:
		res.drive_over = true
		res.event = res.event if res.off_win == -1 else "TURNOVER"
		return
	if yl <= 0.0:
		res.event = "TOUCHDOWN"
		res.drive_over = true
		if player_off:
			tds += 1
		else:
			cpu_tds += 1
		st.yardline_to_opponent_goal = 0.0
		return
	if yl >= 100.0:
		res.event = "SAFETY"
		res.drive_over = true
		return
	st.yardline_to_opponent_goal = yl
	if float(y) >= float(st.distance):
		st.down = 1
		st.distance = minf(10.0, yl)
		if res.off_win == 1:
			res.event = "FIRST DOWN"
	else:
		st.down += 1
		st.distance = maxf(0.5, float(st.distance) - float(y))
		if st.down > 4:
			res.event = "TURNOVER ON DOWNS"
			res.drive_over = true


func _settle(res: Dictionary) -> Dictionary:
	if player_off:
		yards_total += int(res.yards)
	if not res.has("drive_over"):
		res["drive_over"] = false
	history.append({"lead_id": res.play.id, "style": res.style, "win": res.win, "yards": res.yards, "player_off": player_off,
			"my_cat": res.my_cat, "their_cat": res.their_cat})
	log.push_front("%s: %s %+d yds" % [res.event, res.play.name, res.yards])
	last = res
	phase = "OVER" if (res.drive_over and drive_no >= total_drives()) else "RESULT"
	return res


## "WIN", "LOSS" or "TIE" once the game is over.
func outcome() -> String:
	if tds == cpu_tds:
		return "TIE"
	return "WIN" if tds > cpu_tds else "LOSS"


## Move on after RESULT: a fresh down, or the next drive (the ball changes sides) if the last one ended.
func next() -> void:
	if phase != "RESULT":
		return
	if last.get("drive_over", false):
		drive_no += 1
		player_off = not player_off
		_new_drive()
	else:
		_deal()
