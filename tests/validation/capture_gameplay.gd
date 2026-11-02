extends SceneTree
## ANA-GAME-003-B: real-scene screenshots of the official vehicle in the farm (needs a real window).
##   godot --path <project> --rendering-driver opengl3 --resolution 1280x720 --script res://tests/validation/capture_gameplay.gd
## Drives the real main scene through the real input actions and photographs it with an extra capture camera
## (and with the game's own third-person camera). Nothing in the game is modified.

const OUT := "res://validation/ana-game-003-b/screenshots/"

var _main: Node
var _player: PlayerController
var _vehicle: VehicleController
var _interaction: VehicleInteraction
var _game_cam: Camera3D
var _cam: Camera3D
var _failures := 0


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT) + shot_name + ".png"
	var ok := img.save_png(path) == OK and FileAccess.get_file_as_bytes(path).size() > 1000
	print("[%s] %s %dx%d" % ["PASS" if ok else "FAIL", path, img.get_width(), img.get_height()])
	if not ok:
		_failures += 1


## Capture camera placed in the vehicle's frame: offset (right, up, back) relative to its origin.
func _cam_on_vehicle(offset: Vector3, look_local: Vector3, fov: float = 40.0) -> void:
	_cam.fov = fov
	var from := _vehicle.global_transform * offset
	var to := _vehicle.global_transform * look_local
	_cam.look_at_from_position(from, to, Vector3.UP)
	_cam.make_current()


func _place_vehicle(x: float, z: float, yaw: float) -> void:
	_vehicle.velocity = Vector3.ZERO
	_vehicle.speed = 0.0
	_vehicle.lateral = 0.0
	_vehicle.drift_amount = 0.0
	_vehicle.steer = 0.0
	_vehicle.global_position = Vector3(x, FarmLayout.height_at(x, z) + 0.03, z)
	_vehicle.global_rotation = Vector3(0.0, yaw, 0.0)
	await _frames(25)


func _space(pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[NOT VERIFIED] gameplay screenshots - GUI capture required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(_main)
	_player = _main.get_node("Player")
	_vehicle = _main.get_node("RideOnVehicle")
	_interaction = _main.get_node("VehicleInteraction")
	_game_cam = _main.get_node("ThirdPersonCamera/YawPivot/PitchPivot/SpringArm3D/Camera3D")
	_cam = Camera3D.new()
	_main.add_child(_cam)
	await _frames(60)
	print("renderer=", ProjectSettings.get_setting("rendering/renderer/rendering_method"), " adapter=", RenderingServer.get_video_adapter_name())

	# 1. Parked, on foot: official vehicle in the farm, then the placeholder is gone.
	_cam_on_vehicle(Vector3(-1.0, 0.65, -1.15), Vector3(0, 0.27, 0), 32.0)
	await _shot("01_parked_front_left")
	_cam_on_vehicle(Vector3(1.3, 0.5, 0.9), Vector3(0, 0.27, 0), 32.0)
	await _shot("02_parked_rear_right")
	_game_cam.make_current()
	await _shot("03_game_camera_on_foot")

	# 2. Mount with the real E key; seated placeholder close-ups.
	_player.global_position = _vehicle.global_position + Vector3(1.3, 0.1, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	await _tap("interact")
	await _frames(10)
	print("mounted=", _interaction.is_mounted())
	_cam_on_vehicle(Vector3(-1.25, 0.45, 0.0), Vector3(0, 0.36, 0), 28.0)
	await _shot("04_mounted_side_left")
	_cam_on_vehicle(Vector3(-0.95, 0.75, -1.1), Vector3(0, 0.38, 0), 32.0)
	await _shot("05_mounted_front_left")
	_cam_on_vehicle(Vector3(0.0, 0.75, 1.4), Vector3(0, 0.38, 0), 30.0)
	await _shot("06_mounted_rear")
	_game_cam.make_current()
	await _shot("07_game_camera_mounted")

	# 3. Driving with real keys: turn left (wheels + handlebar), game camera.
	await _place_vehicle(28.0, -14.0, -PI / 2.0)
	Input.action_press("move_forward")
	await _frames(100)
	Input.action_press("move_left")
	await _frames(25)
	_cam_on_vehicle(Vector3(-1.1, 0.7, -1.3), Vector3(0, 0.3, 0), 36.0)
	await _shot("08_driving_turn_left_close")
	_game_cam.make_current()
	await _shot("09_game_camera_turning")
	Input.action_release("move_left")

	# 4. Drift (real Space) from the game camera and a close camera.
	await _frames(40)
	_space(true)
	Input.action_press("move_right")
	await _frames(30)
	print("drift_amount=", _vehicle.drift_amount, " lateral=", _vehicle.lateral)
	_cam_on_vehicle(Vector3(1.3, 0.8, -1.4), Vector3(0, 0.3, 0), 40.0)
	await _shot("10_drift_close")
	_game_cam.make_current()
	await _shot("11_game_camera_drift")
	_space(false)
	Input.action_release("move_right")
	Input.action_release("move_forward")

	# 5. Ramp: take-off and landing.
	await _place_vehicle(33.0, 0.0, -PI / 2.0)
	Input.action_press("move_forward")
	var air_shot := false
	for i in 220:
		await _frames(1)
		if not air_shot and not _vehicle.is_on_floor() and _vehicle.global_position.y > 1.0:
			_cam_on_vehicle(Vector3(-2.2, 0.5, -0.3), Vector3(0, 0.2, 0), 40.0)
			await _shot("12_ramp_airborne_side")
			_game_cam.make_current()
			await _shot("13_game_camera_airborne")
			air_shot = true
			break
	Input.action_release("move_forward")
	print("airborne_shot=", air_shot)

	# 6. Hill (west) with the game camera.
	await _place_vehicle(-50.0, 0.0, PI / 2.0)
	Input.action_press("move_forward")
	await _frames(150)
	_cam_on_vehicle(Vector3(-1.4, 0.7, 0.9), Vector3(0, 0.3, 0), 36.0)
	await _shot("14_hill_close")
	_game_cam.make_current()
	await _shot("15_game_camera_hill")
	Input.action_release("move_forward")
	await _frames(120)

	# 7. Dismount and walk.
	await _tap("interact")
	await _frames(10)
	print("dismounted=", not _interaction.is_mounted())
	_game_cam.make_current()
	await _shot("16_dismounted_on_foot")
	quit(1 if _failures > 0 else 0)
