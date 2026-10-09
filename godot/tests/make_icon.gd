extends SceneTree
## Draws the app icon into res://icon.png (512x512): the Blue 80 wordmark and a football. Used as the project icon
## and, on the web build, as the home-screen icon.
##   godot --path godot --resolution 540x960 -s tests/make_icon.gd

class IconArt extends Control:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 512, 512), Px.BG)
		for i in 8:
			draw_rect(Rect2(0, i * 80 - 20, 512, 40), Color(Px.PANEL2, 0.5))
		var px := 112
		var x0 := 256.0 - 2.0 * px
		var y := 96.0
		for i in 4:
			var ch := "BLUE"[i]
			Px.big(self, x0 + i * px + 6, y + 6, ch, px, Color("1c2f8f"))
			Px.big(self, x0 + i * px, y, ch, px, Px.FG)
		var x1 := 256.0 - 1.0 * px
		for i in 2:
			var ch := "80"[i]
			Px.big(self, x1 + i * px + 6, y + px + 22, ch, px, Color("8a1c1c"))
			Px.big(self, x1 + i * px, y + px + 16, ch, px, Px.GOLD)
		draw_rect(Rect2(60, 392, 392, 8), Px.GOLD)
		draw_rect(Rect2(60, 406, 392, 3), Px.RED)
		var k := 6
		var ox := 256.0 - 7.5 * k
		for ry in PxScreen.BALL.size():
			var row: String = PxScreen.BALL[ry]
			for rx in row.length():
				var chr := row[rx]
				if chr != "0":
					draw_rect(Rect2(ox + rx * k, 420 + ry * k, k, k), PxScreen.BALL_COLORS[chr])


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var art := IconArt.new()
	art.size = Vector2(512, 512)
	vp.add_child(art)
	for i in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("res://icon.png")
	print("saved icon.png ", img.get_size())
	quit()
