class_name GameData
extends RefCounted
## Loads rosters, playbooks and the scheme matrix from res://data.


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return null
	return JSON.parse_string(f.get_as_text())


static func load_all() -> Dictionary:
	var off_plays: Array = load_json("res://data/core_offense.json").plays
	var plays := {}
	for p in off_plays:
		plays[p.call_id] = p
	var dj: Dictionary = load_json("res://data/core_defense.json")
	var defs := {}
	for d in dj.plays:
		defs[d.code] = d
	return {
		"plays": plays,
		"defense": defs,
		"defense_order": dj.plays.map(func(d): return d.code),
		"tier_labels": dj.tier_labels,
		"matrix": Sim.index_matrix(load_json("res://data/scheme_matrix.json")),
		"east": Sim.build_team(load_json("res://data/east.json").players),
		"west": Sim.build_team(load_json("res://data/west.json").players),
	}
