class_name DefContext
extends RefCounted
## Hidden defensive "style" that bends a play's curve. The house prices the average over all styles and does not
## see which one is in play; a player who reads the defense (face-up cards, history) can. Each entry multiplies
## the curve constants, raised to `strength` (1 = base effect, 2 = twice as strong in log terms).

const STYLES := ["BALANCED", "BLITZ", "ZONE", "MAN"]

const MODS := {
	"BALANCED": {},
	"BLITZ": {"p_neg": 1.6, "p_to": 1.4, "med": 0.92, "p_big": 1.35, "tail": 1.10},
	"ZONE": {"p_neg": 0.8, "p_zero": 1.15, "med": 0.95, "p_big": 0.7},
	"MAN": {"p_neg": 1.1, "p_zero": 0.9, "med": 1.05, "p_big": 1.15},
}

static var strength := 1.0


static func apply(theta: Dictionary, style: String) -> Dictionary:
	var out := theta.duplicate()
	var mods: Dictionary = MODS[style]
	for k in mods:
		out[k] = float(out[k]) * pow(float(mods[k]), strength)
	return out
