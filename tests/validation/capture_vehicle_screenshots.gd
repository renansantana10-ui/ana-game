extends SceneTree
## ANA-GAME-003-A: renders the isolated GLB preview scene from fixed viewpoints and saves PNGs.
## Needs a real rendering backend (NOT --headless):
##   godot --path <project> --rendering-driver opengl3 --resolution 1280x720 --script res://tests/validation/capture_vehicle_screenshots.gd
## Only moves the preview Camera3D; the imported vehicle is never transformed.

const PREVIEW_SCENE := "res://scenes/validation/ana_vehicle_glb_preview.tscn"
const OUT_DIR := "res://validation/ana-game-003-a/screenshots/"

## name -> [camera position, look-at target, fov]. Vehicle front is -Z, its left side is -X.
const VIEWS := {
	"vehicle_front": [Vector3(0, 0.38, -1.7), Vector3(0, 0.29, 0), 30.0],
	"vehicle_rear": [Vector3(0, 0.38, 1.7), Vector3(0, 0.29, 0), 30.0],
	"vehicle_left": [Vector3(-1.7, 0.33, 0), Vector3(0, 0.29, 0), 30.0],
	"vehicle_right": [Vector3(1.7, 0.33, 0), Vector3(0, 0.29, 0), 30.0],
	"vehicle_three_quarter": [Vector3(-1.05, 0.62, -1.15), Vector3(0, 0.27, 0), 32.0],
	"vehicle_wheel_detail": [Vector3(-0.75, 0.28, -0.75), Vector3(-0.1425, 0.13, -0.25), 30.0],
	"vehicle_handlebar_seat": [Vector3(0.85, 0.6, -0.7), Vector3(0, 0.38, -0.05), 30.0],
}

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[NOT VERIFIED] screenshots - GUI capture required (running headless)")
		quit(2)
		return
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var scene := (load(PREVIEW_SCENE) as PackedScene).instantiate() as Node3D
	get_root().add_child(scene)
	var cam := scene.get_node("Camera3D") as Camera3D
	print("renderer=", ProjectSettings.get_setting("rendering/renderer/rendering_method"), " adapter=",
			RenderingServer.get_video_adapter_name(), " viewport=", get_root().size)
	for view_name in VIEWS:
		var v: Array = VIEWS[view_name]
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1], Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		var path: String = dir + view_name + ".png"
		var err := img.save_png(path)
		var back := Image.load_from_file(path)
		var ok := err == OK and back != null and back.get_width() > 0 and FileAccess.get_file_as_bytes(path).size() > 1000
		# Sanity: the frame must not be a single flat color.
		var c0 := back.get_pixel(back.get_width() / 2, back.get_height() / 2) if back else Color.BLACK
		var varied := false
		if back:
			for i in 40:
				var px := back.get_pixel((i * 97) % back.get_width(), (i * 53) % back.get_height())
				if absf(px.r - c0.r) + absf(px.g - c0.g) + absf(px.b - c0.b) > 0.1:
					varied = true
		print("[%s] %s %dx%d bytes=%d varied=%s" % ["PASS" if ok and varied else "FAIL", path, img.get_width(), img.get_height(),
				FileAccess.get_file_as_bytes(path).size(), varied])
		if not (ok and varied):
			_failures += 1
	quit(1 if _failures > 0 else 0)
