extends SceneTree
## ANA-GAME-002-B tests: Shift sprint on foot. (Sprint disabled while riding is covered in test_vehicle.gd.)
## Run: godot --headless --fixed-fps 60 --path <project> --script res://tests/test_sprint.gd
## Exit code 0 = pass, 1 = fail. Uses the real main scene and the real Input pipeline.

const TIMEOUT_MSEC := 120000

var _failures := 0
var _started_msec := 0
var _player: PlayerController
var _yaw: Node3D


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		if Time.get_ticks_msec() - _started_msec > TIMEOUT_MSEC:
			print("[FAIL] test timeout")
			quit(1)
			return
		await physics_frame


func _speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _jump_rise() -> float:
	var y0 := _player.global_position.y
	var max_y := y0
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	for i in 60:
		await _frames(1)
		max_y = maxf(max_y, _player.global_position.y)
	var release := InputEventAction.new()
	release.action = "jump"
	release.pressed = false
	Input.parse_input_event(release)
	return max_y - y0


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(60)
	_player = main.get_node("Player")
	_yaw = main.get_node("ThirdPersonCamera/YawPivot")
	var camera: Camera3D = main.get_node("ThirdPersonCamera/YawPivot/PitchPivot/SpringArm3D/Camera3D")

	# --- Input action ---------------------------------------------------------------------------
	var events := InputMap.action_get_events("sprint")
	var is_left_shift := false
	for e in events:
		if e is InputEventKey and e.physical_keycode == KEY_SHIFT and e.location == KEY_LOCATION_LEFT:
			is_left_shift = true
	_check("input action `sprint` bound to left Shift", InputMap.has_action("sprint") and is_left_shift)
	_check("defaults: walk 2.5 m/s, sprint 5.0 m/s (exported)", is_equal_approx(_player.move_speed, 2.5)
			and is_equal_approx(_player.sprint_speed, 5.0))
	_check("jump velocity unchanged (3.5)", is_equal_approx(_player.jump_velocity, 3.5))

	# --- Walk -> sprint -> walk -------------------------------------------------------------------
	_player.global_position = Vector3(0, 0.05, 8)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(40)
	_check("walking speed is 2.5 m/s", absf(_speed() - 2.5) < 0.05, "v=%.3f" % _speed())

	Input.action_press("sprint")
	await _frames(1)
	var first_frame := _speed()
	_check("sprint accelerates smoothly (not an instant jump)", first_frame > 2.5 and first_frame < 4.9,
			"v after 1 frame=%.3f" % first_frame)
	await _frames(30)
	_check("sprinting speed is 5.0 m/s", absf(_speed() - 5.0) < 0.05, "v=%.3f" % _speed())

	Input.action_release("sprint")
	await _frames(1)
	_check("releasing Shift decelerates smoothly", _speed() > 2.6 and _speed() < 5.0, "v=%.3f" % _speed())
	await _frames(30)
	_check("back to 2.5 m/s after releasing Shift", absf(_speed() - 2.5) < 0.05, "v=%.3f" % _speed())
	Input.action_release("move_forward")
	await _frames(40)

	Input.action_press("sprint")
	await _frames(30)
	_check("Shift alone does not move the player", _speed() < 0.01, "v=%.3f" % _speed())
	Input.action_release("sprint")

	# --- Camera-relative while sprinting ----------------------------------------------------------
	_yaw.rotation.y = deg_to_rad(70.0)
	await _frames(5)
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var p0 := _player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	var moved := _player.global_position - p0
	moved.y = 0.0
	_check("sprint stays camera-relative", moved.normalized().dot(cam_fwd) > 0.98,
			"dot=%.3f" % moved.normalized().dot(cam_fwd))
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(40)

	# --- Jump: same height standing vs sprinting, and during sprint --------------------------------
	_yaw.rotation.y = 0.0
	_player.global_position = Vector3(0, 0.05, 12)
	_player.velocity = Vector3.ZERO
	await _frames(30)
	var rise_standing := await _jump_rise()
	await _frames(20)
	_player.global_position = Vector3(0, 0.05, 12)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(25)
	var air_speed_start := _speed()
	var rise_sprinting := await _jump_rise()
	_check("jump works while sprinting", rise_sprinting > 0.4, "rise=%.3f" % rise_sprinting)
	_check("jump height not changed by sprint", absf(rise_sprinting - rise_standing) < 0.03,
			"standing=%.3f sprinting=%.3f" % [rise_standing, rise_sprinting])
	_check("sprint speed kept through the jump", absf(air_speed_start - 5.0) < 0.1, "v=%.3f" % air_speed_start)
	Input.action_release("move_forward")
	Input.action_release("sprint")

	_check("no stamina / energy system added", not _player.has_method("get_stamina") and not ("stamina" in _player))
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)
