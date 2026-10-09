extends SceneTree
## How often do hands "hit" under different deal structures?
##   godot --headless --path godot -s tests/hit_rate.gd
## Modes: single deck 5-card draw (current), 6-deck shoe 5-card draw, hold'em style (2 hole + 5 community, best 5 of 7),
## and 3 hole + 3 community (best 5 of 6).

var cards: Array
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 99
	cards = Deck52.build()
	print("\nfinal-hand category for YOU (percent), P(pair+), average multiplier, and what you win with\n")
	print("%s | HIGH  PAIR  2PR  TRIPS STR+  | pair+  avg mult | win%%  tie%%  mult(win) lead gold/plat" % "mode".rpad(30))
	_run("single deck, 5-card draw (now)", 1, "draw", 40000)
	_run("6-deck shoe, 5-card draw", 6, "draw", 40000)
	_run("hold'em: 2 hole + 5 community", 1, "holdem", 25000)
	_run("3 hole + 3 community", 1, "three", 25000)
	quit()


func _shoe(decks: int) -> Array:
	var s: Array = []
	for d in decks:
		s.append_array(cards)
	for i in range(s.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = s[i]
		s[i] = s[j]
		s[j] = t
	return s


## Best five-card hand out of 5, 6 or 7 cards.
func _best(hand: Array) -> Dictionary:
	if hand.size() == 5:
		return Poker.evaluate(hand)
	var best: Dictionary = {}
	var n := hand.size()
	var skip_count := n - 5
	for a in n:
		for b in range(a + 1, n) if skip_count == 2 else [-1]:
			var five: Array = []
			for i in n:
				if i != a and i != b:
					five.append(hand[i])
			var ev := Poker.evaluate(five)
			if best.is_empty() or ev.score > best.score:
				best = ev
	return best


func _draw_hand(hand: Array, deck: Array, pos: int) -> int:
	for i in Poker.discards(hand):
		hand[i] = deck[pos]
		pos += 1
	return pos


func _run(name: String, decks: int, mode: String, rounds: int) -> void:
	var cat := [0, 0, 0, 0, 0]       # high, pair, two pair, trips, straight+
	var mult_all := 0.0
	var wins := 0
	var ties := 0
	var mult_win := 0.0
	var good_lead := 0
	for r in rounds:
		var deck := _shoe(decks)
		var me: Dictionary
		var them: Dictionary
		if mode == "draw":
			var a: Array = deck.slice(0, 5)
			var b: Array = deck.slice(5, 10)
			var pos := _draw_hand(a, deck, 10)
			pos = _draw_hand(b, deck, pos)
			me = Poker.evaluate(a)
			them = Poker.evaluate(b)
		elif mode == "holdem":
			var board: Array = deck.slice(0, 5)
			me = _best(deck.slice(5, 7) + board)
			them = _best(deck.slice(7, 9) + board)
		else:
			var board3: Array = deck.slice(0, 3)
			me = _best(deck.slice(3, 6) + board3)
			them = _best(deck.slice(6, 9) + board3)
		var c: int = me.cat
		cat[mini(c, 4) if c < 4 else 4] += 1 if c >= 4 else 0
		if c < 4:
			cat[c] += 1
		mult_all += Poker.MULT[c]
		if me.score > them.score:
			wins += 1
			mult_win += Poker.MULT[c]
			if me.lead.tier in ["GOLD", "PLATINUM"]:
				good_lead += 1
		elif me.score == them.score:
			ties += 1
	var n := float(rounds)
	print("%s | %4.1f %5.1f %4.1f %5.1f %4.1f | %5.1f%%  x%.2f   | %4.1f %4.1f  x%.2f      %4.1f%%" % [
		name.rpad(30), 100.0 * cat[0] / n, 100.0 * cat[1] / n, 100.0 * cat[2] / n, 100.0 * cat[3] / n, 100.0 * cat[4] / n,
		100.0 * (n - cat[0]) / n, mult_all / n, 100.0 * wins / n, 100.0 * ties / n, mult_win / maxf(1.0, float(wins)),
		100.0 * good_lead / maxf(1.0, float(wins))])
