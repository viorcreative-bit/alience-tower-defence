extends SceneTree

# Bina ve kule kartlarındaki küçük resimleri modellerden çizer (assets/thumbs/*.png).
# Kullanım (ekranlı ortam gerekir): godot --rendering-driver opengl3 --script tools/render_thumbs.gd
const D := preload("res://scripts/data.gd")
const SIZE := 192


func _initialize() -> void:
	_run()


func _run() -> void:
	var models := Models.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.85, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var items := []
	for id in D.BUILDING_ORDER:
		items.append(["b_" + id, models.building(id, 2)])
	for t in D.TOWER_ORDER:
		items.append(["t_" + t, models.tower(t, 2).root])
	for it in items:
		var n: Node3D = it[1]
		vp.add_child(n)
		await process_frame
		# modelin kutusuna göre kamerayı uzaklaştır
		var box := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree():
				continue
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var r := box.size.length() / 2.0
		var dist := r / sin(deg_to_rad(cam.fov / 2.0)) * 0.92
		var c := box.get_center()
		cam.look_at_from_position(c + Vector3(1.0, 0.85, 1.3).normalized() * dist, c)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://assets/thumbs/%s.png" % it[0])
		print("çizildi ", it[0])
		n.queue_free()
		await process_frame
	quit()
