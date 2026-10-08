class_name Drive
extends RefCounted
## One offensive drive: deck/hand/discard (draw-poker style), sequence combos, jokers, and play resolution.

const HAND_SIZE := 5
const MAX_DISCARD := 3
const PREVIEW_SIMS := 80

var D: Dictionary
var rng := RandomNumberGenerator.new()
var state: Dictionary
var deck: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var played: Array = []
var jokers: Array = []
var discards_left := 2
var over := false
var summary: Dictionary = {}
var yards_total := 0
var plays_run := 0
var log: Array = []
var _preview_cache := {}


func _init(data: Dictionary, seed_value: int = 0) -> void:
	D = data
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func new_drive(keep_jokers: bool = true) -> void:
	state = {"period": 1, "clock_seconds": 900, "down": 1, "distance": 10.0, "yardline_to_opponent_goal": 75.0,
			"possession_team": "EAST"}
	if deck.is_empty():
		var uid := 1
		for code in Cards.STARTER_DECK:
			deck.append(Cards.make_card(code, uid, D))
			uid += 1
	if jokers.is_empty() or not keep_jokers:
		var pool: Array = Cards.JOKERS.keys()
		pool.shuffle()
		jokers = pool.slice(0, 3)
	draw_pile = deck.duplicate()
	_shuffle(draw_pile)
	discard_pile = []
	hand = []
	played = []
	discards_left = 2
	over = false
	summary = {}
	yards_total = 0
	plays_run = 0
	log = []
	_preview_cache = {}
	_refill()


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func _draw_one() -> void:
	if draw_pile.is_empty():
		draw_pile = discard_pile.duplicate()
		discard_pile = []
		_shuffle(draw_pile)
	if not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())


func _refill() -> void:
	while hand.size() < HAND_SIZE and (not draw_pile.is_empty() or not discard_pile.is_empty()):
		_draw_one()


func can_discard() -> bool:
	return discards_left > 0 and not over


func discard(uids: Array) -> void:
	if not can_discard() or uids.is_empty():
		return
	var n := 0
	for uid in uids:
		if n >= MAX_DISCARD:
			break
		for i in hand.size():
			if hand[i].uid == uid:
				discard_pile.append(hand[i])
				hand.remove_at(i)
				n += 1
				break
	discards_left -= 1
	_refill()
	_preview_cache = {}


# ------------------------------------------------------------------ odds for a card
func combos_for(card: Dictionary) -> Array:
	return Cards.combos(played, card)


func tilt_for(card: Dictionary) -> Dictionary:
	var t := Cards.joker_tilt(jokers, state)
	for c in combos_for(card):
		Cards.merge(t, c.tilt)
	return t


func curve_for(card: Dictionary) -> Dictionary:
	var sigma := Cards.curve_sigma(jokers, combos_for(card))
	var lean := Cards.run_lean(played)
	return DefenseCurve.compute(state, D, lean, sigma)


## Monte Carlo wheel for a card. Cached until the situation changes.
func preview(card: Dictionary) -> Dictionary:
	var key := "%d|%d|%s|%s|%d" % [card.uid, state.down, str(state.distance), str(state.yardline_to_opponent_goal), played.size()]
	if _preview_cache.has(key):
		return _preview_cache[key]
	var curve := curve_for(card)
	var tilt := tilt_for(card)
	var prng := RandomNumberGenerator.new()
	prng.seed = hash(key)
	var ev := Evaluator.evaluate(state, D.plays[card.code], D, curve.weights, tilt, PREVIEW_SIMS, prng)
	ev["curve"] = curve
	ev["combos"] = combos_for(card)
	_preview_cache[key] = ev
	return ev


## Wheel for a field goal or punt (no cards, no tilt, neutral defense).
func preview_kick(kind: String) -> Dictionary:
	var weights := {}
	for code in D.defense_order:
		weights[code] = 1.0 if code == "C3M" else 0.0
	var prng := RandomNumberGenerator.new()
	prng.seed = hash("kick%s%s" % [kind, str(state.yardline_to_opponent_goal)])
	return Evaluator.evaluate(state, D.plays["FG" if kind == "FG" else "PNT"], D, weights, Cards.neutral(), 60, prng)


# ------------------------------------------------------------------ resolution
func play_card(card: Dictionary) -> Dictionary:
	var combo_list := combos_for(card)
	var tilt := tilt_for(card)
	var curve := curve_for(card)
	var def_code := DefenseCurve.sample(curve.weights, D.defense_order, rng)
	var out := _resolve(D.plays[card.code], def_code, tilt)
	out["combos"] = combo_list
	out["curve"] = curve
	hand = hand.filter(func(c): return c.uid != card.uid)
	discard_pile.append(card)
	played.append(card)
	out["card"] = card
	_finish(out)
	if not over:
		_refill()
	return out


func kick(kind: String) -> Dictionary:
	var code := "FG" if kind == "FG" else "PNT"
	var out := _resolve(D.plays[code], "C3M", Cards.neutral())
	out["combos"] = []
	out["card"] = {"code": code, "name": "FIELD GOAL" if kind == "FG" else "PUNT", "suit": "RUN", "rank": 0}
	_finish(out)
	return out


func _resolve(call: Dictionary, def_code: String, tilt: Dictionary) -> Dictionary:
	var defense: Dictionary = D.defense[def_code]
	var res := Sim.resolve_play(state, call, defense, D.east, D.west, D.matrix, tilt, rng)
	var r: Dictionary = res.result
	var pre := state
	state = res.state
	return {"result": r, "cat": Evaluator.categorize(r), "def_code": def_code, "def": defense, "pre": pre}


func _finish(out: Dictionary) -> void:
	var r: Dictionary = out.result
	plays_run += 1
	yards_total += int(r.yards) if r.outcome in ["RUN", "COMPLETE", "SCRAMBLE", "SACK", "FUMBLE"] else 0
	log.push_front("%s: %s %+d" % [out.card.name, r.outcome, r.yards])
	if r.possession_change or state.clock_seconds <= 0:
		over = true
		var title := "DRIVE OVER"
		var pts := int(r.points_scored)
		match r.outcome:
			"FIELD_GOAL_GOOD":
				title = "FIELD GOAL"
			"FIELD_GOAL_MISSED":
				title = "KICK MISSED"
			"PUNT", "TOUCHBACK":
				title = "PUNT"
			"INTERCEPTION":
				title = "INTERCEPTED"
			"FUMBLE":
				title = "FUMBLE LOST"
			_:
				if r.touchdown:
					title = "TOUCHDOWN"
				elif r.safety:
					title = "SAFETY"
				elif r.turnover:
					title = "TURNOVER ON DOWNS"
				else:
					title = "TIME"
		summary = {"title": title, "points": pts, "plays": plays_run, "yards": yards_total}
