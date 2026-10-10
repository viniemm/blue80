class_name QGame
extends RefCounted
## One run: DRIVES drives of four downs, scored in touchdowns. Yardage is the only currency, and the wheel decides it.
##   DRAW   deal 5 each, you discard up to 3
##   BET    the AI draws, 2 defense cards flip face-up; you pick which card of your made hand is the play, then SNAP
##   RESULT showdown. Win the hand: the wheel spins a gain (positive yards only) times YOUR hand multiplier. Lose it:
##          the wheel spins a loss times THEIR multiplier. Losing by PICK_SIX_GAP or more hand classes is a turnover.
## A defense card's suit is a style (BLITZ / ZONE / MAN / BALANCED); the style of its lead card bends your play's curve.
## Cards come from a persistent multi-deck shoe, reshuffled only when it runs low, so what has been dealt tells you
## something about what is left.

const DRIVES := 6
const PICK_SIX_GAP := 4          # lose the hand by this many classes or more and it is a turnover
const STYLE_OF_SUIT := ["BLITZ", "ZONE", "MAN", "BALANCED"]
const STYLE_STRENGTH := 2.0
const DECKS := 4
const RESHUFFLE_AT := 48         # reshuffle the shoe when fewer than this many cards remain before a deal

var rng := RandomNumberGenerator.new()
var cards: Array                 # the 52 distinct plays plus the 2 jokers
var phase := "DRAW"              # DRAW -> BET -> RESULT -> (DRAW | OVER)
var shoe: Array = []
var shoe_pos := 0
var seen_id := {}                # card id -> copies the player has seen since the last shuffle
var shuffles := 0
var mine: Array = []
var theirs: Array = []
var _def_seen: Array = []        # which defense cards the player has seen
var face_up: Array = []          # indices into `theirs` that are visible
var my_eval: Dictionary = {}
var their_eval: Dictionary = {}
var play_idx := 0                # which of your cards runs the play (any card in the made hand may be chosen)
var st := {}                     # down, distance, yardline_to_opponent_goal
var drive_no := 1
var tds := 0
var yards_total := 0             # net yards over the run
var best_cat := -1               # best hand category won this run
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


## Copies of this card the player has not seen (some may be in the defense's hidden discards).
func copies_left(card_id: int) -> int:
	return maxi(0, DECKS - int(seen_id.get(card_id, 0)))


func rank_left(rank: int) -> int:
	var n := 0
	for s in 4:
		n += copies_left(s * 13 + (rank - 2))
	return n


func wild_left() -> int:
	return copies_left(52) + copies_left(53)


## Every unseen copy, expanded, for probability work (the test analyst samples from this).
func unseen_pool() -> Array:
	var out: Array = []
	for c in cards:
		for k in copies_left(c.id):
			out.append(c)
	return out


# ------------------------------------------------------------------ setup
func _new_drive() -> void:
	st = {"down": 1, "distance": 10.0, "yardline_to_opponent_goal": 75.0, "period": 1, "clock_seconds": 900,
			"possession_team": "EAST"}
	_deal()


func _deal() -> void:
	if shoe_left() < RESHUFFLE_AT:
		_shuffle_shoe()
	mine = []
	theirs = []
	for i in 5:
		var c := _take()
		mine.append(c)
		_see(c)
	for i in 5:
		theirs.append(_take())
	_def_seen = [false, false, false, false, false]
	face_up = []
	my_eval = Poker.evaluate(mine)
	play_idx = my_eval.lead_idx
	their_eval = {}
	phase = "DRAW"


# ------------------------------------------------------------------ the draw
## Discard the hand positions in `idx` (up to 3), the AI draws, and two defense cards flip face-up.
func draw(idx: Array) -> void:
	if phase != "DRAW":
		return
	for i in idx.slice(0, 3):
		var c := _take()
		mine[i] = c
		_see(c)
	for i in Poker.discards(theirs):
		theirs[i] = _take()                      # the AI's discards and new cards stay unseen
	my_eval = Poker.evaluate(mine)
	play_idx = my_eval.lead_idx
	their_eval = Poker.evaluate(theirs)
	var order := [0, 1, 2, 3, 4]
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	face_up = order.slice(0, 2)
	face_up.sort()
	for i in face_up:
		_def_seen[i] = true
		_see(theirs[i])
	phase = "BET"


