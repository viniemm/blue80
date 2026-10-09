class_name Poker
extends RefCounted
## 5-card poker: hand ranking, the multiplier table, lead-card rule and a draw heuristic.
## A card here is any Dictionary with int `rank` (2..14) and int `suit` (0..3).

const CAT_NAMES := ["HIGH CARD", "PAIR", "TWO PAIR", "TRIPS", "STRAIGHT", "FLUSH", "FULL HOUSE", "QUADS", "STRAIGHT FLUSH", "FIVE OF A KIND"]
## Multiplier by hand category. Applies to the winner's payout; a loser pays the opponent's multiplier.
const MULT := [1.0, 1.1, 1.4, 1.8, 2.3, 2.8, 3.5, 5.0, 8.0, 12.0]


## Returns {cat:int, score:int (higher wins), lead:Dictionary (the card that becomes the play)}.
static func evaluate(hand: Array) -> Dictionary:
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
	var lead: Dictionary = {}
	for c in hand:
		if c.rank == lead_rank and (lead.is_empty() or c.suit > lead.suit):
			lead = c
	return {"cat": cat, "score": score, "lead": lead}


static func multiplier(cat: int) -> float:
	return MULT[cat]


## Which hand positions to discard. Keeps made pairs/trips/quads, draws to a 4-flush or open 4-straight,
## otherwise keeps the two highest cards.
static func discards(hand: Array) -> Array:
	var ev := evaluate(hand)
	var cat: int = ev.cat
	if cat >= 4 and cat != 7 or cat == 6:
		return []
	var counts := {}
	for c in hand:
		counts[c.rank] = int(counts.get(c.rank, 0)) + 1
	var out: Array = []
	if cat in [1, 2, 3, 7]:
		for i in hand.size():
			var keep := false
			if cat == 2 or cat == 1 or cat == 3 or cat == 7:
				keep = int(counts[hand[i].rank]) >= 2
			if not keep:
				out.append(i)
		return out
	# high card: look for 4-flush, then open-ended 4-straight
	var by_suit := {}
	for i in hand.size():
		var s: int = hand[i].suit
		if not by_suit.has(s):
			by_suit[s] = []
		by_suit[s].append(i)
	for s in by_suit:
		if by_suit[s].size() == 4:
			for i in hand.size():
				if not by_suit[s].has(i):
					out.append(i)
			return out
	var order: Array = range(hand.size())
	order.sort_custom(func(a, b): return hand[a].rank > hand[b].rank)
	var rs: Array = hand.map(func(c): return c.rank)
	rs.sort()
	for skip in 5:
		var four: Array = []
		for i in 5:
			if i != skip:
				four.append(rs[i])
		if four[3] - four[0] == 3 and four[0] > 2 and four[3] < 14:
			for i in hand.size():
				if hand[i].rank == rs[skip]:
					return [i]
	return [order[2], order[3], order[4]]
