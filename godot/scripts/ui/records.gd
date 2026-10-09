class_name RecordsScreen
extends PxScreen
## Lifetime stats from Save, with a two-tap reset.

var _reset: PxButton
var _armed_at := -10.0


func _ready() -> void:
	set_card_alpha(0.22)
	_reset = add_btn("RESET", Px.DIM, Rect2(110, 552, 140, 28), _on_reset)
	add_back("MENU")


func _on_reset() -> void:
	if t - _armed_at < 3.0:
		Save.reset_records()
		_armed_at = -10.0
	else:
		_armed_at = t


func _paint() -> void:
	banner("RECORDS")
	_reset.set_label("TAP AGAIN" if t - _armed_at < 3.0 else "RESET")
	var snaps := int(Save.rec("snaps"))
	var cat := int(Save.rec("best_cat", -1))
	var rows := [
		["RUNS PLAYED", str(int(Save.rec("runs")))],
		["BUSTED", str(int(Save.rec("busts")))],
		["PEAK CHIPS", "%.1f" % float(Save.rec("peak", 0.0))],
		["MOST TD IN A RUN", str(int(Save.rec("best_tds")))],
		["TOTAL TOUCHDOWNS", str(int(Save.rec("tds")))],
		["SNAPS PLAYED", str(snaps)],
		["HANDS WON", "%.1f%%" % (100.0 * float(Save.rec("wins")) / snaps) if snaps > 0 else "-"],
		["BIGGEST SNAP", "%+.1f" % float(Save.rec("biggest", 0.0)) if snaps > 0 else "-"],
		["BEST HAND WON", Poker.CAT_NAMES[cat] if cat >= 0 else "-"],
	]
	var y := 62.0
	for r in rows:
		draw_rect(Rect2(14, y + 17, 332, 1), Px.LINE)
		Px.text(self, 18, y, r[0], 1, Px.DIM)
		Px.text_right(self, 342, y, r[1], 1, Px.GOLD)
		y += 26.0
