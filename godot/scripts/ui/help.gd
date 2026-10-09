class_name HelpScreen
extends PxScreen
## Paged rules. Left/Right to turn pages.

const PAGES := [
	{"title": "THE GOAL", "body": [
		"You drive down the field. Each down you play poker for the right to run a play, then bet chips on how many yards it gains.",
		"You start with %d chips. Run out and the run is over. Every touchdown pays a %d chip bonus." % [int(QGame.START_BANKROLL), int(QGame.TD_BONUS)],
		"Nothing is hidden about the odds. The edge is in how you read them.",
	]},
	{"title": "THE DEAL", "body": [
		"You and the defense each get 5 cards from a 4-deck shoe. Tap up to 3 of yours to swap, then DRAW.",
		"Your best poker hand sets your multiplier. Its lead card (the pair, the trips, or the high card) is the play you run.",
		"Suit is the play family: RUN, RPO, PASS, SHOT. Rank is the tier: 2-6 bronze, 7-10 silver, J Q K gold, A platinum. Rarer tiers gain more, with more variance.",
		"Lose the hand and the defense hurts you: a stuff, a loss, a sack, a fumble or a pick six, by how badly you lost.",
	]},
	{"title": "WILD CARDS", "body": [
		"Two jokers, PHILLY SPECIAL and FLEA FLICKER, are shuffled into the shoe (one of each per deck).",
		"A joker stands in for any card, so it builds the strongest hand it can: a pair becomes trips, four of a kind becomes five of a kind.",
		"If a joker is part of your best hand you may also run it as your play. Trick plays are swingy: big plays, and big risk.",
	]},
	{"title": "CHOOSE YOUR PLAY", "body": [
		"The cards that make up your best hand are the ones you may run: a pair gives 2 choices, trips 3, two pair 4, and a straight, flush or full house all 5. High card has only its top card.",
		"After the draw, tap a gold-edged card to pick the play (or press P). The bet lines change to match that card.",
		"Each card shows a + strength and a - weakness: the defense styles it beats and loses to. Read the two face-up defense cards, then pick the play that fits.",
		"Tap the (i) badge on any card, or hold it, for its formation, routes and expected yards against each defense.",
	]},
	{"title": "ANTE, STAKE, NO BET", "body": [
		"ANTE: every hand costs one chip. Win and you collect it times your hand multiplier; lose and you pay it times the DEFENSE's multiplier. This is the base game.",
		"STAKE: an optional side bet on your play's yards. Pick a line and an amount. It only plays if you win the hand: it pays the line's odds times your multiplier if the play clears, and loses the stake if it misses. Lose the hand and the stake is refunded.",
		"NO BET: skip the side bet and play the ante only. Do it when you see no edge.",
	]},
	{"title": "THE BET", "body": [
		"After the draw, pick one of five yardage lines for your play: CHECKDOWN, SHORT, MEDIUM, LONG or HAIL MARY.",
		"Each line shows its yards and the house chance (about 90, 75, 50, 25 and 10 percent). Longer lines pay more.",
		"Clear the line and the bet pays its odds times your hand multiplier. Miss and you lose the stake. Lose the hand and the stake comes back.",
		"The house keeps a %d percent cut and stakes are capped at %d chips." % [int(QGame.VIG * 100.0), int(QGame.TABLE_MAX)],
	]},
	{"title": "READ THE DEFENSE", "body": [
		"Two of the defense's five cards flip face-up before you bet. The suit of its lead card is its hidden style, and the style bends your play's yardage.",
		"@styles",
		"The house prices your card averaged over all four styles, so each clue you read is edge.",
	]},
	{"title": "COUNT THE SHOE", "body": [
		"Cards come from a 4-deck shoe that reshuffles only when under %d cards remain." % QGame.RESHUFFLE_AT,
		"The strip under the tells counts the cards you have seen, by rank. Green means richer than average, red means thinner.",
		"A rank-rich shoe makes pairs and trips likelier for both hands, so size your stakes to match.",
	]},
	{"title": "QUANT TIPS", "body": [
		"Edge is chance times payout, minus one. The house price is an average, so your own read is the edge.",
		"Strong hands multiply payouts: lean in. Weak hands: bet small or skip the bet.",
		"Size stakes like Kelly: a bigger edge earns a bigger stake, and never all-in.",
		"Hail Mary lines are volatile. Mix in checkdowns to ride out variance.",
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
