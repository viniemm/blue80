class_name HelpScreen
extends PxScreen
## Paged rules. Left/Right to turn pages.

const PAGES := [
	{"title": "THE GOAL", "body": [
		"A run is %d drives of four downs each. Score as many touchdowns as you can. Yardage is the only currency: no chips, no points." % QGame.DRIVES,
		"Each down you play poker, pick a play, and hit SNAP. A wheel then decides how many yards you gain or lose.",
		"Win the hand and the wheel gains you yards. Lose it and the wheel costs you yards. Nothing is hidden about the odds, so the edge is in how you read them.",
	]},
	{"title": "THE DEAL", "body": [
		"You and the defense each get 5 cards from a 4-deck shoe. Tap up to 3 of yours to swap, then DRAW.",
		"Your best poker hand sets your multiplier. Its lead card (the pair, the trips, or the high card) is the play you run.",
		"Suit is the play family: RUN, RPO, PASS, SHOT. Rank is the tier: 2-6 bronze, 7-10 silver, J Q K gold, A platinum. Rarer tiers gain more, with more variance.",
		"Hand classes, low to high: high card, pair, two pair, trips, straight, flush, full house, quads, straight flush, five of a kind.",
	]},
	{"title": "WILD CARDS", "body": [
		"Two jokers, PHILLY SPECIAL and FLEA FLICKER, are shuffled into the shoe (one of each per deck).",
		"A joker stands in for any card, so it builds the strongest hand it can: a pair becomes trips, four of a kind becomes five of a kind.",
		"If a joker is part of your best hand you may also run it as your play. Trick plays are swingy: big plays, and big risk.",
	]},
	{"title": "CHOOSE YOUR PLAY", "body": [
		"The cards that make up your best hand are the ones you may run: a pair gives 2 choices, trips 3, two pair 4, and a straight, flush or full house all 5. High card has only its top card.",
		"After the draw, tap a gold-edged card to pick the play (or press P). The wheel odds change to match that card.",
		"Each card shows a + strength and a - weakness: the defense styles it beats and loses to. Read the two face-up defense cards, then pick the play that fits.",
		"Tap the (i) badge on any card, or hold it, for its formation, routes and expected yards against each defense.",
	]},
	{"title": "THE WHEEL", "body": [
		"After the draw, the wheel at the bottom shows this play's odds if you win. Hit SNAP and the hands are compared.",
		"WIN the hand: the wheel spins a gain (positive yards only), times YOUR hand multiplier. A pair is x1.1, a flush x2.8, quads x5.",
		"LOSE the hand: the wheel spins a loss, times THEIR multiplier. If their hand is %d or more classes above yours it is a turnover instead, with no spin." % QGame.PICK_SIX_GAP,
		"Wedges are sized by the play's real odds against the defense's hidden style, so a play that suits the defense has a fatter gain wheel.",
	]},
	{"title": "READ THE DEFENSE", "body": [
		"Two of the defense's five cards flip face-up before you bet. The suit of its lead card is its hidden style, and the style bends your play's yardage on the wheel.",
		"@styles",
		"The two face-up cards also hint at how strong their hand is, which sets the multiplier you pay on a loss.",
	]},
	{"title": "COUNT THE SHOE", "body": [
		"Cards come from a 4-deck shoe that reshuffles only when under %d cards remain." % QGame.RESHUFFLE_AT,
		"The strip under the tells counts the cards you have seen, by rank. Green means richer than average, red means thinner.",
		"A rank-rich shoe makes pairs and trips likelier for both hands, so it moves the odds of winning the hand.",
	]},
	{"title": "QUANT TIPS", "body": [
		"Your edge is choosing the card to keep and the play to run. You cannot size a bet, so every decision is about the wheel.",
		"Read the two face-up defense cards to guess the style, then run the play whose strength matches it: its wheel will be fatter.",
		"Count the shoe: it tells you how likely a big hand is for you (a better multiplier) and for them (a bigger loss).",
		"A weak play with a big multiplier can beat a strong play with a small one.",
	]},
]
const STYLES := [
	["BLITZ", "more sacks and big plays"],
	["ZONE", "fewer sacks, far fewer big plays"],
	["MAN", "a few more big plays and sacks"],
	["BALANCED", "no change"],
]

var page := 0
var _prev: PxButton
var _next: PxButton


func _ready() -> void:
	set_card_alpha(0.18)
	_prev = add_btn("PREV", Px.ROYAL, Rect2(8, 556, 100, 28), func(): _turn(-1))
	_next = add_btn("NEXT", Px.GOLD, Rect2(252, 556, 100, 28), func(): _turn(1))
	add_back("MENU")
	_turn(0)


func _turn(d: int) -> void:
	page = clampi(page + d, 0, PAGES.size() - 1)
	_prev.disabled = page == 0
	_next.disabled = page == PAGES.size() - 1


func _para(y: float, text: String, color: Color = Px.FG) -> float:
	for line in Px.wrap(text, 332.0, 1):
		Px.text(self, 14, y, line, 1, color)
		y += Px.line_height(1)
	return y + 8.0


func _paint() -> void:
	banner("HOW TO PLAY")
	var p: Dictionary = PAGES[page]
	Px.text(self, 14, 54, "%d/%d  %s" % [page + 1, PAGES.size(), p.title], 2, Px.GOLD)
	var y := 82.0
	for item in p.body:
		if item == "@styles":
			for s in STYLES:
				draw_rect(Rect2(14, y + 1, 64, 13), QCardView.STYLE_COLORS[s[0]])
				Px.text_center(self, 46, y + 1, s[0], 0, Color("0a0a1a"))
				Px.text(self, 86, y, s[1], 1, Px.FG)
				y += 20.0
			y += 6.0
		else:
			y = _para(y, item)
	for i in PAGES.size():
		draw_rect(Rect2(W / 2.0 - PAGES.size() * 7.0 + i * 14.0, 566, 8, 8), Px.GOLD if i == page else Px.LINE)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_LEFT:
			_turn(-1)
		elif e.keycode == KEY_RIGHT:
			_turn(1)
		elif e.keycode == KEY_ESCAPE:
			go.emit("menu")
