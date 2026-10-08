class_name Cards
extends RefCounted
## Play cards, poker-style sequence combos, and joker modifiers.
## Combos look at the sequence of plays in the drive (the last two plus the card being played).

const SUIT_COLORS := {
	"RUN": Color("3fd07a"), "QUICK": Color("33c8ff"), "MID": Color("6f8cff"),
	"DEEP": Color("ff4d4d"), "PA": Color("ffcc33"), "SCREEN": Color("c78bff"),
}
const SUIT_ICONS := {
	"RUN": ["00100", "00010", "11111", "00010", "00100"],
	"QUICK": ["00011", "00110", "01110", "00110", "01100"],
	"MID": ["00100", "01110", "11111", "01110", "00100"],
	"DEEP": ["00100", "01110", "10101", "00100", "00100"],
	"PA": ["01010", "11111", "11111", "01110", "00100"],
	"SCREEN": ["11111", "10001", "10101", "10001", "11111"],
}
const SHORT_NAMES := {
	"IZS": "INSIDE ZONE", "OZS": "STRETCH", "PWO": "POWER O", "CTR": "COUNTER", "DRW": "DRAW",
	"SLN": "SLANTS", "STK": "STICK", "SMH": "SMASH", "MSH": "MESH", "SAL": "FLOOD", "DAG": "DAGGER",
	"PAB": "PA BOOT", "PAP": "PA POST", "4VT": "4 VERTS", "HBS": "SCREEN", "HMY": "HAIL MARY",
}
const STARTER_DECK := ["IZS", "OZS", "PWO", "DRW", "SLN", "STK", "SMH", "MSH", "PAB", "PAP", "4VT", "HBS"]


static func suit_of(play: Dictionary) -> String:
	match play.category:
		"RUN_INSIDE_ZONE", "RUN_OUTSIDE_ZONE", "RUN_POWER_GAP", "RUN_DRAW_TRAP", "RUN_OPTION_VEER":
			return "RUN"
		"PASS_QUICK_GAME":
			return "QUICK"
		"PASS_MESH_DRAG", "PASS_INTERMEDIATE", "PASS_AIR_RAID":
			return "MID"
		"PASS_DEEP_SHOT", "PASS_HAIL_MARY":
			return "DEEP"
		"PASS_PLAY_ACTION", "RPO_PACKAGES":
			return "PA"
		"PASS_SCREEN":
			return "SCREEN"
	return "MID"


static func rank_of(play: Dictionary) -> int:
	return clampi(int(round(float(play.aggressiveness) * 10.0)), 1, 10)


static func make_card(code: String, uid: int, D: Dictionary) -> Dictionary:
	var play: Dictionary = D.plays[code]
	return {"uid": uid, "code": code, "suit": suit_of(play), "rank": rank_of(play),
			"name": SHORT_NAMES.get(code, String(play.name).to_upper())}


# ------------------------------------------------------------------ tilts
static func neutral() -> Dictionary:
	return {"run_fit": 0.0, "pressure": 0.0, "sep_short": 0.0, "sep_deep": 0.0, "sep_all": 0.0, "comp_logit": 0.0,
			"int_logit": 0.0, "fumble_mult": 1.0, "run_yards_mult": 1.0, "yac_mult": 1.0}


static func merge(into: Dictionary, add: Dictionary) -> void:
	for k in add:
		if k in ["fumble_mult", "run_yards_mult", "yac_mult"]:
			into[k] = float(into[k]) * float(add[k])
		else:
			into[k] = float(into[k]) + float(add[k])


