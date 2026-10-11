class_name GameConfig
extends RefCounted
## Backend knobs for the card game, read from res://data/config.json (decks, hand size, discards, face-up tells,
## reshuffle point, drives per side, the turnover gap and the defense-style strength). Missing keys fall back to defaults.

const PATH := "res://data/config.json"
const DEFAULTS := {"decks": 1, "hand_size": 7, "max_discards": 3, "face_up": 2, "reshuffle_at": 20, "drives_per_side": 3,
		"pick_six_gap": 4, "style_strength": 2.0}

static var _data: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_bytes(PATH).get_string_from_utf8())
		if parsed is Dictionary:
			for k in parsed:
				if not String(k).begins_with("_"):
					_data[k] = parsed[k]


static func get_int(key: String, fallback: int = 0) -> int:
	_load()
	return int(_data.get(key, fallback))


static func get_float(key: String, fallback: float = 0.0) -> float:
	_load()
	return float(_data.get(key, fallback))
