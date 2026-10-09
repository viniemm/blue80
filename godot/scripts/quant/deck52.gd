class_name Deck52
extends RefCounted
## 52 unique plays. Suit = play family, rank = quality tier, and each card's curve constants are
## (family baseline) x (rank scaling) x (small per-card personality), so 52 curves need no 52 hand-made tables.

const SUITS := ["RUN", "RPO", "PASS", "SHOT"]
const RANK_LABELS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

const NAMES := {
	"RUN": ["QB SNEAK", "FB DIVE", "DRAW", "COUNTER", "TRAP", "INSIDE ZONE", "OUTSIDE ZONE", "POWER O", "STRETCH",
			"TOSS SWEEP", "ISO LEAD", "COUNTER TREY", "JET SWEEP"],
	"RPO": ["RPO SLANT", "RPO BUBBLE", "RPO FLAT", "READ OPTION", "ZONE READ", "INVERTED VEER", "SPEED OPTION",
			"TRIPLE OPTION", "PACKAGED HITCH", "RPO GLANCE", "RPO SEAM", "OPTION PASS", "FULL FLOW"],
	"PASS": ["DUMP OFF", "SWING", "HITCH", "STICK", "CURL FLAT", "SLANTS", "MESH", "SMASH", "DAGGER", "FLOOD", "DIG",
			"CORNER", "LEVELS"],
	"SHOT": ["FADE", "BACK SHOULDER", "GO ROUTE", "PA BOOT", "PA POST", "CORNER POST", "WHEEL", "SEAM SHOT",
			"DOUBLE MOVE", "PA DEEP OVER", "FOUR VERTS", "POST WHEEL", "MOON SHOT"],
}

# Family baselines at rank "average". Loss sizes are mean extra yards beyond the first.
const BASE := {
	"RUN": {"p_neg": 0.09, "loss": 2.0, "p_to": 0.012, "p_zero": 0.10, "med": 3.4, "sig": 0.65, "p_big": 0.035, "tail": 12.0},
	"RPO": {"p_neg": 0.08, "loss": 2.5, "p_to": 0.016, "p_zero": 0.12, "med": 4.0, "sig": 0.75, "p_big": 0.050, "tail": 13.0},
	"PASS": {"p_neg": 0.08, "loss": 5.5, "p_to": 0.022, "p_zero": 0.22, "med": 6.5, "sig": 0.60, "p_big": 0.060, "tail": 14.0},
	"SHOT": {"p_neg": 0.11, "loss": 6.0, "p_to": 0.035, "p_zero": 0.42, "med": 14.0, "sig": 0.55, "p_big": 0.140, "tail": 18.0},
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
		"BRONZE": mmul = 0.80 + 0.04 * float(rank - 2)
		"SILVER": mmul = 1.05 + 0.05 * float(rank - 7)
		"GOLD": mmul = 1.35 + 0.07 * float(rank - 11)
		"PLATINUM": mmul = 1.90
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


## All 52 cards: {id, suit, suit_name, rank, label, tier, name, theta}.
static func build() -> Array:
	var out: Array = []
	for s in 4:
		for rank in range(2, 15):
			out.append({
				"id": s * 13 + (rank - 2), "suit": s, "suit_name": SUITS[s], "rank": rank,
				"label": RANK_LABELS[rank - 2], "tier": tier_of(rank),
				"name": NAMES[SUITS[s]][rank - 2], "theta": theta_for(s, rank),
			})
	return out
