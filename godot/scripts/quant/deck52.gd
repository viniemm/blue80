class_name Deck52
extends RefCounted
## 52 unique plays. Suit = play family, rank = quality tier, and each card's curve constants are
## (family baseline) x (rank scaling) x (small per-card personality), so 52 curves need no 52 hand-made tables.

const SUITS := ["RUN", "RPO", "PASS", "SHOT"]
const RANK_LABELS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

# Family baselines at rank "average". Loss sizes are mean extra yards beyond the first.
const BASE := {
	"RUN": {"p_neg": 0.09, "loss": 2.0, "p_to": 0.010, "p_zero": 0.08, "med": 4.6, "sig": 0.70, "p_big": 0.060, "tail": 12.0},
	"RPO": {"p_neg": 0.08, "loss": 2.5, "p_to": 0.014, "p_zero": 0.12, "med": 5.9, "sig": 0.75, "p_big": 0.070, "tail": 13.0},
	"PASS": {"p_neg": 0.07, "loss": 5.5, "p_to": 0.022, "p_zero": 0.20, "med": 8.3, "sig": 0.60, "p_big": 0.070, "tail": 14.0},
	"SHOT": {"p_neg": 0.10, "loss": 6.0, "p_to": 0.035, "p_zero": 0.38, "med": 14.0, "sig": 0.55, "p_big": 0.130, "tail": 18.0},
}


static func tier_of(rank: int) -> String:
	if rank <= 6:
		return "BRONZE"
	if rank <= 10:
		return "SILVER"
	if rank <= 13:
		return "GOLD"
	return "PLATINUM"


## Deterministic jitter in [-1, 1] for (card id, parameter slot).
static func _j(id: int, slot: int) -> float:
	var v: float = sin(float(id) * 12.9898 + float(slot) * 78.233) * 43758.5453
	return (v - floorf(v)) * 2.0 - 1.0


static func theta_for(suit_idx: int, rank: int) -> Dictionary:
	var suit: String = SUITS[suit_idx]
	var b: Dictionary = BASE[suit]
	var id := suit_idx * 13 + (rank - 2)
	var q: float = float(rank - 2) / 12.0
	var mmul := 1.0
	match tier_of(rank):
		"BRONZE": mmul = 0.85 + 0.03 * float(rank - 2)
		"SILVER": mmul = 0.95 + 0.04 * float(rank - 7)
		"GOLD": mmul = 1.00 + 0.05 * float(rank - 11)
		"PLATINUM": mmul = 1.30
	return {
		"p_neg": clampf(float(b.p_neg) * (0.85 + 0.45 * q) * (1.0 + 0.08 * _j(id, 0)), 0.01, 0.30),
		"p_to": clampf(float(b.p_to) * (0.80 + 0.60 * q) * (1.0 + 0.10 * _j(id, 1)), 0.002, 0.10),
		"p_zero": clampf(float(b.p_zero) * (1.0 - 0.10 * q) * (1.0 + 0.08 * _j(id, 2)), 0.02, 0.60),
		"med": float(b.med) * mmul * (1.0 + 0.07 * _j(id, 3)),
		"sig": float(b.sig) * (0.85 + 0.35 * q) * (1.0 + 0.06 * _j(id, 4)),
		"p_big": clampf(float(b.p_big) * (0.35 + 1.9 * pow(q, 1.5)) * (1.0 + 0.10 * _j(id, 5)), 0.0, 0.40),
		"tail": float(b.tail) * (0.8 + 0.5 * q) * (1.0 + 0.06 * _j(id, 6)),
		"loss": float(b.loss) * (1.0 + 0.08 * _j(id, 7)),
	}


const DATA_PATH := "res://data/plays.json"
const JOKER_TIER := "JOKER"

static var _data: Dictionary = {}


## plays.json: formation templates, the 52 plays (name, formation, routes, summary, strength and weakness) and the jokers.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_bytes(DATA_PATH).get_string_from_utf8())
		_data = parsed if parsed is Dictionary else {"formations": {}, "plays": [], "jokers": []}
	return _data


## Style multipliers from a play's own strength and weakness, folded into its curve by DefContext.apply.
static func _aff(strong: String, weak: String) -> Dictionary:
	return {strong: [1.08, 1.14], weak: [0.92, 0.86]}


static func _info(p: Dictionary) -> Dictionary:
	return {"formation": p.formation, "routes": p.routes, "summary": p.summary, "strong": p.strong, "weak": p.weak}


## One deck of 52 plays: {id, suit, suit_name, rank, label, tier, name, theta, info}.
static func build() -> Array:
	var by_key := {}
	for p in data().plays:
		by_key["%s-%d" % [p.suit, int(p.rank)]] = p
	var out: Array = []
	for s in 4:
		for rank in range(2, 15):
			var p: Dictionary = by_key["%s-%d" % [SUITS[s], rank]]
			var theta := theta_for(s, rank)
			theta["aff"] = _aff(p.strong, p.weak)
			out.append({
				"id": s * 13 + (rank - 2), "suit": s, "suit_name": SUITS[s], "rank": rank,
				"label": RANK_LABELS[rank - 2], "tier": tier_of(rank),
				"name": p.name, "theta": theta, "info": _info(p),
			})
	return out


## The two wild cards. They stand in for any card when you build a hand, and are real plays if you run one.
static func jokers() -> Array:
	var out: Array = []
	var i := 0
	for j in data().jokers:
		var theta: Dictionary = (j.theta as Dictionary).duplicate()
		theta["aff"] = _aff(j.strong, j.weak)
		out.append({"id": 52 + i, "suit": 4, "suit_name": "JOKER", "rank": 0, "label": "JK", "tier": JOKER_TIER,
				"name": j.name, "theta": theta, "info": _info(j), "joker": true})
		i += 1
	return out


## All 54 distinct cards: the 52 plays plus the two jokers.
static func build_all() -> Array:
	return build() + jokers()
