extends SceneTree
## ANA-GAME-003-A-FIX-01: renders a preview scene from named viewpoints into a SubViewport (any size, MSAA).
## Needs a real rendering backend (not --headless). Only the preview Camera3D moves; the vehicle is never touched.
##   godot --path <project> --rendering-driver opengl3 --script res://tests/validation/capture_vehicle_views.gd -- \
##     scene=res://scenes/validation/ana_vehicle_glb_preview.tscn out=res://validation/ana-game-003-a/x/ w=1400 h=1075 msaa=4 views=blender_34,blender_side

## name -> [position, target, fov (perspective) or ortho height (orthographic), orthographic?]
## blender_* views mirror ana_veiculo_render_v02.py (Blender Z-up -> Godot: x, z, -y).
const VIEWS := {
	"blender_34": [Vector3(1.499, 0.618, -1.171), Vector3(0.0, 0.265, 0.0), 26.0, false],
	"blender_side": [Vector3(3.0, 0.29, 0.0), Vector3(0.0, 0.29, 0.0), 0.768, true],
	"blender_front": [Vector3(0.0, 0.29, -3.0), Vector3(0.0, 0.29, 0.0), 0.63, true],
	"blender_rear": [Vector3(0.0, 0.29, 3.0), Vector3(0.0, 0.29, 0.0), 0.63, true],
	"vehicle_front": [Vector3(0, 0.38, -1.7), Vector3(0, 0.29, 0), 30.0, false],
	"vehicle_rear": [Vector3(0, 0.38, 1.7), Vector3(0, 0.29, 0), 30.0, false],
	"vehicle_left": [Vector3(-1.7, 0.33, 0), Vector3(0, 0.29, 0), 30.0, false],
	"vehicle_right": [Vector3(1.7, 0.33, 0), Vector3(0, 0.29, 0), 30.0, false],
	"vehicle_three_quarter": [Vector3(-1.05, 0.62, -1.15), Vector3(0, 0.27, 0), 32.0, false],
	"vehicle_wheel_detail": [Vector3(-0.75, 0.28, -0.75), Vector3(-0.1425, 0.13, -0.25), 30.0, false],
	"vehicle_handlebar_seat": [Vector3(0.85, 0.6, -0.7), Vector3(0, 0.38, -0.05), 30.0, false],
	"seat_detail": [Vector3(0.55, 0.6, 0.55), Vector3(0, 0.3, 0.1), 24.0, false],
}

var _failures := 0


func _initialize() -> void:
	_run()


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return default


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[NOT VERIFIED] screenshots - GUI capture required (running headless)")
		quit(2)
		return
	var scene_path := _arg("scene", "res://scenes/validation/ana_vehicle_glb_preview.tscn")
	var out_dir := ProjectSettings.globalize_path(_arg("out", "res://validation/ana-game-003-a/screenshots_refined/"))
	var size := Vector2i(int(_arg("w", "1400")), int(_arg("h", "1075")))
	var msaa := int(_arg("msaa", "4"))
	var names := _arg("views", "blender_34").split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}[msaa]
	get_root().add_child(vp)
	var scene := (load(scene_path) as PackedScene).instantiate() as Node3D
	vp.add_child(scene)
	var cam := scene.get_node("Camera3D") as Camera3D
	print("scene=", scene_path, " renderer=", ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			" adapter=", RenderingServer.get_video_adapter_name(), " size=", size, " msaa=", msaa)
	for view_name in names:
		var v: Array = VIEWS[view_name]
		if v[3]:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = v[2]
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1], Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path: String = out_dir + view_name + ".png"
		var err := img.save_png(path)
		var back := Image.load_from_file(path)
		var ok := err == OK and back != null and back.get_width() == size.x and FileAccess.get_file_as_bytes(path).size() > 1000
		var c0 := back.get_pixel(size.x / 2, size.y / 2) if back else Color.BLACK
		var varied := false
		if back:
			for i in 60:
				var px := back.get_pixel((i * 97) % size.x, (i * 53) % size.y)
				if absf(px.r - c0.r) + absf(px.g - c0.g) + absf(px.b - c0.b) > 0.1:
					varied = true
		print("[%s] %s %dx%d bytes=%d varied=%s" % ["PASS" if ok and varied else "FAIL", path, img.get_width(), img.get_height(),
				FileAccess.get_file_as_bytes(path).size(), varied])
		if not (ok and varied):
			_failures += 1
	quit(1 if _failures > 0 else 0)
