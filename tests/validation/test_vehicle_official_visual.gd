extends SceneTree
## ANA-GAME-003-B tests: the official GLB as the playable vehicle's visual (presentation only).
## Run: godot --headless --fixed-fps 60 --path <project> --script res://tests/validation/test_vehicle_official_visual.gd
## Exit code 0 = pass, 1 = fail. Uses the real main scene, the real adapter, the real Input pipeline and
## real vehicle physics. Gameplay regressions (acceleration, braking, reverse, drift, camera, on foot) are
## covered by the existing tests, which also run against the official visual.

const TIMEOUT_MSEC := 200000
const GLB := "res://assets/vehicles/ana-veiculo-integracao-v01.glb"
const GLB_SHA256 := "e1725ef7618c869daff49477002eb977c2633bc0ee4a11e9b6d2c2ee2ace846e"
const A_COMMIT := "76fa645bbd2a3f889b399c7b6bf7b1ffee94a86a"
const MAIN_BASE_COMMIT := "4b925e96be31196a3e8d344af07633e7dd844793"  ## main before ANA-GAME-003 (PR #1 merge)
const ROLES: Array[StringName] = [&"front_left", &"front_right", &"rear_left", &"rear_right"]
const PROTECTED := ["scripts/vehicle_controller.gd", "scripts/vehicle_interaction.gd", "scripts/player_controller.gd",
		"scripts/third_person_camera.gd", "scripts/controls_hud.gd", "scripts/ride_on_visual.gd", "scenes/main.tscn",
		"scenes/player.tscn", "scenes/third_person_camera.tscn", "scenes/farm_world.tscn", "scenes/controls_hud.tscn",
		"project.godot", "export_presets.cfg", "assets/vehicles", "scenes/validation"]

var _failures := 0
var _started_msec := 0
var _main: Node
var _player: PlayerController
var _vehicle: VehicleController
var _interaction: VehicleInteraction
var _rig: ThirdPersonCamera
var _vis: OfficialVehicleVisual


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures += 1


func _info(label: String, detail: String) -> void:
	print("[INFO] %s %s" % [label, detail])


func _frames(count: int) -> void:
	for i in count:
		if Time.get_ticks_msec() - _started_msec > TIMEOUT_MSEC:
			print("[FAIL] test timeout")
			quit(1)
			return
		await physics_frame


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump", "vehicle_handbrake", "interact"]:
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


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for m in node.find_children("*", "MeshInstance3D", true, false):
		out.append(m as MeshInstance3D)
	return out


func _count_named(node: Node, node_name: String) -> int:
	var n := 1 if node.name == node_name else 0
	for c in node.get_children():
		n += _count_named(c, node_name)
	return n


func _count_class(node: Node, type_name: String) -> int:
	var n := 0
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		n += 1
	for c in node.get_children():
		n += _count_class(c, type_name)
	return n


## World-space tread point: the topmost vertex of a wheel mesh in its rest pose (taken once, in mesh space).
func _top_vertex(mi: MeshInstance3D) -> Vector3:
	var best := Vector3(0, -INF, 0)
	for s in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.y > best.y:
				best = v
	return best


func _wheel_mesh(vis: OfficialVehicleVisual, role: StringName) -> MeshInstance3D:
	return vis.get_spin_node(role).get_child(0) as MeshInstance3D


func _is_finite_tree(node: Node) -> bool:
	if node is Node3D:
		var t := (node as Node3D).transform
		if not (t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()):
			return false
	for c in node.get_children():
		if not _is_finite_tree(c):
			return false
	return true


