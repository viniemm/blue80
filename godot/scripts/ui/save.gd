class_name Save
extends RefCounted
## Records and settings, kept in user://blue80.cfg.

const PATH := "user://blue80.cfg"

static var _cf: ConfigFile


static func _c() -> ConfigFile:
	if _cf == null:
		_cf = ConfigFile.new()
		_cf.load(PATH)                       # a missing file is fine: everything has a default
	return _cf


static func rec(key: String, default: Variant = 0) -> Variant:
	return _c().get_value("records", key, default)


static func set_rec(key: String, v: Variant) -> void:
	_c().set_value("records", key, v)


static func setting(key: String, default: Variant = true) -> Variant:
	return _c().get_value("settings", key, default)


static func set_setting(key: String, v: Variant) -> void:
	_c().set_value("settings", key, v)
	flush()


static func flush() -> void:
	_c().save(PATH)


## Fold one finished (or abandoned) run into the lifetime records. Empty runs are ignored.
static func commit_run(g: QGame) -> void:
	if g.history.is_empty():
		return
	var wins := 0
	var biggest := 0.0
	for h in g.history:
		wins += 1 if h.win == 1 else 0
		biggest = maxf(biggest, float(h.delta))
	set_rec("runs", int(rec("runs")) + 1)
	set_rec("busts", int(rec("busts")) + (1 if g.phase == "OVER" else 0))
	set_rec("snaps", int(rec("snaps")) + g.history.size())
	set_rec("wins", int(rec("wins")) + wins)
	set_rec("tds", int(rec("tds")) + g.tds)
	set_rec("best_tds", maxi(int(rec("best_tds")), g.tds))
	set_rec("peak", maxf(float(rec("peak", 0.0)), g.peak))
	set_rec("biggest", maxf(float(rec("biggest", 0.0)), biggest))
	set_rec("best_cat", maxi(int(rec("best_cat", -1)), g.best_cat))
	flush()


static func reset_records() -> void:
	_c().erase_section("records")
	flush()
