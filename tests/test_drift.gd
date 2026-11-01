extends SceneTree
## ANA-GAME-002-B-FIX-01 tests: Space = jump on foot, handbrake / arcade drift while riding.
## Run: godot --headless --fixed-fps 60 --path <project> --script res://tests/test_drift.gd
## Exit code 0 = pass, 1 = fail. Real main scene, real Input pipeline (real Space key events).

const TIMEOUT_MSEC := 240000
const LANE_Z := -14.0          # flat lane in the ramp plaza, driven toward +X
const LANE_YAW := -PI / 2.0

var _failures := 0
var _started_msec := 0
var _main: Node
var _player: PlayerController
var _vehicle: VehicleController
var _interaction: VehicleInteraction
var _rig: ThirdPersonCamera
var _foot_target: Node3D


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


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump", "vehicle_handbrake"]:
		Input.action_release(a)
	_space(false)


func _space(pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(action: String, frames_down: int = 2) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(frames_down)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(1)


func _place_vehicle(x: float, z: float, yaw: float) -> void:
	_vehicle.velocity = Vector3.ZERO
	_vehicle.speed = 0.0
	_vehicle.lateral = 0.0
	_vehicle.drift_amount = 0.0
	_vehicle.steer = 0.0
	_vehicle.global_position = Vector3(x, FarmLayout.height_at(x, z) + 0.03, z)
	_vehicle.global_rotation = Vector3(0.0, yaw, 0.0)
	await _frames(25)


## Reaches top speed on the flat lane, driving toward +X.
func _launch() -> void:
	_release_all()
	await _place_vehicle(28.0, LANE_Z, LANE_YAW)
	Input.action_press("move_forward")
	await _frames(120)


func _slip_angle() -> float:
	var v := Vector2(_vehicle.velocity.x, _vehicle.velocity.z)
	var f := Vector2(-_vehicle.global_basis.z.x, -_vehicle.global_basis.z.z)
	if v.length() < 0.5:
		return 0.0
	return rad_to_deg(absf(v.angle_to(f)))


## Runs `frames` physics frames with the given keys held; returns per-run stats.
func _run_keys(frames: int, space: bool, left: bool, right: bool) -> Dictionary:
	var st := {"dyaw": 0.0, "max_lateral": 0.0, "max_slip": 0.0, "min_speed": INF, "max_speed": 0.0,
			"max_vy": 0.0, "grounded": 0, "max_yaw_jerk": 0.0, "end_speed": 0.0, "finite": true,
			"min_forward_progress": INF}
	var yaw_start := _vehicle.global_rotation.y
	var prev_yaw := yaw_start
	var prev_rate := 0.0
	if space:
		_space(true)
	if left:
		Input.action_press("move_left")
	if right:
		Input.action_press("move_right")
	var start := _vehicle.global_position
	for i in frames:
		await _frames(1)
		var yaw := _vehicle.global_rotation.y
		var rate := wrapf(yaw - prev_yaw, -PI, PI)
		if i > 0:
			st.max_yaw_jerk = maxf(st.max_yaw_jerk, absf(rate - prev_rate))
		prev_yaw = yaw
		prev_rate = rate
		st.max_lateral = maxf(st.max_lateral, absf(_vehicle.lateral))
		st.max_slip = maxf(st.max_slip, _slip_angle())
		st.min_speed = minf(st.min_speed, _vehicle.speed)
		st.max_speed = maxf(st.max_speed, _vehicle.speed)
		st.max_vy = maxf(st.max_vy, absf(_vehicle.velocity.y))
		if _vehicle.is_on_floor():
			st.grounded += 1
		if not _vehicle.global_position.is_finite() or not _vehicle.velocity.is_finite():
			st.finite = false
	st.dyaw = wrapf(_vehicle.global_rotation.y - yaw_start, -PI, PI)
	st.end_speed = _vehicle.speed
	st.travelled = _vehicle.global_position.distance_to(start)
	return st


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(60)
	_player = _main.get_node("Player")
	_vehicle = _main.get_node("RideOnVehicle")
	_interaction = _main.get_node("VehicleInteraction")
	_rig = _main.get_node("ThirdPersonCamera")
	_foot_target = _player.get_node("CameraTarget")
	var hud: ControlsHUD = _main.get_node("ControlsHUD")

	# ---------------- Input map ----------------
	var space_events := 0
	for action in ["jump", "vehicle_handbrake"]:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and e.physical_keycode == KEY_SPACE:
				space_events += 1
	_check("`jump` and `vehicle_handbrake` are both bound to Space", space_events == 2)
	_check("max speed unchanged (7.0) and drift defaults exposed", is_equal_approx(_vehicle.max_forward_speed, 7.0)
			and is_equal_approx(_vehicle.drift_min_speed, 3.0) and is_equal_approx(_vehicle.drift_steer_multiplier, 1.85)
			and is_equal_approx(_vehicle.drift_lateral_grip, 0.38) and is_equal_approx(_vehicle.grip_recovery_time, 0.2))
	_check("sprint unchanged (2.5 / 5.0)", is_equal_approx(_player.move_speed, 2.5) and is_equal_approx(_player.sprint_speed, 5.0))
	_check("HUD texts: vehicle panel mentions handbrake/drift, foot panel keeps `Espaço — Pular`",
			(hud.get_node("Root/Margin/VehiclePanel/Padding/Lines/Body") as Label).text.contains("Espaço — Freio de mão / Derrapar")
			and (hud.get_node("Root/Margin/Panel/Padding/Lines/Body") as Label).text.contains("Espaço — Pular"))

	# ---------------- On foot: Space still jumps ----------------
	var parked := _vehicle.global_position
	await _frames(30)
	var y0 := _player.global_position.y
	var rise := 0.0
	_space(true)
	for i in 50:
		await _frames(1)
		rise = maxf(rise, _player.global_position.y - y0)
	_space(false)
	await _frames(40)
	_check("on foot: real Space key makes the player jump", rise > 0.55, "rise=%.2f" % rise)
	_check("on foot: Space does not touch the parked vehicle", _vehicle.global_position.distance_to(parked) < 0.02
			and _vehicle.speed == 0.0 and _vehicle.drift_amount == 0.0)

	# ---------------- Mount (E) ----------------
	_player.global_position = Vector3(2.6, 0.1, -4.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	await _tap("interact")
	await _frames(5)
	_check("E mounts as before", _interaction.is_mounted() and _vehicle.driven and _rig.target == _vehicle.camera_target)

	# ---------------- Handbrake only (straight) ----------------
	await _launch()
	_check("reached top speed before braking", absf(_vehicle.speed - 7.0) < 0.3, "v=%.2f" % _vehicle.speed)
	var y_flat := _vehicle.global_position.y
	var brake := await _run_keys(30, true, false, false)
	_check("handbrake (no steering) brakes partially, not instantly", brake.end_speed < 6.0 and brake.end_speed > 2.0,
			"v after 0.5 s = %.2f" % brake.end_speed)
	_check("handbrake straight: no spin, no sideways slide, no hop", absf(brake.dyaw) < 0.01 and brake.max_lateral < 0.05
			and brake.max_vy < 0.05 and absf(_vehicle.global_position.y - y_flat) < 0.05,
			"dyaw=%.4f lat=%.3f vy=%.3f" % [brake.dyaw, brake.max_lateral, brake.max_vy])
	_release_all()
	await _frames(20)

	# ---------------- A-only baseline vs handbrake + A ----------------
	await _launch()
	var base := await _run_keys(40, false, true, false)
	_check("baseline A-only turn: no slide", base.max_lateral < 0.05 and base.max_slip < 3.0,
			"dyaw=%.2f lat=%.3f slip=%.1f deg" % [base.dyaw, base.max_lateral, base.max_slip])
	var base_dyaw: float = base.dyaw
	var base_speed: float = base.end_speed

	await _launch()
	var drift_l := await _run_keys(40, true, true, false)
	_check("Space + A: drifts LEFT (turns left, slides right of heading)", drift_l.dyaw > 0.3 and _vehicle.lateral > 0.5,
			"dyaw=%.2f lateral=%.2f" % [drift_l.dyaw, _vehicle.lateral])
	_check("drift turns more than the normal turn (x1.1 .. x1.9)", drift_l.dyaw > base_dyaw * 1.1 and drift_l.dyaw < base_dyaw * 1.9,
			"drift=%.2f base=%.2f ratio=%.2f" % [drift_l.dyaw, base_dyaw, drift_l.dyaw / base_dyaw])
	_check("visible but controlled slip angle (6-40 deg)", drift_l.max_slip > 6.0 and drift_l.max_slip < 40.0,
			"slip=%.1f deg" % drift_l.max_slip)
	_check("keeps moving forward while sliding, partial deceleration only", drift_l.end_speed > 3.5
			and drift_l.end_speed < base_speed + 0.01 and drift_l.min_speed > 3.0,
			"drift end=%.2f baseline end=%.2f" % [drift_l.end_speed, base_speed])
	_check("drift stays grounded: no vertical impulse, finite, never above top speed", drift_l.grounded == 40
			and drift_l.max_vy < 0.05 and drift_l.finite and drift_l.max_speed <= 7.05,
			"vy=%.3f vmax=%.2f" % [drift_l.max_vy, drift_l.max_speed])
	_check("drift engaged (drift_amount > 0.8)", _vehicle.drift_amount > 0.8, "amount=%.2f" % _vehicle.drift_amount)

	# Release Space while still holding A: grip comes back smoothly.
	_space(false)
	var slip_at_release := _slip_angle()
	var rec := await _run_keys(40, false, true, false)
	_check("grip recovers after releasing Space (lateral ~0, drift_amount 0)",
			absf(_vehicle.lateral) < 0.1 and _vehicle.drift_amount == 0.0 and _slip_angle() < 3.0,
			"lateral=%.3f slip=%.1f->%.1f deg" % [_vehicle.lateral, slip_at_release, _slip_angle()])
	_check("recovery is smooth (no sudden yaw-rate jump)", rec.max_yaw_jerk < 0.012, "max jerk=%.4f rad/frame" % rec.max_yaw_jerk)
	_check("recovery keeps the vehicle moving and grounded", rec.min_speed > 3.0 and rec.grounded == 40 and rec.max_vy < 0.05)
	_release_all()
	await _frames(10)

	# Right drift (mirror).
	await _launch()
	var drift_r := await _run_keys(40, true, false, true)
	_check("Space + D: drifts RIGHT (yaw decreases, slides left of heading)", drift_r.dyaw < -0.3 and _vehicle.lateral < -0.5,
			"dyaw=%.2f lateral=%.2f" % [drift_r.dyaw, _vehicle.lateral])
	_check("right drift is a mirror of the left one (+-25 %)", absf(absf(drift_r.dyaw) / absf(drift_l.dyaw) - 1.0) < 0.25,
			"|R|=%.2f |L|=%.2f" % [absf(drift_r.dyaw), absf(drift_l.dyaw)])
	_space(false)
	var rec_r := await _run_keys(40, false, false, true)
	_check("right drift recovers smoothly too", absf(_vehicle.lateral) < 0.1 and rec_r.max_yaw_jerk < 0.012,
			"lateral=%.3f jerk=%.4f" % [_vehicle.lateral, rec_r.max_yaw_jerk])
	_release_all()

	# Holding Space for a long time while steering never spins out.
	await _launch()
	var long_drift := await _run_keys(150, true, true, false)
	_check("long drift: speed decays smoothly, yaw rate bounded, still finite",
			long_drift.finite and absf(long_drift.dyaw) < PI and long_drift.max_yaw_jerk < 0.012 and long_drift.grounded == 150,
			"dyaw=%.2f jerk=%.4f end v=%.2f" % [long_drift.dyaw, long_drift.max_yaw_jerk, long_drift.end_speed])
	_space(false)
	await _frames(40)
	_check("long drift ends cleanly after releasing Space", absf(_vehicle.lateral) < 0.1 and _vehicle.drift_amount == 0.0)
	_release_all()

	# ---------------- No artificial drift when slow / stopped ----------------
	_release_all()
	await _place_vehicle(28.0, LANE_Z, LANE_YAW)
	var still_pos := _vehicle.global_position
	var still := await _run_keys(60, true, true, false)
	_check("stopped: handbrake + A causes no spin, slide or movement", absf(still.dyaw) < 0.001 and still.max_lateral < 0.01
			and _vehicle.global_position.distance_to(still_pos) < 0.01 and _vehicle.drift_amount == 0.0,
			"dyaw=%.5f moved=%.4f" % [still.dyaw, _vehicle.global_position.distance_to(still_pos)])
	_release_all()
	await _place_vehicle(28.0, LANE_Z, LANE_YAW)
	Input.action_press("move_forward")
	await _frames(20)
	var slow_speed := _vehicle.speed
	var slow := await _run_keys(30, true, true, false)
	_check("below 3 m/s: no drift is started", slow_speed < 3.0 and _vehicle.drift_amount == 0.0 and slow.max_lateral < 0.05,
			"v=%.2f lateral=%.3f" % [slow_speed, slow.max_lateral])
	_release_all()
	await _frames(10)

	# ---------------- No handbrake effects in the air; no vertical impulse ----------------
	_release_all()
	await _place_vehicle(22.0, 0.0, LANE_YAW)
	Input.action_press("move_forward")
	var guard := 0
	while _vehicle.is_on_floor() or _vehicle.global_position.y < 0.8:
		await _frames(1)
		guard += 1
		if guard > 600:
			break
	_check("reached the air on the medium ramp", not _vehicle.is_on_floor(), "frames=%d" % guard)
	_space(true)
	Input.action_press("move_left")
	var air_frames := 0
	var max_h_change := 0.0
	var max_vy_dev := 0.0
	var max_yaw_change := 0.0
	var prev_v := _vehicle.velocity
	var prev_yaw := _vehicle.global_rotation.y
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	while not _vehicle.is_on_floor() and air_frames < 120:
		await _frames(1)
		if _vehicle.is_on_floor():
			break
		air_frames += 1
		var v := _vehicle.velocity
		max_h_change = maxf(max_h_change, Vector2(v.x - prev_v.x, v.z - prev_v.z).length())
		max_vy_dev = maxf(max_vy_dev, absf((v.y - prev_v.y) + gravity / 60.0))
		max_yaw_change = maxf(max_yaw_change, absf(wrapf(_vehicle.global_rotation.y - prev_yaw, -PI, PI)))
		prev_v = v
		prev_yaw = _vehicle.global_rotation.y
	_check("airborne with Space+A: horizontal velocity unchanged, pure gravity vertically, no turning",
			air_frames >= 3 and max_h_change < 0.02 and max_vy_dev < 0.05 and max_yaw_change < 0.001 and _vehicle.drift_amount < 0.01,
			"air=%d dH=%.4f dVy=%.4f dYaw=%.5f" % [air_frames, max_h_change, max_vy_dev, max_yaw_change])
	_release_all()
	await _frames(90)
	_check("landing after the ramp is stable", _vehicle.is_on_floor() and absf(_vehicle.global_position.y) < 0.1
			and _vehicle.visual_root.global_basis.y.dot(Vector3.UP) > 0.97 and _vehicle.global_position.is_finite(),
			"y=%.3f lateral=%.3f" % [_vehicle.global_position.y, _vehicle.lateral])

	# ---------------- Hills with drift bursts ----------------
	await _place_vehicle(-14.0, 3.0, atan2(42.0, 33.0))
	var target := Vector2(-56, -30)
	var grounded := 0
	var frames_total := 0
	var max_sink := 0.0
	var max_y := -INF
	var finite := true
	var max_speed := 0.0
	var min_tilt := 1.0
	Input.action_press("move_forward")
	for f in 2400:
		var d := target - Vector2(_vehicle.global_position.x, _vehicle.global_position.z)
		if d.length() < 2.5:
			break
		var err := wrapf(atan2(-d.x, -d.y) - _vehicle.global_rotation.y, -PI, PI)
		var burst := (f % 150) >= 100 and (f % 150) < 130
		if burst:
			_space(true)
			if (f / 150) % 2 == 0:
				Input.action_press("move_left")
				Input.action_release("move_right")
			else:
				Input.action_press("move_right")
				Input.action_release("move_left")
		else:
			_space(false)
			if err > 0.06:
				Input.action_press("move_left")
				Input.action_release("move_right")
			elif err < -0.06:
				Input.action_press("move_right")
				Input.action_release("move_left")
			else:
				Input.action_release("move_left")
				Input.action_release("move_right")
		await _frames(1)
		frames_total += 1
		if _vehicle.is_on_floor():
			grounded += 1
			max_sink = maxf(max_sink, FarmLayout.height_at(_vehicle.global_position.x, _vehicle.global_position.z) - _vehicle.global_position.y)
		max_y = maxf(max_y, _vehicle.global_position.y)
		max_speed = maxf(max_speed, _vehicle.speed)
		min_tilt = minf(min_tilt, _vehicle.visual_root.global_basis.y.dot(Vector3.UP))
		if not _vehicle.global_position.is_finite() or not _vehicle.velocity.is_finite():
			finite = false
	_release_all()
	_check("hill climb with drift bursts: reaches the top, stays grounded and stable",
			max_y > 3.0 and grounded >= 0.85 * frames_total and max_sink < 0.12 and finite and min_tilt > 0.8 and max_speed <= 7.0 * 1.3 + 0.1,
			"max_y=%.2f grounded=%d/%d sink=%.3f tilt=%.2f vmax=%.2f" % [max_y, grounded, frames_total, max_sink, min_tilt, max_speed])
	await _frames(200)

	# ---------------- Camera, exit and foot control still fine ----------------
	_check("camera still follows the vehicle", _rig.target == _vehicle.camera_target)
	_vehicle.speed = 0.0
	await _frames(200)
	await _tap("interact")
	await _frames(5)
	_check("E dismounts when stopped", not _interaction.is_mounted() and _player.move_state == PlayerController.MoveState.ON_FOOT)
	await _frames(120)
	_check("camera returns to the player", _rig.target == _foot_target
			and _rig.global_position.distance_to(_foot_target.global_position) < 0.15)
	var y1 := _player.global_position.y
	var rise2 := 0.0
	_space(true)
	for i in 50:
		await _frames(1)
		rise2 = maxf(rise2, _player.global_position.y - y1)
	_space(false)
	_check("Space jumps again after dismounting", rise2 > 0.55, "rise=%.2f" % rise2)
	_check("exactly one player after all of this", _count(_main, "PlayerController") == 1)
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _count(node: Node, type_name: String) -> int:
	var n := 0
	if node.get_script() and node.get_script().get_global_name() == type_name:
		n += 1
	for c in node.get_children():
		n += _count(c, type_name)
	return n