func _git(args: Array) -> Array:
	var out: Array = []
	var full: Array = ["-C", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	var code := OS.execute("git", PackedStringArray(full), out, true)
	return [code, String(out[0]) if out.size() > 0 else ""]


## Git prints advisory lines ("warning: ... LF will be replaced by CRLF ...") on stderr, which OS.execute merges into
## the output. They are not changed files, so they are dropped; every other line is a real path and still fails the check.
func _git_changed_paths(args: Array) -> Array:
	var res := _git(args)
	var paths: Array = []
	for line in String(res[1]).split("\n"):
		var l := line.strip_edges()
		if l != "" and not l.begins_with("warning:"):
			paths.append(l)
	return [res[0], paths]


func _run() -> void:
	# ============ Test 01 - official GLB integration ============
	print("-- Test 01: official GLB integration")
	_check("T01 official GLB resource loads", load(GLB) is PackedScene)
	var veh_txt := FileAccess.get_file_as_string("res://scenes/ride_on_vehicle.tscn")
	_check("T01 playable vehicle scene references the GLB and the adapter", veh_txt.contains(GLB) and veh_txt.contains("official_vehicle_visual.gd"))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(60)
	_player = _main.get_node("Player")
	_vehicle = _main.get_node("RideOnVehicle")
	_interaction = _main.get_node("VehicleInteraction")
	_rig = _main.get_node("ThirdPersonCamera")
	_vis = _vehicle.visual_root as OfficialVehicleVisual
	_check("T01 controller's visual_root is the OfficialVehicleVisual (a RideOnVisual -> update_wheels contract kept)",
			_vis != null and _vis is RideOnVisual and _vis.ready_ok)
	var resolved := 0
	for r in ROLES:
		if _vis.get_wheel_pivot(r) != null and _vis.get_spin_node(r) != null:
			resolved += 1
	_check("T01 four wheel pivots + Spin nodes, HandlebarPivot and SeatAnchor resolved", resolved == 4 and _vis.get_handlebar_pivot() != null)
	_check("T01 update_wheels signature unchanged (speed, steer_angle, delta)", _vis.get_method_list().any(func(m: Dictionary) -> bool:
			return m.name == "update_wheels" and m.args.size() == 3 and m.args[0].name == "speed" and m.args[1].name == "steer_angle" and m.args[2].name == "delta"))

	# ============ Test 02 - single visible vehicle ============
	print("-- Test 02: single visible vehicle")
	var all_meshes := _meshes(_vehicle)
	var primitives := all_meshes.filter(func(m: MeshInstance3D) -> bool: return m.mesh is PrimitiveMesh)
	_check("T02 13 imported meshes, no placeholder primitive mesh", all_meshes.size() == 13 and primitives.is_empty(),
			"meshes=%d primitives=%d" % [all_meshes.size(), primitives.size()])
	_check("T02 official model instanced exactly once; one PinkBody/Seat/Handlebar", _count_named(_vehicle, "OfficialVehicleGLB") == 1
			and _count_named(_vehicle, "PinkBody") == 1 and _count_named(_vehicle, "ElongatedSeat") == 1 and _count_named(_vehicle, "TriangularHandlebar") == 1)
	_check("T02 one vehicle, one collision shape, no second body or camera", _count_class(_main, "VehicleController") == 1
			and _vehicle.find_children("*", "CollisionShape3D", true, false).size() == 1
			and _vehicle.find_children("*", "Camera3D", true, false).is_empty() and _vehicle.find_children("*", "PhysicsBody3D", true, false).is_empty())
	_check("T02 imported GLB brings no physics/light/animation nodes", _vehicle.find_children("*", "AnimationPlayer", true, false).is_empty()
			and _vehicle.find_children("*", "Light3D", true, false).is_empty())

	# ============ Test 03 - wheel pivot mapping ============
	print("-- Test 03: wheel pivot mapping")
	var spin_names := {}
	var mapping_ok := true
	for r in ROLES:
		var pivot := _vis.get_wheel_pivot(r)
		var spin := _vis.get_spin_node(r)
		var expect_name: String = {&"front_left": "FrontLeftWheel", &"front_right": "FrontRightWheel", &"rear_left": "RearLeftWheel", &"rear_right": "RearRightWheel"}[r]
		var center := _vehicle.visual_root.global_transform.affine_inverse() * spin.global_position
		var left_ok := (center.x < 0.0) == (r == &"front_left" or r == &"rear_left")
		var front_ok := (center.z < 0.0) == (r == &"front_left" or r == &"front_right")
		if pivot.name != expect_name or spin.get_parent() != pivot or not left_ok or not front_ok:
			mapping_ok = false
		spin_names[r] = String(spin.name)
	_info("wheel role -> imported Spin node", str(spin_names))
	_check("T03 each role maps to the pivot of the same name, its Spin child, and the matching physical corner (left = -X, front = -Z)", mapping_ok)
	var uniq := {}
	for r in ROLES:
		uniq[_vis.get_spin_node(r)] = true
	_check("T03 four distinct Spin nodes (names Spin/Spin2/Spin3/Spin4 are not used to infer position)", uniq.size() == 4)

	# Isolated instance of the vehicle (physics disabled) for exact adapter tests.
	var iso := (load("res://scenes/ride_on_vehicle.tscn") as PackedScene).instantiate() as VehicleController
	iso.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(iso)
	iso.global_position = Vector3(30, 5, 30)
	await process_frame
	await process_frame
	var iv := iso.visual_root as OfficialVehicleVisual
	var tops := {}
	var rest_tops := {}
	for r in ROLES:
		var m := _wheel_mesh(iv, r)
		tops[r] = _top_vertex(m)
		rest_tops[r] = m.global_transform * tops[r]
	var dt := 1.0 / 60.0

	# ============ Test 04 - forward rolling ============
	# Small steps keep the angles away from the +-PI wrap so displacement can be compared exactly.
	print("-- Test 04: forward wheel rotation")
	for i in 6:
		iv.update_wheels(0.5, 0.0, dt)
	var fwd_ok := true
	var expected := -0.5 * dt * 6 / iv.visual_wheel_radius
	for r in ROLES:
		var now: Vector3 = _wheel_mesh(iv, r).global_transform * tops[r]
		var moved: Vector3 = now - rest_tops[r]
		if moved.z >= -0.005 or absf(iv.get_spin_angle(r) - expected) > 1e-5:
			fwd_ok = false
		_info("forward tread top displacement", "%s dz=%.4f dy=%.4f angle=%.4f expected=%.4f" % [r, moved.z, moved.y, iv.get_spin_angle(r), expected])
	_check("T04 all four wheels roll forward (tread top moves to -Z); angle = -v*t/r (proportional to speed and time)", fwd_ok)
	var a0 := iv.get_spin_angle(&"rear_left")
	for i in 6:
		iv.update_wheels(1.0, 0.0, dt)
	var step2 := angle_difference(a0, iv.get_spin_angle(&"rear_left"))
	_check("T04 doubling the speed doubles the angular displacement", absf(step2 - 2.0 * expected) < 1e-5, "d=%.5f expected=%.5f" % [step2, 2.0 * expected])
	for i in 600:  # long run: angle stays bounded and finite
		iv.update_wheels(7.0, 0.0, dt)
	var bounded := true
	var pivots_ok := true
	for r in ROLES:
		bounded = bounded and absf(iv.get_spin_angle(r)) <= PI + 1e-6
		if not iv.get_wheel_pivot(r).transform.origin.is_equal_approx(iv._pivot_rest[r].origin) or not iv.get_wheel_pivot(r).scale.is_equal_approx(Vector3.ONE):
			pivots_ok = false
	_check("T04 spin angle stays within +-PI over a long run; wheels stay on their axles at rest scale", bounded and pivots_ok)

	# ============ Test 05 - reverse ============
	print("-- Test 05: reverse wheel rotation")
	var angles_before := {}
	var tops_before := {}
	for r in ROLES:
		angles_before[r] = iv.get_spin_angle(r)
		tops_before[r] = _wheel_mesh(iv, r).global_transform * tops[r]
	for i in 6:
		iv.update_wheels(-1.0, 0.0, dt)
	var rev_ok := true
	for r in ROLES:
		var delta_angle := angle_difference(angles_before[r], iv.get_spin_angle(r))
		if absf(delta_angle - (1.0 * dt * 6 / iv.visual_wheel_radius)) > 1e-5:
			rev_ok = false
	_check("T05 reverse speed rolls every wheel by exactly +v*t/r (opposite sign to forward), continuously", rev_ok)

	# ============ Test 06 - braking and idle ============
	print("-- Test 06: braking and idle")
	var last_step := INF
	var monotonic := true
	var speed := 5.0
	for i in 40:
		var a_prev := iv.get_spin_angle(&"front_left")
		iv.update_wheels(speed, 0.0, dt)
		var step := absf(angle_difference(a_prev, iv.get_spin_angle(&"front_left")))
		if step > last_step + 1e-9:
			monotonic = false
		last_step = step
		speed = maxf(speed - 0.25, 0.0)
	var held := iv.get_spin_angle(&"front_left")
	for i in 30:
		iv.update_wheels(0.0, 0.0, dt)
	_check("T06 braking: per-frame rotation decreases monotonically to zero", monotonic and last_step < 1e-9, "last=%.9f" % last_step)
	_check("T06 idle: angle unchanged at speed 0, no reset", is_equal_approx(held, iv.get_spin_angle(&"front_left")))
	# ============ Test 07 - front-wheel steering ============
	print("-- Test 07: front-wheel steering")
	for sign in [1.0, -1.0]:
		for i in 10:
			iv.update_wheels(2.0, 0.4 * sign, dt)
		var fl := iv.get_wheel_pivot(&"front_left")
		var fr := iv.get_wheel_pivot(&"front_right")
		var rl := iv.get_wheel_pivot(&"rear_left")
		var rr := iv.get_wheel_pivot(&"rear_right")
		_check("T07 steer %+.1f rad: both front pivots yaw by it (+ = left), rear pivots stay at rest" % (0.4 * sign),
				absf(fl.rotation.y - 0.4 * sign) < 1e-5 and absf(fr.rotation.y - 0.4 * sign) < 1e-5
				and rl.transform.is_equal_approx(iv._pivot_rest[&"rear_left"]) and rr.transform.is_equal_approx(iv._pivot_rest[&"rear_right"]))
		_check("T07 front wheels stay on their axles and still roll while steering", fl.position.is_equal_approx(iv._pivot_rest[&"front_left"].origin)
				and fr.position.is_equal_approx(iv._pivot_rest[&"front_right"].origin) and absf(iv.get_spin_node(&"front_left").rotation.x) > 0.0
				and iv.get_spin_node(&"front_left").rotation.y == 0.0 and iv.get_spin_node(&"front_left").rotation.z == 0.0)
	for i in 5:
		iv.update_wheels(0.0, 0.0, dt)
	_check("T07 steer 0 restores the exact rest alignment of the front pivots", iv.get_wheel_pivot(&"front_left").transform.is_equal_approx(iv._pivot_rest[&"front_left"])
			and iv.get_wheel_pivot(&"front_right").transform.is_equal_approx(iv._pivot_rest[&"front_right"]))

	# ============ Test 08 - handlebar ============
	print("-- Test 08: handlebar steering")
	for i in 200:  # settle residual smoothing from the steering test before taking the rest pose
		iv.update_wheels(0.0, 0.0, dt)
	var hb := iv.get_handlebar_pivot()
	var grip := iv.find_child("HandlebarGrip", true, false) as MeshInstance3D
	var grip_rest := grip.global_transform
	for i in 60:
		iv.update_wheels(0.0, 0.5, dt)
	_check("T08 handlebar converges to steer*ratio (+ = left) and stays bounded", absf(hb.rotation.y - 0.5 * iv.handlebar_steer_ratio) < 0.005
			and absf(iv.get_handlebar_angle()) <= 0.5 * iv.handlebar_steer_ratio + 1e-6, "angle=%.4f" % hb.rotation.y)
	var left_tip_z: float = (iv.global_transform.affine_inverse() * (grip.global_transform * Vector3(-0.2, 0.2, 0.0))).z
	var left_tip_rest_z: float = (iv.global_transform.affine_inverse() * (grip_rest * Vector3(-0.2, 0.2, 0.0))).z
	_check("T08 turning left pulls the left grip back and pushes the right forward (rotation direction matches wheels)", left_tip_z > left_tip_rest_z + 0.02,
			"dz=%.3f" % (left_tip_z - left_tip_rest_z))
	iv.update_wheels(0.0, 0.0, dt)
	var smooth_first := iv.get_handlebar_angle()
	_check("T08 return is interpolated, not a jump (first frame partial)", smooth_first > 0.05 and smooth_first < 0.5, "a=%.3f" % smooth_first)
	for i in 120:
		iv.update_wheels(0.0, 0.0, dt)
	_check("T08 steer 0 restores the original handlebar rest orientation", hb.transform.is_equal_approx(iv._handlebar_rest)
			and grip.global_transform.is_equal_approx(grip_rest))

	# ============ Test 09 - visual radius, alignment, physics unchanged ============
	print("-- Test 09: visual radius, alignment, physics parameters")
	var wm := _wheel_mesh(iv, &"front_left")
	var aabb := wm.mesh.get_aabb()
	var measured_r := minf(aabb.size.y, aabb.size.z) * 0.5
	_check("T09 visual wheel radius matches the validated mesh (0.1226 +/- 0.001); placeholder 0.13 not used", absf(iv.visual_wheel_radius - measured_r) < 0.001
			and absf(iv.visual_wheel_radius - 0.13) > 0.005, "visual=%.4f measured=%.4f" % [iv.visual_wheel_radius, measured_r])
	var cap := (_vehicle.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	_check("T09 physics unchanged: capsule r 0.24 / h 0.8, speed 7.0/2.5, accel 5, brake 12, drift 1.85/0.38/0.2, steer visual 0.5",
			is_equal_approx(cap.radius, 0.24) and is_equal_approx(cap.height, 0.8) and is_equal_approx(_vehicle.max_forward_speed, 7.0)
			and is_equal_approx(_vehicle.max_reverse_speed, 2.5) and is_equal_approx(_vehicle.acceleration, 5.0) and is_equal_approx(_vehicle.brake_strength, 12.0)
			and is_equal_approx(_vehicle.drift_steer_multiplier, 1.85) and is_equal_approx(_vehicle.drift_lateral_grip, 0.38)
			and is_equal_approx(_vehicle.grip_recovery_time, 0.2) and is_equal_approx(_vehicle.max_steer_visual_angle, 0.5))
	await _place_vehicle(4.0, -4.0, 0.0)
	var floor_y := FarmLayout.height_at(4.0, -4.0)
	var lowest := INF
	var centers_ok := true
	for r in ROLES:
		var m := _wheel_mesh(_vis, r)
		for v: Vector3 in m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			lowest = minf(lowest, (m.global_transform * v).y)
		var local_center := _vis.global_transform.affine_inverse() * _vis.get_spin_node(r).global_position
		if absf(local_center.y - (0.12 + _vis.ground_lift)) > 1e-3:
			centers_ok = false
	_info("ground contact", "lowest tire y - floor y = %.4f m (ground_lift %.3f)" % [lowest - floor_y, _vis.ground_lift])
	_check("T09 flat ground: tires meet the floor within 3 mm (visual lift only), wheel centers at pivot height + lift", absf(lowest - floor_y) < 0.003 and centers_ok)

	# ============ Test 10 - seat attachment ============
	print("-- Test 10: seat attachment and mounting")
	var glb_seat := _vis.find_child("SeatAnchor", true, false) as Node3D
	_check("T10 gameplay SeatAnchor (Marker3D) follows the official SeatAnchor (+ documented offset %s)" % _vis.seat_offset,
			_vehicle.seat_anchor.global_position.distance_to(glb_seat.global_position + _vis.global_basis * _vis.seat_offset) < 1e-4
			and _vehicle.seat_anchor.position.is_equal_approx(_vis.effective_seat_transform().origin))
	_player.global_position = _vehicle.global_position + Vector3(1.2, 0.1, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(20)
	await _tap("interact")
	await _frames(5)
	_check("T10 E mounts: mounted state, vehicle driven, camera on the vehicle target", _interaction.is_mounted() and _vehicle.driven and _rig.target == _vehicle.camera_target)
	_check("T10 exactly one player controller and one player visual", _count_class(_main, "PlayerController") == 1 and _count_named(_main, "PlaceholderMesh") == 1)
	var local_rider := _vis.global_transform.affine_inverse() * _player.global_position
	var seat_mesh := _vis.find_child("ElongatedSeat", true, false) as MeshInstance3D
	var sb := seat_mesh.mesh.get_aabb()
	var seat_local_min: Vector3 = _vis.global_transform.affine_inverse() * (seat_mesh.global_transform * sb.position)
	var seat_top_y := seat_local_min.y + sb.size.y
	_info("rider vs seat (VehicleVisualRoot space)", "rider base=%s seat x=[%.3f,%.3f] z=[%.3f,%.3f] top y=%.3f" % [local_rider, -sb.size.x * 0.5, sb.size.x * 0.5, sb.position.z, sb.position.z + sb.size.z, seat_top_y])
	_check("T10 rider base is centered on the seat in X and over the seat in Z, within 7 cm of the seat top (no float, no deep sink)",
			absf(local_rider.x) < 0.01 and local_rider.z > sb.position.z and local_rider.z < sb.position.z + sb.size.z and absf(local_rider.y - seat_top_y) < 0.07)
	_check("T10 rider faces the vehicle's front (-Z)", (-_player.global_basis.z).dot(-_vehicle.global_basis.z) > 0.99)
	# Drive on the flat plaza lane; the rider must keep the same pose in the (tilting) visual frame.
	await _place_vehicle(28.0, -14.0, -PI / 2.0)
	_check("T10 still exactly one player after repositioning", _count_class(_main, "PlayerController") == 1)
	Input.action_press("move_forward")
	var max_dev := 0.0
	var max_wheel_err := 0.0
	var min_tilt := 1.0
	var finite := true
	var angle_prev := _vis.get_spin_angle(&"front_left")
	var angle_sum := 0.0
	for i in 240:
		await _frames(1)
		var rel := _vis.global_transform.affine_inverse() * _player.global_position
		max_dev = maxf(max_dev, rel.distance_to(local_rider))
		min_tilt = minf(min_tilt, _vis.global_basis.y.dot(Vector3.UP))
		if i % 20 == 0 and not _is_finite_tree(_vehicle):
			finite = false
		var a := _vis.get_spin_angle(&"front_left")
		angle_sum += angle_difference(angle_prev, a)
		angle_prev = a
	Input.action_release("move_forward")
	_check("T10 while driving the rider keeps its seat pose in the visual frame (dev < 2 mm)", max_dev < 0.002, "dev=%.5f tilt_min=%.3f" % [max_dev, min_tilt])
	var rolled := -angle_sum
	_check("T11 real driving: wheels turned by about distance/r (4 s accelerating)", rolled > 8.0 and _vehicle.speed > 3.0, "roll=%.1f rad speed=%.2f" % [rolled, _vehicle.speed])
	_check("T16 transforms stay finite and spin angles bounded while driving", finite and absf(_vis.get_spin_angle(&"front_left")) <= PI + 1e-6)

	# Real steering reaches the visuals (controller -> update_wheels).
	Input.action_press("move_left")
	await _frames(25)
	var steer_pose := _vis.get_wheel_pivot(&"front_left").rotation.y
	var hb_pose := _vis.get_handlebar_pivot().rotation.y
	Input.action_release("move_left")
	_check("T07/T08 real A key: front wheels and handlebar turn left with the physics steering", steer_pose > 0.3 and hb_pose > 0.25 and absf(steer_pose - _vehicle.steer * 0.5) < 0.2,
			"wheel=%.3f bar=%.3f steer=%.3f" % [steer_pose, hb_pose, _vehicle.steer])
	Input.action_press("move_right")
	await _frames(40)
	_check("T07/T08 real D key: both turn right", _vis.get_wheel_pivot(&"front_right").rotation.y < -0.3 and _vis.get_handlebar_pivot().rotation.y < -0.25)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	await _frames(20)

	# Reverse with real input: wheels roll the other way.
	_release_all()
	await _place_vehicle(28.0, -14.0, -PI / 2.0)
	var rev_prev := _vis.get_spin_angle(&"rear_right")
	var rev_sum := 0.0
	Input.action_press("move_backward")
	for i in 90:
		await _frames(1)
		var ra := _vis.get_spin_angle(&"rear_right")
		rev_sum += angle_difference(rev_prev, ra)
		rev_prev = ra
	var rev_speed := _vehicle.speed
	Input.action_release("move_backward")
	_check("T12 real S key: vehicle reverses and every wheel-roll step is positive (reverse direction)", rev_speed < -1.0 and rev_sum > 5.0,
			"v=%.2f roll=%.1f rad" % [rev_speed, rev_sum])
	# Space: handbrake/drift path only, no jump (the existing test_drift covers the physics in depth).
	await _place_vehicle(28.0, -14.0, -PI / 2.0)
	Input.action_press("move_forward")
	await _frames(120)
	var y_before := _vehicle.global_position.y
	_space(true)
	Input.action_press("move_left")
	var max_vy := 0.0
	var max_dy := 0.0
	var wheels_turn := true
	for i in 40:
		await _frames(1)
		max_vy = maxf(max_vy, absf(_vehicle.velocity.y))
		max_dy = maxf(max_dy, absf(_vehicle.global_position.y - y_before))
		if not _is_finite_tree(_vis):
			wheels_turn = false
	var drift_amount := _vehicle.drift_amount
	var lateral := _vehicle.lateral
	_space(false)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_check("T13 Space + A with the GLB: drift engages (drift_amount, lateral slide), no vertical impulse, visual stays finite and attached",
			drift_amount > 0.5 and absf(lateral) > 0.3 and max_vy < 0.05 and max_dy < 0.05 and wheels_turn
			and _player.global_position.distance_to(_vehicle.seat_anchor.global_position) < 0.05,
			"drift=%.2f lat=%.2f vy=%.3f dy=%.3f" % [drift_amount, lateral, max_vy, max_dy])
	await _frames(60)
	_check("T13 releasing Space recovers grip", _vehicle.drift_amount == 0.0 and absf(_vehicle.lateral) < 0.1)

	# Dismount and walk.
	Input.action_release("move_forward")
	await _frames(240)
	await _tap("interact")
	await _frames(5)
	var dismounted := not _interaction.is_mounted()
	if not dismounted:
		await _frames(120)
		await _tap("interact")
		await _frames(5)
		dismounted = not _interaction.is_mounted()
	_check("T10/T15 E dismounts; player on foot again, one player, camera back on the player", dismounted and _rig.target == _player.get_node("CameraTarget")
			and _count_class(_main, "PlayerController") == 1 and _player.visual_root.scale.is_equal_approx(Vector3.ONE))

	# ============ Test 16 - stability, Test 17 - preservation ============
	print("-- Test 16/17: stability and source preservation")
	_check("T16 no NaN/inf in the vehicle transform tree after the full session", _is_finite_tree(_vehicle) and _vehicle.global_position.is_finite())
	_check("T17 imported GLB checksum unchanged", FileAccess.get_sha256(GLB) == GLB_SHA256)
	var src := "D:/ana game/producao-assets-3d/exports-glb/ana-veiculo-integracao-v01.glb"
	if FileAccess.file_exists(src):
		_check("T17 production GLB unchanged", FileAccess.get_sha256(src) == GLB_SHA256)
	else:
		print("[NOT VERIFIED] T17 production GLB not accessible")
	var diff := _git_changed_paths(["diff", "--name-only", A_COMMIT, "--"] + PROTECTED)
	if diff[0] == 0:
		_check("T17 git: protected controller/camera/player/main/project/GLB/preview files unchanged since the 003-A commit", diff[1].is_empty(), ", ".join(diff[1]))
	else:
		print("[NOT VERIFIED] T17 git unavailable")
	# History checks stay valid after later commits and merges: the 003-A commit must still be part of HEAD, and the
	# original ANA-GAME-002 base of main must still be part of main (main may legitimately move forward).
	var anc := _git(["merge-base", "--is-ancestor", A_COMMIT, "HEAD"])
	var base_in_main := _git(["merge-base", "--is-ancestor", MAIN_BASE_COMMIT, "main"])
	_check("T17 history preserved: the 003-A commit is an ancestor of HEAD and the ANA-GAME-002 base (%s) is still an ancestor of main" % MAIN_BASE_COMMIT.substr(0, 7),
			anc[0] == 0 and base_in_main[0] == 0, "is-ancestor exit codes: A->HEAD=%s base->main=%s" % [str(anc[0]), str(base_in_main[0])])

	iso.queue_free()
	print("== RESULT: %s (%d failure(s)) ==" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)