func skip_draw() -> void:
	draw([])


# ------------------------------------------------------------------ info for the UI
func my_lead() -> Dictionary:
	return mine[play_idx]


## Hand positions that may be chosen as the play: every card in the made combination, plus any joker.
func eligible() -> Array:
	return my_eval.eligible


func set_play(i: int) -> void:
	if (phase == "DRAW" or phase == "BET") and my_eval.eligible.has(i):
		play_idx = i


func my_mult() -> float:
	return Poker.multiplier(int(my_eval.cat))


func style_of(card: Dictionary) -> String:
	return STYLE_OF_SUIT[card.suit] if card.suit < 4 else "WILD"


## What the defense's lead card is, only known after the showdown (or by cheating in tests).
func hidden_style() -> String:
	return STYLE_OF_SUIT[their_eval.lead_suit]           # a joker leading stands in for some suit


# ------------------------------------------------------------------ showdown
func showdown() -> Dictionary:
	if phase != "BET":
		return {}
	for i in 5:                                   # the defense hand is turned over
		if not _def_seen[i]:
			_def_seen[i] = true
			_see(theirs[i])
	var mine_score: int = my_eval.score
	var their_score: int = their_eval.score
	var my_m := my_mult()
	var their_m := Poker.multiplier(int(their_eval.cat))
	var res := {"win": 0, "my_cat": my_eval.cat, "their_cat": their_eval.cat, "style": hidden_style(),
			"my_lead": my_lead(), "their_lead": their_eval.lead, "my_mult": my_m, "their_mult": their_m,
			"spin": 0, "spin_kind": "none", "mult": 1.0, "yards": 0, "turnover": false, "event": ""}
	if mine_score == their_score:
		res.event = "PUSH"
		return _settle(res)
	var lead := my_lead()
	var theta_true := DefContext.apply(lead.theta, res.style)
	if mine_score > their_score:
		res.win = 1
		res.spin_kind = "gain"
		res.spin = YardCurve.sample_gain(theta_true, rng)             # the wheel: positive yards only
		res.mult = my_m
		res.yards = int(round(float(res.spin) * my_m))
		best_cat = maxi(best_cat, int(my_eval.cat))
	else:
		res.win = -1
		var gap: int = int(their_eval.cat) - int(my_eval.cat)
		if gap >= PICK_SIX_GAP:
			res.event = "PICK SIX"
			res.turnover = true
		else:
			res.spin_kind = "loss"
			res.spin = YardCurve.sample_loss(theta_true, rng)
			res.mult = their_m
			res.yards = -int(round(float(res.spin) * their_m))
			res.event = "LOSS"
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
		res.event = res.event if res.win == -1 else "TURNOVER"
		return
	if yl <= 0.0:
		res.event = "TOUCHDOWN"
		res.drive_over = true
		tds += 1
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
		if res.win == 1:
			res.event = "FIRST DOWN"
	else:
		st.down += 1
		st.distance = maxf(0.5, float(st.distance) - float(y))
		if st.down > 4:
			res.event = "TURNOVER ON DOWNS"
			res.drive_over = true


func _settle(res: Dictionary) -> Dictionary:
	yards_total += int(res.yards)
	if not res.has("drive_over"):
		res["drive_over"] = false
	history.append({"lead_id": my_lead().id, "style": res.style, "win": res.win, "yards": res.yards,
			"my_cat": res.my_cat, "their_cat": res.their_cat})
	log.push_front("%s: %s %+d yds" % [res.event, my_lead().name, res.yards])
	last = res
	phase = "OVER" if (res.drive_over and drive_no >= DRIVES) else "RESULT"
	return res


## Move on after RESULT: a fresh down, or a new drive if the last one ended.
func next() -> void:
	if phase != "RESULT":
		return
	if last.get("drive_over", false):
		drive_no += 1
		_new_drive()
	else:
		_deal()
