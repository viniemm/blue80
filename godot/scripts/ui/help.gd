class_name HelpScreen
extends PxScreen
## Paged rules. Left/Right to turn pages.

static var PAGES: Array = [
	{"title": "THE GOAL", "body": [
		"You play the computer. Drives alternate: %d each, four downs per drive. Whoever scores more touchdowns wins." % QGame.DRIVES_PER_SIDE,
		"When you have the ball you choose the PLAY. When the computer has it you are on DEFENSE and choose the defensive CALL.",
		"Yardage is the only currency. Each down you play poker, make your selection, and hit SNAP: a wheel then decides the yards.",
	]},
	{"title": "THE DEAL", "body": [
		"You and the computer each get %d cards from a %d-deck shoe. Tap up to %d of yours to swap, then DRAW." % [QGame.HAND_SIZE, QGame.DECKS, QGame.MAX_DISCARDS],
		"Your hand is the best five of your cards. Its multiplier is set by the poker class: pair x1.1, flush x2.8, quads x5 and so on.",
		"Suit is the play family: RUN, RPO, PASS, SHOT. Rank is the tier: 2-6 bronze, 7-10 silver, J Q K gold, A platinum. Rarer tiers gain more, with more variance.",
		"Hand classes, low to high: high card, pair, two pair, trips, straight, flush, full house, quads, straight flush, five of a kind.",
	]},
	{"title": "WILD CARDS", "body": [
		"Two jokers, PHILLY SPECIAL and FLEA FLICKER, are in the deck.",
		"A joker stands in for any card, so it builds the strongest hand it can: a pair becomes trips, four of a kind becomes five of a kind.",
		"If a joker is part of your best five you may also run it as your play. Trick plays are swingy: big plays, and big risk. As a defensive call a joker is BALANCED.",
	]},
	{"title": "CHOOSE YOUR CARD", "body": [
		"Nothing is preselected. After the draw you must tap a gold card yourself; SNAP stays locked until you do.",
		"The cards in your best five are the ones you may pick: a pair gives you 2 choices, trips 3, and a straight, flush or full house all 5. High card has only its top card.",
		"On OFFENSE the card is your play. Each card shows a + strength and a - weakness: the defense styles it beats and loses to. The wheel previews its odds.",
		"On DEFENSE the SUIT of your card is your style: RUN = BLITZ, RPO = ZONE, PASS = MAN, SHOT = BALANCED.",
	]},
	{"title": "THE WHEEL", "body": [
		"The comparison: the offense wins when its hand beats the defense's. Then the wheel spins a gain (positive yards only) times the offense's hand multiplier.",
		"Otherwise the wheel spins a loss times the DEFENSE's multiplier. If the defense's hand is %d or more classes higher, it is a turnover instead, with no spin." % QGame.PICK_SIX_GAP,
		"Wedges are sized by the play's real odds against the defensive style, so a play that suits the defense has a fatter gain wheel.",
		"Tap (i) on any card, or hold it, for its formation, routes and yards against each defense.",
	]},
	{"title": "READ THE OTHER SIDE", "body": [
		"After the draw, %d of the computer's cards flip face-up." % QGame.FACE_UP,
		"When you are on offense its suit is its defensive style, and the style bends your play's yardage:",
		"@styles",
		"When you are on defense you see what it may run, with each card's weakness (-). Call the style it hates.",
	]},
	{"title": "COUNT THE DECK", "body": [
		"With %d deck%s the shoe is small, so every card you see changes the odds. It reshuffles when under %d cards remain." % [QGame.DECKS, "" if QGame.DECKS == 1 else "s", QGame.RESHUFFLE_AT],
		"The strip under the tells counts the cards you have seen, by rank. Green means richer than average, red means thinner.",
		"If aces and kings are gone, big hands are less likely for both of you.",
	]},
	{"title": "QUANT TIPS", "body": [
		"Your decisions are the draw (what to keep), which card to select, and reading the face-up cards.",
		"A weak play with a big multiplier can beat a strong play with a small one. A strong hand makes your gains bigger and the computer's gains on defense smaller.",
		"Count the deck to guess the computer's hand. If it probably has a monster, protect yourself by drawing for a bigger class.",
		"On defense, choose the style that is the weakness of the play it is most likely running.",
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
