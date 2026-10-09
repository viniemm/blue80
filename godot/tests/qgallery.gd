extends SceneTree
## Renders one card of every tier in every suit (mine on top, defense style cards below) for a visual check.
##   godot --path godot --resolution 540x960 -s tests/qgallery.gd -- <out_dir>

func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	DefContext.strength = QGame.STYLE_STRENGTH
	var cards := Deck52.build()
	var holder := Control.new()
	var bg := ColorRect.new()
	bg.color = Px.BG
	bg.size = Vector2(360, 640)
	holder.add_child(bg)
	root.add_child(holder)
	var ranks := [4, 8, 13, 14]            # bronze, silver, gold, platinum
	for row in 4:
		for s in 4:
			var c: Dictionary = cards[s * 13 + (ranks[row] - 2)]
			var v := QCardView.new(c, "mine", row * 4 + s)
			v.position = Vector2(8 + s * 86, 6 + row * 96)
			holder.add_child(v)
	for row in 4:
		for s in 4:
			var c: Dictionary = cards[s * 13 + (ranks[row] - 2)]
			var d := QCardView.new(c, "theirs", row * 4 + s)
			d.position = Vector2(8 + s * 86, 400 + row * 58)
			holder.add_child(d)
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/gallery.png" % out_dir)
	print("saved gallery")
	quit()
