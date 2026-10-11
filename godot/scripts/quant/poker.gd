class_name Poker
extends RefCounted
## Poker: hand ranking of the best 5 cards out of any hand size, the multiplier table, the lead-card rule and a draw heuristic.
## A card here is any Dictionary with int `rank` (2..14) and int `suit` (0..3).

const CAT_NAMES := ["HIGH CARD", "PAIR", "TWO PAIR", "TRIPS", "STRAIGHT", "FLUSH", "FULL HOUSE", "QUADS", "STRAIGHT FLUSH", "FIVE OF A KIND"]
## Multiplier by hand category. Applies to the winner's payout; a loser pays the opponent's multiplier.
const MULT := [1.0, 1.1, 1.4, 1.8, 2.3, 2.8, 3.5, 5.0, 8.0, 12.0]


## Best hand, with jokers standing in for any card. Returns
##   cat, score (higher wins), lead (the default card that becomes the play), lead_idx, lead_suit (the suit that sets
##   the defense style; a joker's stand-in suit), eligible (hand positions that form the combination, any of which
##   may be chosen as the play) and wild (what each joker is standing in for).
static func evaluate(hand: Array) -> Dictionary:
	if hand.size() <= 5:
		return _eval5(hand)
	var best: Dictionary = {}
	var best_combo: Array = []
	for combo in _combos(hand.size()):
		var sub: Array = []
		for i in combo:
			sub.append(hand[i])
		var ev := _eval5(sub)
		if best.is_empty() or ev.score > best.score:
			best = ev
			best_combo = combo
	var eligible: Array = []
	for i in best.eligible:
		eligible.append(best_combo[i])
	best["eligible"] = eligible
	best["lead_idx"] = best_combo[best.lead_idx]
	best["lead"] = hand[best.lead_idx]
	return best


static var _combo_cache := {}


## Every way to pick 5 of n card positions (21 for 7 cards).
static func _combos(n: int) -> Array:
	if _combo_cache.has(n):
		return _combo_cache[n]
	var out: Array = []
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						out.append([a, b, c, d, e])
	_combo_cache[n] = out
	return out


## Best 5-card hand with jokers standing in for any card (the old evaluate).
static func _eval5(hand: Array) -> Dictionary:
	var jk: Array = []
	for i in hand.size():
		if hand[i].get("joker", false):
			jk.append(i)
	if jk.is_empty():
		return _eval_plain(hand)
	var best: Dictionary = {}
	var best_sub: Array = []
	# A joker's suit can only matter for a flush, and that needs every natural card to share one suit, so borrowing
	# a natural card's suit is always enough. Each joker then has 13 candidate ranks: two jokers cost 169
	# evaluations instead of 2704.
	var suit := 0
	for i in hand.size():
		if not hand[i].get("joker", false):
			suit = hand[i].suit
			break
	var suits: Array = [suit]
	var subs: Array = [[]]
	for j in jk:                                   # every assignment of a stand-in card to every joker
		var nxt: Array = []
		for sub in subs:
			for r in range(2, 15):
				for s in suits:
					nxt.append(sub + [{"rank": r, "suit": s}])
		subs = nxt
	for sub in subs:
		var h: Array = hand.duplicate()
		for k in jk.size():
			h[jk[k]] = sub[k]
		var ev := _eval_plain(h)
		if best.is_empty() or ev.score > best.score:
			best = ev
			best_sub = sub
	best["wild"] = best_sub
	for j in jk:
		if not best.eligible.has(j):
			best.eligible.append(j)
	var li: int = best.lead_idx
	best["lead"] = hand[li]
	return best


static func _eval_plain(hand: Array) -> Dictionary:
	var counts := {}
	var ranks: Array = []
	var flush := true
	for c in hand:
		counts[c.rank] = int(counts.get(c.rank, 0)) + 1
		ranks.append(c.rank)
		if c.suit != hand[0].suit:
			flush = false
	ranks.sort()
	ranks.reverse()
	var groups: Array = []
	for r in counts:
		groups.append([int(counts[r]), int(r)])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var straight := false
	var high: int = ranks[0]
	if counts.size() == 5:
		if ranks[0] - ranks[4] == 4:
			straight = true
		elif ranks == [14, 5, 4, 3, 2]:
			straight = true
			high = 5
	var g0: int = groups[0][0]
	var g1: int = groups[1][0] if groups.size() > 1 else 0
	var cat := 0
	if g0 >= 5:
		cat = 9
	elif straight and flush:
		cat = 8
	elif g0 == 4:
		cat = 7
	elif g0 == 3 and g1 == 2:
		cat = 6
	elif flush:
		cat = 5
	elif straight:
		cat = 4
	elif g0 == 3:
		cat = 3
	elif g0 == 2 and g1 == 2:
		cat = 2
	elif g0 == 2:
		cat = 1
	var tiebreak: Array = []
	if straight:
		tiebreak = [high]
	else:
		for g in groups:
			tiebreak.append(g[1])
	var score := cat
	for i in 5:
		score = score * 15 + (int(tiebreak[i]) if i < tiebreak.size() else 0)
	# lead card: the paired/tripled rank for made hands with groups, otherwise the high card
	var lead_rank: int = groups[0][1] if cat in [1, 2, 3, 6, 7, 9] else high
	var lead_idx := 0
	var found := false
	for i in hand.size():
		if hand[i].rank == lead_rank and (not found or hand[i].suit > hand[lead_idx].suit):
			lead_idx = i
			found = true
	# every card in the made combination may be chosen as the play: the stronger the hand, the more choices
	var eligible: Array = []
	for i in hand.size():
		var rk: int = hand[i].rank
		var member := false
		match cat:
			0: member = i == lead_idx
			1, 3, 7: member = rk == groups[0][1]
			2: member = rk == groups[0][1] or rk == groups[1][1]
			_: member = true                         # straight, flush, full house, straight flush, five of a kind
		if member:
			eligible.append(i)
	return {"cat": cat, "score": score, "lead": hand[lead_idx], "lead_idx": lead_idx, "lead_suit": hand[lead_idx].suit,
			"eligible": eligible, "wild": []}


static func multiplier(cat: int) -> float:
	return MULT[cat]


## Which hand positions the computer discards (at most `max_n`). It keeps the cards that make its best hand, any joker, and a
## four-card flush draw, and throws away the lowest of the rest.
static func discards(hand: Array, max_n: int = 3) -> Array:
	var ev := evaluate(hand)
	var cat: int = ev.cat
	var by_suit := {}
	for i in hand.size():
		if not hand[i].get("joker", false):
			var sv: int = hand[i].suit
			if not by_suit.has(sv):
				by_suit[sv] = 0
			by_suit[sv] += 1
	var draw_suit := -1
	if cat < 5:
		for sv in by_suit:
			if by_suit[sv] >= 4:
				draw_suit = sv
	var cand: Array = []
	for i in hand.size():
		if ev.eligible.has(i) or hand[i].get("joker", false):
			continue
		var score: int = hand[i].rank
		if draw_suit >= 0 and hand[i].suit == draw_suit:
			score += 100
		cand.append([score, i])
	cand.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	for k in mini(max_n, cand.size()):
		out.append(cand[k][1])
	return out