# ------------------------------------------------------------------ combos
## history: already-played cards (oldest first). Returns [{kind, name, text, tilt}].
static func combos(history: Array, card: Dictionary) -> Array:
	var out: Array = []
	var prev: Dictionary = history[history.size() - 1] if history.size() >= 1 else {}
	var prev2: Dictionary = history[history.size() - 2] if history.size() >= 2 else {}
	if not prev.is_empty() and prev.suit == card.suit:
		if not prev2.is_empty() and prev2.suit == card.suit:
			out.append({"kind": "TRIPS", "name": "TRIPS", "text": "Big rhythm, but the defense reads it",
					"tilt": {"comp_logit": 0.5, "run_fit": 0.45}})
		else:
			out.append({"kind": "PAIR", "name": "PAIR", "text": "Same family twice: rhythm",
					"tilt": {"comp_logit": 0.25, "run_fit": 0.2}})
	if not prev.is_empty() and not prev2.is_empty():
		if prev.suit != card.suit and prev2.suit != card.suit and prev.suit != prev2.suit:
			out.append({"kind": "STRAIGHT", "name": "STRAIGHT", "text": "Three families: can't key on you",
					"tilt": {"sep_all": 0.3, "comp_logit": 0.15, "run_fit": 0.15}})
		if prev2.rank < prev.rank and prev.rank < card.rank:
			out.append({"kind": "BUILD", "name": "BUILD-UP", "text": "Escalating calls: more YAC",
					"tilt": {"run_yards_mult": 1.15, "yac_mult": 1.25, "comp_logit": 0.2}})
	if not prev.is_empty() and prev.suit == "RUN" and card.suit in ["PA", "DEEP"]:
		out.append({"kind": "SETUP", "name": "RUN FAKE", "text": "Run sets up the shot",
				"tilt": {"pressure": -0.5, "sep_deep": 0.4}})
	return out


## Scouting lean in [-1, 1] from the drive's recent plays (+ = run-heavy).
static func run_lean(history: Array) -> float:
	var recent: Array = history.slice(maxi(0, history.size() - 3))
	if recent.size() < 2:
		return 0.0
	var runs := 0
	for c in recent:
		if c.suit == "RUN":
			runs += 1
	return clampf((float(runs) - float(recent.size() - runs)) / float(recent.size()), -1.0, 1.0)


# ------------------------------------------------------------------ jokers
const JOKERS := {
	"IRON": {"name": "IRON LINE", "text": "LESS PRESSURE", "tilt": {"pressure": -0.6}},
	"DOWNHILL": {"name": "DOWNHILL", "text": "RUNS HIT HARDER", "tilt": {"run_fit": 0.35, "run_yards_mult": 1.1}},
	"GUN": {"name": "GUNSLINGER", "text": "DEEP OPEN, MORE INT", "tilt": {"sep_deep": 0.5, "int_logit": 0.4}},
	"GLUE": {"name": "GLUE HANDS", "text": "FUMBLES -80%", "tilt": {"fumble_mult": 0.2}},
	"SPEED": {"name": "SPEED KILLS", "text": "BIG YAC", "tilt": {"yac_mult": 1.3, "sep_short": 0.3}},
	"CHAIN": {"name": "CHAIN MOVER", "text": "3RD/4TH BOOST", "tilt": {}, "when": "late_down",
			"extra": {"comp_logit": 0.35, "run_fit": 0.3}},
	"REDZONE": {"name": "RED ZONE KING", "text": "OPP 20 BOOST", "tilt": {}, "when": "red_zone",
			"extra": {"comp_logit": 0.5, "run_fit": 0.4}},
	"TAPE": {"name": "TAPE STUDY", "text": "SHARPER CURVE", "tilt": {}, "curve_sigma": 0.55},
}


static func joker_tilt(joker_ids: Array, st: Dictionary) -> Dictionary:
	var t := neutral()
	for id in joker_ids:
		var j: Dictionary = JOKERS[id]
		merge(t, j.tilt)
		if j.get("when", "") == "late_down" and st.down >= 3:
			merge(t, j.extra)
		if j.get("when", "") == "red_zone" and st.yardline_to_opponent_goal <= 20.0:
			merge(t, j.extra)
	return t


static func curve_sigma(joker_ids: Array, combo_list: Array) -> float:
	var s := 0.85
	for id in joker_ids:
		s = minf(s, float(JOKERS[id].get("curve_sigma", 0.85)))
	for c in combo_list:
		if c.kind == "STRAIGHT":
			s = 1.2
	return s
