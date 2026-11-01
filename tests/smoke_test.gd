extends SceneTree
## Automated headless gameplay checks for ANA-GAME-001.
## Run: godot --headless --path <project> --script res://tests/smoke_test.gd
## Simulates input through the real Input pipeline; does NOT validate rendering or real mouse/keyboard.

var _failures := 0
var _main: Node
var _player: CharacterBody3D
var _rig: Node3D
var _yaw: Node3D
var _pitch: Node3D


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_player = _main.get_node("Player")
	_rig = _main.get_node("ThirdPersonCamera")
	_yaw = _rig.get_node("YawPivot")
	_pitch = _rig.get_node("YawPivot/PitchPivot")
	var camera: Camera3D = _rig.get_node("YawPivot/PitchPivot/SpringArm3D/Camera3D")

	await _frames(90)
	_check("player is CharacterBody3D", _player is CharacterBody3D)
	_check("player lands on ground", _player.is_on_floor() and absf(_player.global_position.y) < 0.02,
			"y=%.3f" % _player.global_position.y)
	_check("camera is current", camera.current)
	_check("camera above and behind player", camera.global_position.y > 0.8 and camera.global_position.z > 1.0,
			str(camera.global_position))

	# Forward (camera yaw 0 => -Z)
	var start := _player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	_check("W moves forward (-Z)", _player.global_position.z < start.z - 1.0,
			"dz=%.2f" % (_player.global_position.z - start.z))
	_check("speed reaches move_speed", absf(_horizontal_speed() - 2.5) < 0.05, "v=%.3f" % _horizontal_speed())

	# Diagonal normalization
	Input.action_press("move_right")
	await _frames(60)
	_check("diagonal normalized", _horizontal_speed() <= 2.55, "v=%.3f" % _horizontal_speed())
	Input.action_release("move_forward")
	Input.action_release("move_right")
	await _frames(40)
	_check("deceleration stops player", _horizontal_speed() < 0.01, "v=%.3f" % _horizontal_speed())

	# Jump
	var max_y := 0.0
	var jump_event := InputEventAction.new()
	jump_event.action = "jump"
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	var second := false
	for i in 90:
		await physics_frame
		max_y = maxf(max_y, _player.global_position.y)
		if i == 15 and not second:
			second = true
			Input.parse_input_event(jump_event)  # midair attempt must be ignored
	var release_event := InputEventAction.new()
	release_event.action = "jump"
	release_event.pressed = false
	Input.parse_input_event(release_event)
	_check("jump leaves ground", max_y > 0.4, "max_y=%.3f" % max_y)
	_check("no midair double jump", max_y < 0.7, "max_y=%.3f (expected ~0.62)" % max_y)
	_check("lands after jump", _player.is_on_floor() and absf(_player.global_position.y) < 0.02,
			"y=%.3f" % _player.global_position.y)

	# Mouse capture and look
	# Headless DisplayServer does not keep MOUSE_MODE_CAPTURED, so capture/release/click
	# behavior is NOT VERIFIED here (needs interactive F5). Look math is tested directly.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var capture_ok := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("[NOT VERIFIED] mouse capture/release/click state (headless cannot hold captured mode)" if not capture_ok
			else "[INFO] mouse capture available; verifying capture flow")
	if true:
		var yaw0 := _yaw.rotation.y
		_rig._rotate_view(Vector2(300, 0))
		await physics_frame
		_check("mouse X rotates yaw", absf(_yaw.rotation.y - yaw0) > 0.3, "dyaw=%.3f" % (_yaw.rotation.y - yaw0))

		# Camera-relative movement after yaw change
		await _frames(5)
		var cam_fwd := -camera.global_basis.z
		cam_fwd.y = 0.0
		cam_fwd = cam_fwd.normalized()
		var p0 := _player.global_position
		Input.action_press("move_forward")
		await _frames(40)
		Input.action_release("move_forward")
		var moved := _player.global_position - p0
		moved.y = 0.0
		_check("W follows camera forward after yaw", moved.normalized().dot(cam_fwd) > 0.95,
				"dot=%.3f" % moved.normalized().dot(cam_fwd))
		await _frames(30)

		# Pitch clamp
		for i in 3:
			_rig._rotate_view(Vector2(0, 5000))
			await physics_frame
		_check("pitch clamped (lower bound)", _pitch.rotation.x >= deg_to_rad(-70.0) - 0.001,
				"pitch=%.1f" % rad_to_deg(_pitch.rotation.x))
		for i in 3:
			_rig._rotate_view(Vector2(0, -5000))
			await physics_frame
		_check("pitch clamped (upper bound)", _pitch.rotation.x <= deg_to_rad(10.0) + 0.001,
				"pitch=%.1f" % rad_to_deg(_pitch.rotation.x))
		_check("no roll", absf(_pitch.rotation.z) < 0.0001 and absf(_yaw.rotation.z) < 0.0001)

		# Escape releases, motion ignored, click recaptures (only meaningful if capture works)
		if capture_ok:
			await _check_capture_flow()

	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check_capture_flow() -> void:
	if true:
		var esc := InputEventAction.new()
		esc.action = "release_mouse"
		esc.pressed = true
		Input.parse_input_event(esc)
		await physics_frame
		_check("release_mouse releases cursor", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		var yaw1 := _yaw.rotation.y
		var m3 := InputEventMouseMotion.new()
		m3.screen_relative = Vector2(300, 0)
		Input.parse_input_event(m3)
		await physics_frame
		_check("camera ignores motion while released", is_equal_approx(_yaw.rotation.y, yaw1))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		await physics_frame
		_check("click recaptures cursor", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
