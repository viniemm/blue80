class_name QGame
extends RefCounted
## One run of the card-betting game: bankroll, a drive of downs, and the round loop
##   DRAW  deal 5 each, you discard up to 3
##   BET   AI draws, 2 defense cards flip face-up, you pick a line and a stake
##   RESULT showdown: win -> your lead card runs and the bet settles on its yards (bet voided if you lose)
##          lose -> the defense's hand decides the damage, scaled by how badly you were beaten
## A defense card's suit is a style (BLITZ / ZONE / MAN / BALANCED); the style of its lead card bends your curve.
## Cards come from a persistent multi-deck shoe, reshuffled only when it runs low, so what has been dealt tells you
## something about what is left.

const ANTE := 1.0
const START_BANKROLL := 100.0
const MAX_STAKE_FRAC := 0.25
const TABLE_MAX := 10.0          # absolute table limit, so a winning bettor grows linearly and not exponentially
const TD_BONUS := 10.0
const STYLE_OF_SUIT := ["BLITZ", "ZONE", "MAN", "BALANCED"]
const STYLE_STRENGTH := 2.0
const VIG := 0.20
const DECKS := 4
const RESHUFFLE_AT := 48         # reshuffle the shoe when fewer than this many cards remain before a deal

var rng := RandomNumberGenerator.new()
var cards: Array                 # the 52 distinct plays (one deck)
var lines: Lines
var bankroll := START_BANKROLL
var phase := "DRAW"            # DRAW -> BET -> RESULT -> (DRAW | OVER)
var shoe: Array = []
var shoe_pos := 0
var seen_id := {}              # card id -> copies the player has seen since the last shuffle
var shuffles := 0
var mine: Array = []
var theirs: Array = []
var _def_seen: Array = []      # which defense cards the player has seen
var face_up: Array = []        # indices into `theirs` that are visible
var my_eval: Dictionary = {}
var their_eval: Dictionary = {}
var bet := {"line": -1, "stake": 0.0}
var st := {}                   # down, distance, yardline_to_opponent_goal
var drive_no := 1
var tds := 0
var last: Dictionary = {}
var history: Array = []        # one record per snap, for analytics
var log: Array = []


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	DefContext.strength = STYLE_STRENGTH
	cards = Deck52.build()
	lines = Lines.new(cards, VIG, "card")
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
	bet = {"line": -1, "stake": 0.0}
	my_eval = Poker.evaluate(mine)
	their_eval = {}
	phase = "DRAW"


func max_stake() -> float:
	return minf(snappedf(bankroll * MAX_STAKE_FRAC, 0.5), TABLE_MAX)


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
	return my_eval.lead


func my_mult() -> float:
	return Poker.multiplier(int(my_eval.cat))


func style_of(card: Dictionary) -> String:
	return STYLE_OF_SUIT[card.suit]


func line_threshold(k: int) -> int:
	return lines.threshold(my_lead(), k)


func line_house_p(k: int) -> float:
	return lines.house_p(my_lead(), k)


## Net chips won per chip staked if line k clears, including the hand multiplier.
func line_payout(k: int) -> float:
	return lines.odds(my_lead(), k) * my_mult()


func set_bet(k: int, stake: float) -> void:
	bet = {"line": k, "stake": clampf(stake, 0.0, max_stake()) if k >= 0 else 0.0}


## What the defense's lead card is, only known after the showdown (or by cheating in tests).
func hidden_style() -> String:
	return style_of(their_eval.lead)


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
	var res := {"win": 0, "my_cat": my_eval.cat, "their_cat": their_eval.cat, "style": hidden_style(),
			"my_lead": my_lead(), "their_lead": their_eval.lead, "yards": 0, "turnover": false, "event": "",
			"ante_delta": 0.0, "bet_delta": 0.0, "bonus": 0.0, "bet": bet.duplicate(), "voided": false, "cleared": false}
	if mine_score == their_score:
		res.event = "PUSH"
		res.voided = true
		return _settle(res)
	if mine_score > their_score:
		res.win = 1
		var m := my_mult()
		res.ante_delta = ANTE * m
		var lead := my_lead()
		var theta_true := DefContext.apply(lead.theta, res.style)
		var snap: Dictionary = YardCurve.sample(theta_true, rng)
		res.yards = snap.yards
		res.turnover = snap.turnover
		if bet.line >= 0 and bet.stake > 0.0:
			var cleared: bool = snap.yards >= line_threshold(bet.line)
			res.cleared = cleared
			res.bet_delta = bet.stake * line_payout(bet.line) if cleared else -float(bet.stake)
		_advance_field(res)
	else:
		res.win = -1
		res.ante_delta = -ANTE * Poker.multiplier(int(their_eval.cat))
		res.voided = bet.line >= 0
		_defense_wins(res)
	return _settle(res)


## A lost hand: the damage grows with how many hand categories the defense beat you by.
func _defense_wins(res: Dictionary) -> void:
	var gap: int = int(their_eval.cat) - int(my_eval.cat)
	if gap <= 0:
		res.event = "STUFFED"
		res.yards = -rng.randi_range(0, 2)
	elif gap == 1:
		res.event = "LOSS"
		res.yards = -rng.randi_range(1, 4)
	elif gap == 2:
		res.event = "SACKED"
		res.yards = -rng.randi_range(4, 8)
	elif gap == 3:
		res.event = "FUMBLE"
		res.yards = -rng.randi_range(1, 4)
		res.turnover = true
	else:
		res.event = "PICK SIX"
		res.yards = -rng.randi_range(2, 8)
		res.turnover = true
		res.bonus = -TD_BONUS * 0.5
	_advance_field(res)


func _advance_field(res: Dictionary) -> void:
	var y: int = res.yards
	var yl: float = st.yardline_to_opponent_goal - y
	if res.event == "":
		res.event = "RUN" if y >= 0 else "LOSS"
	res.drive_over = false
	if res.turnover:
		res.drive_over = true
		res.event = res.event if res.win == -1 else "TURNOVER"
		return
	if yl <= 0.0:
		res.event = "TOUCHDOWN"
		res.bonus += TD_BONUS
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
	var delta: float = res.ante_delta + res.bet_delta + res.bonus
	bankroll += delta
	res["delta"] = delta
	res["bankroll"] = bankroll
	if not res.has("drive_over"):
		res["drive_over"] = false
	history.append({"lead_id": my_lead().id, "style": res.style, "win": res.win, "yards": res.yards,
			"line": bet.line, "stake": bet.stake, "cleared": res.cleared, "delta": delta})
	log.push_front("%s: %s %+d yds  %+.1f chips" % [res.event, my_lead().name, res.yards, delta])
	last = res
	phase = "OVER" if bankroll <= 0.0 else "RESULT"
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
