extends SceneTree
## ANA-GAME-002-B tests: ride-on vehicle, mount/dismount, driving, hills, ramps, no-jump, camera.
## Run: godot --headless --fixed-fps 60 --path <project> --script res://tests/test_vehicle.gd
## Exit code 0 = pass, 1 = fail. Uses the real main scene, real components and the real Input pipeline.

const TIMEOUT_MSEC := 280000

var _failures := 0
var _started_msec := 0
var _main: Node
var _player: PlayerController
var _vehicle: VehicleController
var _interaction: VehicleInteraction
var _rig: ThirdPersonCamera
var _hud: ControlsHUD
var _yaw: Node3D
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
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump", "interact"]:
		Input.action_release(a)


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
	_vehicle.steer = 0.0
	_vehicle.global_position = Vector3(x, FarmLayout.height_at(x, z) + 0.03, z)
	_vehicle.global_rotation = Vector3(0.0, yaw, 0.0)
	await _frames(25)


func _place_player(x: float, z: float) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(x, FarmLayout.height_at(x, z) + 0.1, z)
	await _frames(20)


func _heading_to(target: Vector2) -> float:
	var d := target - Vector2(_vehicle.global_position.x, _vehicle.global_position.z)
	return atan2(-d.x, -d.y)


## Drives with W held, steering with A/D toward `target` (x, z). Collects stats.
func _drive_to(target: Vector2, max_frames: int, stop_dist: float = 2.0, check_sink: bool = false) -> Dictionary:
	var st := {"frames": 0, "grounded": 0, "air": 0, "max_y": -INF, "min_speed": INF, "max_speed": 0.0,
			"reached": false, "finite": true, "max_sink": 0.0, "min_tilt": 1.0}
	Input.action_press("move_forward")
	for f in max_frames:
		var d := target - Vector2(_vehicle.global_position.x, _vehicle.global_position.z)
		if d.length() < stop_dist:
			st.reached = true
			break
		var err := wrapf(_heading_to(target) - _vehicle.global_rotation.y, -PI, PI)
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
		st.frames += 1
		if _vehicle.is_on_floor():
			st.grounded += 1
		else:
			st.air += 1
		var p := _vehicle.global_position
		st.max_y = maxf(st.max_y, p.y)
		if f > 60:
			st.min_speed = minf(st.min_speed, _vehicle.speed)
		st.max_speed = maxf(st.max_speed, _vehicle.speed)
		if not p.is_finite() or not _vehicle.velocity.is_finite() or not is_finite(_vehicle.speed):
			st.finite = false
		if check_sink and _vehicle.is_on_floor():
			st.max_sink = maxf(st.max_sink, FarmLayout.height_at(p.x, p.z) - p.y)
		var vis: Node3D = _vehicle.visual_root
		st.min_tilt = minf(st.min_tilt, vis.global_basis.y.dot(Vector3.UP))
	_release_all()
	return st


func _count_nodes(node: Node, type_name: String) -> int:
	var n := 0
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		n += 1
	for c in node.get_children():
		n += _count_nodes(c, type_name)
	return n


func _count_named(node: Node, node_name: String) -> int:
	var n := 1 if node.name == node_name else 0
	for c in node.get_children():
		n += _count_named(c, node_name)
	return n


func _yaw_of_vehicle() -> float:
	return _vehicle.global_rotation.y


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(60)
	_player = _main.get_node("Player")
	_vehicle = _main.get_node("RideOnVehicle")
	_interaction = _main.get_node("VehicleInteraction")
	_rig = _main.get_node("ThirdPersonCamera")
	_hud = _main.get_node("ControlsHUD")
	_yaw = _rig.get_node("YawPivot")
	_foot_target = _player.get_node("CameraTarget")
	var player_shape: CollisionShape3D = _player.get_node("CollisionShape3D")
	var camera: Camera3D = _rig.get_node("YawPivot/PitchPivot/SpringArm3D/Camera3D")
	var start_vehicle_pos := _vehicle.global_position

	# =============================== 1. Vehicle greybox & proportions ===============================
	var visual: Node3D = _vehicle.get_node("VehicleVisualRoot")
	var wheels_ok := true
	for w in ["FrontLeftWheel", "FrontRightWheel", "RearLeftWheel", "RearRightWheel"]:
		var tire: MeshInstance3D = visual.get_node_or_null(w + "/Spin/Tire")
		if tire == null:
			wheels_ok = false
			continue
		var c: Color = (tire.mesh as PrimitiveMesh).material.albedo_color
		if not (c.g > c.r and c.g > 0.8 and c.b > 0.65):  # mint green
			wheels_ok = false
	_check("four separate mint-green wheels", wheels_ok)
	var pink: Color = (visual.get_node("PinkBody").mesh as PrimitiveMesh).material.albedo_color
	_check("pink body, elongated seat and triangular handlebar exist", pink.r > 0.9 and pink.g < 0.7
			and visual.get_node_or_null("ElongatedSeat") != null and visual.get_node_or_null("TriangularHandlebar") != null
			and visual.get_node_or_null("HandlebarGrip") != null)
	var bounds := AABB()
	var first := true
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (_vehicle.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_check("child-sized: < 1.0 m long, < 0.7 m wide, < 0.8 m tall (rider ~0.9 m)",
			bounds.size.z < 1.0 and bounds.size.x < 0.7 and bounds.size.y < 0.8, "size=%s" % bounds.size)
	_check("logical anchors exist (seat, camera target, dismount)", _vehicle.seat_anchor != null
			and _vehicle.camera_target != null and _vehicle.dismount_anchor != null)
	_check("vehicle is a single reusable CharacterBody3D root with one collision shape",
			_vehicle is CharacterBody3D and _vehicle.find_children("*", "CollisionShape3D", true, false).size() == 1)

	# =============================== 2. Parked, on foot, mount rejected out of range ===============
	_check("starts ON_FOOT with the vehicle parked", _player.move_state == PlayerController.MoveState.ON_FOOT
			and not _vehicle.driven and not _interaction.is_mounted())
	_check("parked vehicle is grounded and does not drift", _vehicle.is_on_floor()
			and _vehicle.global_position.distance_to(start_vehicle_pos) < 0.05,
			"drift=%.4f" % _vehicle.global_position.distance_to(start_vehicle_pos))
	Input.action_press("move_forward")
	await _frames(10)
	_check("vehicle ignores driving input while nobody rides it", _vehicle.speed == 0.0
			and _vehicle.global_position.distance_to(start_vehicle_pos) < 0.05)
	_release_all()
	await _place_player(-6, 6)
	await _tap("interact")
	_check("mount rejected outside interaction distance", not _interaction.is_mounted() and not _vehicle.driven)
	_check("no prompt shown when far", _hud.get_prompt() == "")

	# =============================== 3. Mount ======================================================
	await _place_player(2.6, -4)
	await _frames(5)
	_check("prompt `E — Subir no veículo` shown near the vehicle", _hud.get_prompt() == "E — Subir no veículo",
			"prompt='%s'" % _hud.get_prompt())
	await _tap("interact")
	await _frames(5)
	_check("E mounts within interaction distance", _interaction.is_mounted())
	_check("mounted state: foot controller inactive, vehicle controllable",
			_player.move_state == PlayerController.MoveState.MOUNTED and _vehicle.driven)
	_check("player collision shape disabled while riding (no invisible blocker)", player_shape.disabled)
	_check("exactly one player controller and one player visual",
			_count_nodes(_main, "PlayerController") == 1 and _count_named(_main, "PlaceholderMesh") == 1,
			"controllers=%d visuals=%d" % [_count_nodes(_main, "PlayerController"), _count_named(_main, "PlaceholderMesh")])
	_check("rider sits on SeatAnchor", _player.global_position.distance_to(_vehicle.seat_anchor.global_position) < 0.05)
	_check("camera target switched to the vehicle", _rig.target == _vehicle.camera_target)
	_check("HUD shows vehicle controls, hides foot controls",
			_hud.get_node("Root/Margin/VehiclePanel").visible and not _hud.get_node("Root/Margin/Panel").visible)
	_check("prompt cleared while riding", _hud.get_prompt() == "")
	_check("mouse sensitivity and pitch limits unchanged", is_equal_approx(_rig.mouse_sensitivity, 0.0025)
			and is_equal_approx(_rig.min_pitch_degrees, -70.0) and is_equal_approx(_rig.max_pitch_degrees, 10.0))

	# =============================== 4. Sprint disabled while riding ===============================
	# Compare 1 s of full throttle with and without Shift held: identical, and the rider never moves by itself.
	await _place_vehicle(0, 8, 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(30)
	var speed_sprint := _vehicle.speed
	var rider_offset := _player.global_position.distance_to(_vehicle.seat_anchor.global_position)
	_release_all()
	await _place_vehicle(0, 8, 0.0)
	Input.action_press("move_forward")
	await _frames(30)
	var speed_plain := _vehicle.speed
	_release_all()
	_check("sprint has no effect while mounted", absf(speed_sprint - speed_plain) < 0.01 and _player.velocity == Vector3.ZERO,
			"sprint=%.3f plain=%.3f rider_vel=%s" % [speed_sprint, speed_plain, _player.velocity])
	_check("rider stays on the seat while driving", rider_offset < 0.05, "offset=%.4f" % rider_offset)

	# =============================== 5. Acceleration, coast, brake, reverse ========================
	await _place_vehicle(0, 14, 0.0)
	var d0 := _vehicle.global_position
	Input.action_press("move_forward")
	await _frames(30)
	var v_half := _vehicle.speed
	_check("acceleration is progressive (not instant)", v_half > 1.5 and v_half < 3.5, "v(0.5 s)=%.2f" % v_half)
	await _frames(90)
	_check("reaches the 7 m/s top speed on flat ground", absf(_vehicle.speed - 7.0) < 0.3, "v=%.2f" % _vehicle.speed)
	var travelled := _vehicle.global_position - d0
	_check("W drives forward (-Z)", travelled.z < -5.0, "dz=%.2f" % travelled.z)
	_check("stays grounded on flat ground (no hop)", _vehicle.is_on_floor() and absf(_vehicle.global_position.y) < 0.06,
			"y=%.3f" % _vehicle.global_position.y)
	Input.action_release("move_forward")
	await _frames(30)
	var v_coast := _vehicle.speed
	_check("releasing W decelerates gradually", v_coast < 6.5 and v_coast > 3.0, "v=%.2f" % v_coast)
	await _frames(240)
	_check("coasts to a stop", absf(_vehicle.speed) < 0.05, "v=%.3f" % _vehicle.speed)

	await _place_vehicle(0, 14, 0.0)
	Input.action_press("move_forward")
	await _frames(120)
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	var prev := _vehicle.speed
	var max_step := 0.0
	var crossed_zero_smoothly := false
	var reached_brake := false
	for i in 150:
		await _frames(1)
		max_step = maxf(max_step, absf(_vehicle.speed - prev))
		if absf(_vehicle.speed) < 0.5 and i < 90:
			reached_brake = true
		prev = _vehicle.speed
		if i == 50:
			_check("S brakes: speed falls fast while moving forward", _vehicle.speed < 3.0, "v=%.2f" % _vehicle.speed)
	crossed_zero_smoothly = max_step < 0.3
	_check("braking reaches (almost) a stop in under 1.5 s", reached_brake)
	_check("forward-to-reverse transition has no abrupt velocity change", crossed_zero_smoothly, "max step=%.3f" % max_step)
	_check("reverse engages after slowing and reaches ~ -2.5 m/s", absf(_vehicle.speed + 2.5) < 0.3, "v=%.2f" % _vehicle.speed)
	Input.action_release("move_backward")
	await _frames(120)
	_check("reverse coasts to a stop", absf(_vehicle.speed) < 0.05, "v=%.3f" % _vehicle.speed)

	# =============================== 6. Steering ====================================================
	await _place_vehicle(0, 14, 0.0)
	Input.action_press("move_left")
	await _frames(60)
	_check("steering does nothing at standstill (no spinning in place)", absf(_yaw_of_vehicle()) < 0.01,
			"yaw=%.4f" % _yaw_of_vehicle())
	_release_all()
	await _place_vehicle(0, 20, 0.0)
	Input.action_press("move_forward")
	await _frames(60)
	var yaw_before := _yaw_of_vehicle()
	Input.action_press("move_left")
	await _frames(40)
	var left_turn := wrapf(_yaw_of_vehicle() - yaw_before, -PI, PI)
	var fwd := -_vehicle.global_basis.z
	_check("A steers left (yaw increases, nose swings to -X)", left_turn > 0.3 and fwd.x < -0.2,
			"dyaw=%.2f fwd=%s" % [left_turn, fwd])
	Input.action_release("move_left")
	yaw_before = _yaw_of_vehicle()
	Input.action_press("move_right")
	await _frames(60)
	var right_turn := wrapf(_yaw_of_vehicle() - yaw_before, -PI, PI)
	_check("D steers right (yaw decreases)", right_turn < -0.3, "dyaw=%.2f" % right_turn)
	_check("turning rate stays sane (no uncontrolled spin)", absf(left_turn) / (40.0 / 60.0) < 2.0
			and absf(right_turn) / 1.0 < 2.0, "%.2f / %.2f rad/s" % [left_turn / 0.667, right_turn])
	_release_all()
	await _frames(150)
	await _place_vehicle(0, 8, 0.0)
	Input.action_press("move_backward")
	await _frames(70)
	yaw_before = _yaw_of_vehicle()
	Input.action_press("move_left")
	await _frames(40)
	var rev_turn := wrapf(_yaw_of_vehicle() - yaw_before, -PI, PI)
	_check("steering works in reverse like a real vehicle (opposite yaw direction)", rev_turn < -0.1, "dyaw=%.2f" % rev_turn)
	_release_all()
	await _frames(60)

	# =============================== 7. Space never makes the vehicle jump ==========================
	var src := FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	_check("vehicle controller source never references the jump action", not src.contains('"jump"'))
	# Baseline: drive a flat lane with no Space.
	await _place_vehicle(28, -14, -PI / 2.0)
	Input.action_press("move_forward")
	var base_max_y := -INF
	var base_max_vy := -INF
	for i in 150:
		await _frames(1)
		base_max_y = maxf(base_max_y, _vehicle.global_position.y)
		base_max_vy = maxf(base_max_vy, _vehicle.velocity.y)
	_release_all()
	await _frames(100)
	# Same drive, hammering Space (tap + hold) the whole time.
	await _place_vehicle(28, -14, -PI / 2.0)
	Input.action_press("move_forward")
	_send_jump(true)
	var space_max_y := -INF
	var space_max_vy := -INF
	var rider_moved_alone := false
	for i in 150:
		await _frames(1)
		if i % 20 == 10:
			_send_jump(false)
			_send_jump(true)
		space_max_y = maxf(space_max_y, _vehicle.global_position.y)
		space_max_vy = maxf(space_max_vy, _vehicle.velocity.y)
		if _player.global_position.distance_to(_vehicle.seat_anchor.global_position) > 0.05 or _player.velocity.y != 0.0:
			rider_moved_alone = true
	_send_jump(false)
	_release_all()
	_check("driving at speed: Space adds no vertical motion (vs baseline)",
			space_max_y < base_max_y + 0.02 and space_max_vy < 0.05 and space_max_y < 0.1,
			"baseline y=%.3f vy=%.3f | with Space y=%.3f vy=%.3f" % [base_max_y, base_max_vy, space_max_y, space_max_vy])
	_check("Space does not run the on-foot jump (rider glued to seat, no vertical velocity)", not rider_moved_alone)
	await _frames(100)
	await _place_vehicle(28, -14, -PI / 2.0)
	var still_max_vy := -INF
	_send_jump(true)
	for i in 90:
		await _frames(1)
		still_max_vy = maxf(still_max_vy, absf(_vehicle.velocity.y))
	_send_jump(false)
	_check("stopped vehicle: holding Space does nothing", still_max_vy < 0.05 and absf(_vehicle.global_position.y) < 0.06,
			"vy=%.3f" % still_max_vy)

	# =============================== 8. Hills (uphill + downhill) ===================================
	await _place_vehicle(-14, 3, _heading_to_static(Vector2(-14, 3), Vector2(-56, -30)))
	var up := await _drive_to(Vector2(-56, -30), 1800, 2.5, true)
	_check("vehicle climbs the hill path to the top (> 3 m)", up.reached and up.max_y > 3.0, "max_y=%.2f frames=%d" % [up.max_y, up.frames])
	_check("uphill: does not stall (min speed > 1.5) and stays grounded (>= 85%)", up.min_speed > 1.5
			and up.grounded >= 0.85 * up.frames, "min_v=%.2f grounded=%d/%d" % [up.min_speed, up.grounded, up.frames])
	_check("uphill: no clipping into terrain, finite physics, no flipping", up.max_sink < 0.12 and up.finite and up.min_tilt > 0.8,
			"sink=%.3f tilt=%.2f" % [up.max_sink, up.min_tilt])
	await _frames(100)
	var down := await _drive_to(Vector2(-14, 3), 1800, 2.5, true)
	_check("vehicle descends back down (reaches the start area)", down.reached and _vehicle.global_position.y < 1.0,
			"y=%.2f" % _vehicle.global_position.y)
	_check("downhill: stable (grounded >= 80%, no clipping, speed bounded)", down.grounded >= 0.8 * down.frames
			and down.max_sink < 0.12 and down.finite and down.max_speed <= 7.0 * 1.3 + 0.1,
			"grounded=%d/%d sink=%.3f vmax=%.2f" % [down.grounded, down.frames, down.max_sink, down.max_speed])
	_release_all()
	await _frames(150)

	# Parked on a moderate slope: stays put.
	await _place_vehicle(-20, -34, 0.0)
	var park_pos := _vehicle.global_position
	await _frames(120)
	_check("parked on a hillside it holds position", _vehicle.global_position.distance_to(park_pos) < 0.1,
			"slid %.3f m (slope at spot %.1f deg)" % [_vehicle.global_position.distance_to(park_pos),
			rad_to_deg(acos(FarmLayout.normal_at(-20, -34).y))])

	# =============================== 9. Ramps =======================================================
	await _place_vehicle(22, 0, -PI / 2.0)
	var med := await _drive_to(Vector2(62, 0), 900, 2.0)
	_check("crosses the medium ramp and gets naturally airborne", med.reached and med.air >= 3 and med.max_y > 1.2,
			"air=%d frames max_y=%.2f" % [med.air, med.max_y])
	await _frames(60)
	_check("lands cleanly: grounded, level, finite", _vehicle.is_on_floor() and absf(_vehicle.global_position.y) < 0.1
			and _vehicle.visual_root.global_basis.y.dot(Vector3.UP) > 0.97 and med.finite,
			"y=%.3f tilt=%.3f" % [_vehicle.global_position.y, _vehicle.visual_root.global_basis.y.dot(Vector3.UP)])
	_release_all()
	await _frames(120)
	await _place_vehicle(22, -9, -PI / 2.0)
	var small := await _drive_to(Vector2(62, -9), 900, 2.0)
	_check("crosses the small ramp (peak > 0.4 m)", small.reached and small.max_y > 0.4 and small.finite,
			"max_y=%.2f air=%d" % [small.max_y, small.air])
	_release_all()
	await _frames(120)
	await _place_vehicle(47, 0, PI)
	var mound := await _drive_to(Vector2(47, 29), 900, 2.0)
	_check("crosses the natural mound (peak > 1.5 m, stays on the surface)", mound.reached and mound.max_y > 1.5
			and mound.grounded >= 0.8 * mound.frames and mound.finite,
			"max_y=%.2f grounded=%d/%d" % [mound.max_y, mound.grounded, mound.frames])
	_release_all()
	await _frames(120)

	# =============================== 10. Camera while riding ========================================
	await _place_vehicle(0, 20, 0.0)
	await _frames(120)
	Input.action_press("move_forward")
	await _frames(150)
	var cam_error := _rig.global_position.distance_to(_vehicle.camera_target.global_position)
	var expected_lag := _vehicle.speed / _interaction.riding_follow_speed
	_check("camera follows the vehicle at full speed (lag <= v/follow + margin)", cam_error < expected_lag + 0.15,
			"error=%.3f allowed=%.3f" % [cam_error, expected_lag + 0.15])
	var cam_dist := camera.global_position.distance_to(_rig.global_position)
	_check("riding camera is slightly farther than on foot (~4.5 m)", cam_dist > 4.0 and cam_dist < 4.8, "dist=%.2f" % cam_dist)
	var yaw0 := _yaw.rotation.y
	_rig._rotate_view(Vector2(200, 0))
	await _frames(2)
	_check("mouse orbit still works while riding", absf(wrapf(_yaw.rotation.y - yaw0, -PI, PI)) > 0.3)
	Input.action_press("move_left")
	await _frames(60)
	_check("camera follows through turns", _rig.global_position.distance_to(_vehicle.camera_target.global_position) < expected_lag + 0.2)
	_release_all()
	await _frames(150)

	# =============================== 11. Dismount ===================================================
	await _place_vehicle(0, 20, 0.0)
	Input.action_press("move_forward")
	await _frames(100)
	await _tap("interact")
	_check("dismount rejected while moving fast", _interaction.is_mounted() and _vehicle.driven
			and _hud.get_prompt() == "Pare o veículo para descer", "prompt='%s'" % _hud.get_prompt())
	Input.action_release("move_forward")
	await _frames(300)
	_check("vehicle has stopped", _vehicle.can_dismount(), "v=%.3f" % _vehicle.get_real_velocity().length())

	# Blocked on all sides -> stays mounted with a message.
	var blockers: Array[StaticBody3D] = []
	for off in [Vector3(0.85, 0, 0), Vector3(-0.85, 0, 0), Vector3(0, 0, 1.1), Vector3(0, 0, -1.1)]:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, 1.5, 0.7)
		cs.shape = box
		b.add_child(cs)
		_main.add_child(b)
		b.global_position = _vehicle.global_transform * off + Vector3(0, 0.75, 0)
		blockers.append(b)
	await _frames(5)
	await _tap("interact")
	await _frames(3)
	_check("dismount refused when no safe spot exists (stays mounted, shows message)",
			_interaction.is_mounted() and _hud.get_prompt() == "Sem espaço para descer", "prompt='%s'" % _hud.get_prompt())
	for b in blockers:
		b.queue_free()
	await _frames(40)

	var vehicle_before := _vehicle.global_position
	await _tap("interact")
	await _frames(5)
	_check("E dismounts when stopped and space is free", not _interaction.is_mounted()
			and _player.move_state == PlayerController.MoveState.ON_FOOT and not _vehicle.driven)
	var gap := Vector2(_player.global_position.x - _vehicle.global_position.x, _player.global_position.z - _vehicle.global_position.z).length()
	_check("player placed safely beside (not inside) the vehicle", gap > 0.6 and gap < 1.6, "gap=%.2f" % gap)
	await _frames(20)
	_check("player is grounded again, shape re-enabled", _player.is_on_floor() and not player_shape.disabled
			and absf(_player.global_position.y - FarmLayout.height_at(_player.global_position.x, _player.global_position.z)) < 0.05,
			"y=%.3f" % _player.global_position.y)
	_check("vehicle stays in the scene where it was left", _vehicle.global_position.distance_to(vehicle_before) < 0.1)
	_check("camera target restored to the player's CameraTarget", _rig.target == _foot_target)
	_check("visual scale/pose restored, HUD back to foot controls",
			_player.visual_root.scale.is_equal_approx(Vector3.ONE) and _hud.get_node("Root/Margin/Panel").visible
			and not _hud.get_node("Root/Margin/VehiclePanel").visible)
	_check("one player, one visual after dismount", _count_nodes(_main, "PlayerController") == 1
			and _count_named(_main, "PlaceholderMesh") == 1)
	await _frames(120)
	_check("camera converges back on the player", _rig.global_position.distance_to(_foot_target.global_position) < 0.15,
			"error=%.3f" % _rig.global_position.distance_to(_foot_target.global_position))
	var cam_dist_foot := camera.global_position.distance_to(_rig.global_position)
	_check("camera distance back to on-foot value (3.5 m)", absf(cam_dist_foot - 3.5) < 0.2, "dist=%.2f" % cam_dist_foot)

	# =============================== 12. Foot controls restored =====================================
	_yaw.rotation.y = 0.0
	var p0 := _player.global_position
	Input.action_press("move_forward")
	await _frames(40)
	_check("WASD works again on foot", _player.global_position.distance_to(p0) > 1.5)
	Input.action_press("sprint")
	await _frames(30)
	_check("sprint works again on foot", absf(Vector2(_player.velocity.x, _player.velocity.z).length() - 5.0) < 0.1)
	_release_all()
	await _frames(40)
	var y_start := _player.global_position.y
	var rise := 0.0
	var jp := InputEventAction.new()
	jp.action = "jump"
	jp.pressed = true
	Input.parse_input_event(jp)
	for i in 50:
		await _frames(1)
		rise = maxf(rise, _player.global_position.y - y_start)
	jp.pressed = false
	Input.parse_input_event(jp)
	_check("on-foot jump works after dismounting (Space)", rise > 0.55, "rise=%.2f" % rise)

	# =============================== 13. Rapid E presses ============================================
	await _place_player(_vehicle.global_position.x + 1.2, _vehicle.global_position.z)
	for i in 12:
		var e := InputEventAction.new()
		e.action = "interact"
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(1)
		e.pressed = false
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(30)
	var consistent := _interaction.is_mounted() == _vehicle.driven and _interaction.is_mounted() == player_shape.disabled
	_check("rapid E spam keeps a consistent state (one player, matching flags)", consistent
			and _count_nodes(_main, "PlayerController") == 1 and _count_named(_main, "PlaceholderMesh") == 1,
			"mounted=%s driven=%s shape_disabled=%s" % [_interaction.is_mounted(), _vehicle.driven, player_shape.disabled])
	var seen_states := {}
	for i in 6:
		await _tap("interact")
		await _frames(25)
		seen_states[_interaction.is_mounted()] = true
		_check("E toggle %d: flags consistent" % i, _interaction.is_mounted() == _vehicle.driven
				and (_interaction.is_mounted() == player_shape.disabled))
	_check("E toggles between both states reliably", seen_states.size() == 2)
	_release_all()
	_check("final physics state finite", _player.global_position.is_finite() and _vehicle.global_position.is_finite())
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## Presses/releases the real Space key (maps to both `jump` and `vehicle_handbrake`).
func _send_jump(pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = pressed
	Input.parse_input_event(e)


func _heading_to_static(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)
