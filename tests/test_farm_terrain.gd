extends SceneTree
## ANA-GAME-002-A tests: farm terrain, collision, ramps, zones, boundaries and on-foot traversal.
## Run: godot --headless --path <project> --script res://tests/test_farm_terrain.gd
## Exit code 0 = pass, 1 = fail. Uses the real main scene and the real input pipeline.

const TIMEOUT_MSEC := 180000

var _failures := 0
var _started_msec := 0
var _player: PlayerController
var _rig: ThirdPersonCamera
var _yaw: Node3D
var _terrain: FarmTerrain


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


func _finish() -> void:
	Input.action_release("move_forward")
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## Y of the first collider under (x, z), ignoring the player. NAN if nothing is hit.
func _ground_y(x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -10.0, z))
	query.exclude = [_player.get_rid()]
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else NAN


func _teleport(x: float, z: float) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(x, FarmLayout.height_at(x, z) + 0.1, z)
	await _frames(20)


## Walks toward `target` (x, z) by steering the camera yaw each frame and holding W.
func _walk_to(target: Vector2, max_frames: int, stop_dist: float = 0.8) -> Dictionary:
	var stats := {"frames": 0, "on_floor": 0, "max_y": -INF, "min_clearance": INF, "reached": false}
	Input.action_press("move_forward")
	for f in max_frames:
		var d := target - Vector2(_player.global_position.x, _player.global_position.z)
		if d.length() < stop_dist:
			stats.reached = true
			break
		_yaw.rotation.y = atan2(-d.x, -d.y)
		await _frames(1)
		stats.frames += 1
		if _player.is_on_floor():
			stats.on_floor += 1
		stats.max_y = maxf(stats.max_y, _player.global_position.y)
		var ground := FarmLayout.height_at(_player.global_position.x, _player.global_position.z)
		stats.min_clearance = minf(stats.min_clearance, _player.global_position.y - ground)
	Input.action_release("move_forward")
	await _frames(25)
	return stats


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_player = main.get_node("Player")
	_rig = main.get_node("ThirdPersonCamera")
	_yaw = _rig.get_node("YawPivot")
	_terrain = main.get_node_or_null("FarmWorld/Terrain")

	# --- Terrain scene and geometry -----------------------------------------------------------
	_check("FarmWorld/Terrain exists and is a FarmTerrain", _terrain != null)
	if _terrain == null:
		_finish()
		return
	var n := FarmLayout.GRID_VERTICES
	var mesh_instance: MeshInstance3D = _terrain.get_node_or_null("TerrainMesh")
	var collision: CollisionShape3D = _terrain.get_node_or_null("TerrainCollision")
	_check("terrain mesh and collision shape built", mesh_instance != null and collision != null)
	var shape := collision.shape as ConcavePolygonShape3D
	_check("collision is a static triangle mesh", shape != null and _terrain is StaticBody3D)
	var faces := shape.get_faces()
	_check("collision triangle count matches the grid", faces.size() == (n - 1) * (n - 1) * 6,
			"faces=%d" % faces.size())
	var aabb := mesh_instance.mesh.get_aabb()
	_check("terrain spans 160 x 160 m", is_equal_approx(aabb.size.x, 160.0) and is_equal_approx(aabb.size.z, 160.0),
			"size=%s" % aabb.size)
	var up_facing := 0
	for t in range(0, faces.size(), 3 * 997):  # sample triangles across the grid
		var tri_normal := (faces[t + 1] - faces[t]).cross(faces[t + 2] - faces[t])
		if tri_normal.y < 0.0:  # clockwise seen from above = front face up in Godot
			up_facing += 1
	_check("sampled triangles face upward (winding)", up_facing == len(range(0, faces.size(), 3 * 997)))

	var all_finite := true
	for h in _terrain.heights:
		if not is_finite(h):
			all_finite = false
			break
	_check("all terrain heights finite", all_finite)
	var started := Time.get_ticks_msec()
	var terrain_b := FarmTerrain.new()
	root.add_child(terrain_b)
	var build_ms := Time.get_ticks_msec() - started
	_check("terrain is deterministic (second build identical)", terrain_b.heights == _terrain.heights,
			"build=%d ms" % build_ms)
	terrain_b.queue_free()

	# --- Layout: flat zones, hills, slopes ----------------------------------------------------
	var flat_ok := true
	for p in [Vector2(0, 0), Vector2(4, -4), Vector2(12, 8), Vector2(-10, -12), Vector2(0, -62),
			Vector2(-46, 46), Vector2(50, 50), Vector2(62, -45), Vector2(48, 0), Vector2(52, 0)]:
		if absf(FarmLayout.height_at(p.x, p.y)) > 0.001:
			flat_ok = false
			print("  not flat at %s: %.4f" % [p, FarmLayout.height_at(p.x, p.y)])
	_check("start area, parking, barn, reserves and plaza are flat", flat_ok)

	var max_slope := 0.0
	var hill_points := 0
	var x := -70.0
	while x <= 70.0:
		var z := -70.0
		while z <= 70.0:
			var sx := absf(FarmLayout.height_at(x + 1.0, z) - FarmLayout.height_at(x, z))
			var sz := absf(FarmLayout.height_at(x, z + 1.0) - FarmLayout.height_at(x, z))
			max_slope = maxf(max_slope, rad_to_deg(atan(maxf(sx, sz))))
			if FarmLayout.height_at(x, z) > 2.0:
				hill_points += 1
			z += 1.0
		x += 1.0
	_check("interior slopes are gentle (< 20 deg)", max_slope < 20.0, "max=%.1f deg" % max_slope)
	_check("hills exist (many points > 2 m)", hill_points > 100, "points=%d" % hill_points)
	_check("path-end hilltop is the highest point (3.5-5 m)", FarmLayout.height_at(-56, -30) > 3.5
			and FarmLayout.height_at(-56, -30) < 5.0, "h=%.2f" % FarmLayout.height_at(-56, -30))
	_check("mound peak ~2 m", FarmLayout.height_at(47, 15) > 1.9, "h=%.2f" % FarmLayout.height_at(47, 15))

	var zones := {
		"A": Vector2(2, 2), "B": Vector2(-24, -40), "C": Vector2(0, -18), "D": Vector2(48, 5),
		"E": Vector2(0, -62), "F": Vector2(-46, 46),
	}
	var zones_ok := true
	for key in zones:
		var got := FarmLayout.zone_at(zones[key].x, zones[key].y)
		if got != key:
			zones_ok = false
			print("  zone %s expected at %s, got '%s'" % [key, zones[key], got])
	_check("zones A-F identifiable by position", zones_ok)
	var path_ok := FarmLayout.path_mask_at(0, -18) > 0.9 and FarmLayout.path_mask_at(20, 15) < 0.05
	_check("path mask: on-path ~1, off-path ~0", path_ok)

	# --- Collision matches the height field (no gaps) -----------------------------------------
	var misses := 0
	var worst := 0.0
	var seed_state := 12345
	for s in 300:
		seed_state = (seed_state * 1103515245 + 12345) & 0x7fffffff
		var rx := (float(seed_state % 15990) / 100.0) - 79.95
		seed_state = (seed_state * 1103515245 + 12345) & 0x7fffffff
		var rz := (float(seed_state % 15990) / 100.0) - 79.95
		if (rx > 35.5 and rx < 44.5 and rz > -11.0 and rz < 2.5):
			continue  # ramp footprints are checked separately
		var gy := _ground_y(rx, rz)
		if is_nan(gy):
			misses += 1
			continue
		worst = maxf(worst, absf(gy - FarmLayout.height_at(rx, rz)))
	_check("300 random rays all hit ground (no collision gaps)", misses == 0, "misses=%d" % misses)
	_check("collision height matches height field", worst < 0.1, "worst=%.3f m" % worst)
	var corners_ok := true
	for c in [Vector2(-79.9, -79.9), Vector2(79.9, -79.9), Vector2(-79.9, 79.9), Vector2(79.9, 79.9)]:
		if is_nan(_ground_y(c.x, c.y)):
			corners_ok = false
	_check("ground exists at all four corners", corners_ok)

	# --- Ramps --------------------------------------------------------------------------------
	var small: RampWedge = main.get_node_or_null("FarmWorld/Ramps/RampSmall")
	var medium: RampWedge = main.get_node_or_null("FarmWorld/Ramps/RampMedium")
	_check("two ramps exist with real collision", small != null and medium != null
			and small.get_node("CollisionShape3D").shape is ConvexPolygonShape3D
			and medium.get_node("CollisionShape3D").shape is ConvexPolygonShape3D)
	var aim: Vector3 = medium.global_basis * Vector3.FORWARD
	_check("ramps face +X (run-up from the west)", aim.dot(Vector3.RIGHT) > 0.99, "aim=%s" % aim)
	var monotone := true
	var prev := -1.0
	var err := 0.0
	for xi: float in [36.5, 38.0, 40.0, 42.0, 43.5]:
		var ry := _ground_y(xi, 0.0)
		var expected: float = 1.5 * (xi - 36.0) / 8.0
		err = maxf(err, absf(ry - expected))
		if ry <= prev:
			monotone = false
		prev = ry
	_check("medium ramp surface rises linearly to 1.5 m", monotone and err < 0.05, "err=%.3f" % err)
	var small_mid := _ground_y(40.0, -9.0)
	_check("small ramp mid height ~0.25 m", absf(small_mid - 0.25) < 0.04, "y=%.3f" % small_mid)
	_check("ramp is only 4 m wide (ground beside it)", absf(_ground_y(40.0, 3.0)) < 0.05
			and _ground_y(40.0, 1.5) > 0.5)
	_check("vertical drop behind the lip (landing area is ground)", absf(_ground_y(45.0, 0.0)) < 0.05)
	_check("three distinct ramp features (0.5 m, 1.5 m, 2.0 m)",
			small.ramp_height < medium.ramp_height and medium.ramp_height < FarmLayout.MOUND.z + 0.01)

	# --- Boundaries -------------------------------------------------------------------------
	var walls: StaticBody3D = main.get_node_or_null("FarmWorld/BoundaryWalls")
	_check("boundary walls: 4 collision shapes", walls != null and walls.get_child_count() == 4)

	# --- On-foot traversal: flat ground, slopes, ramps, jump, boundaries ------------------------
	await _teleport(0.0, 0.0)
	var flat_stats := await _walk_to(Vector2(0, -14), 400)
	_check("walks across the start area (on floor, y ~ 0)", flat_stats.reached
			and flat_stats.on_floor >= flat_stats.frames - 2 and absf(flat_stats.max_y) < 0.05, str(flat_stats))

	await _teleport(-14.0, 3.0)
	var h_start := _player.global_position.y
	var up_stats := await _walk_to(Vector2(-56, -30), 1500, 1.5)
	var h_end := _player.global_position.y
	_check("walks up the hill path (reaches top, rises > 3 m)", up_stats.reached and h_end - h_start > 3.0,
			"%.2f -> %.2f m, frames=%d" % [h_start, h_end, up_stats.frames])
	_check("uphill: stays on the ground (>= 90% grounded, never inside terrain)",
			up_stats.on_floor >= 0.9 * up_stats.frames and up_stats.min_clearance > -0.05,
			"grounded=%d/%d clearance=%.3f" % [up_stats.on_floor, up_stats.frames, up_stats.min_clearance])

	# Jump on a slope (grounded jump must still work and land again).
	var y_before := _player.global_position.y
	var max_rise := 0.0
	var jump_event := InputEventAction.new()
	jump_event.action = "jump"
	jump_event.pressed = true
	Input.parse_input_event(jump_event)
	for i in 45:
		await _frames(1)
		max_rise = maxf(max_rise, _player.global_position.y - y_before)
	jump_event.pressed = false
	Input.parse_input_event(jump_event)
	await _frames(40)
	_check("jump works on the hilltop and lands again", max_rise > 0.4 and _player.is_on_floor(),
			"rise=%.2f" % max_rise)

	var down_stats := await _walk_to(Vector2(-14, 3), 1500, 1.5)
	_check("walks down the hill (reaches bottom, descends > 3 m)", down_stats.reached
			and _player.global_position.y < 1.0, "y=%.2f" % _player.global_position.y)
	_check("downhill: stays on the ground (>= 80% grounded, never inside terrain)",
			down_stats.on_floor >= 0.8 * down_stats.frames and down_stats.min_clearance > -0.05,
			"grounded=%d/%d clearance=%.3f" % [down_stats.on_floor, down_stats.frames, down_stats.min_clearance])

	await _teleport(30.0, 0.0)
	var ramp_stats := await _walk_to(Vector2(50, 0), 500)
	_check("walks over the medium ramp (peaks ~1.5 m, ends on landing area)",
			ramp_stats.max_y > 1.3 and ramp_stats.reached, "max_y=%.2f" % ramp_stats.max_y)
	await _teleport(30.0, -9.0)
	var small_stats := await _walk_to(Vector2(50, -9), 500)
	_check("walks over the small ramp (peaks ~0.5 m)", small_stats.max_y > 0.4 and small_stats.max_y < 0.8
			and small_stats.reached, "max_y=%.2f" % small_stats.max_y)
	await _teleport(47.0, 4.0)
	var mound_stats := await _walk_to(Vector2(47, 29), 700)
	_check("walks over the mound (peaks > 1.8 m, stays grounded)", mound_stats.max_y > 1.8
			and mound_stats.reached and mound_stats.on_floor >= 0.9 * mound_stats.frames,
			"max_y=%.2f grounded=%d/%d" % [mound_stats.max_y, mound_stats.on_floor, mound_stats.frames])

	# Boundaries: walk straight into each edge for a long time; must stay inside and above ground.
	var edges_ok := true
	var edge_report := ""
	for e in [[Vector2(0, -70), Vector2(0, -120)], [Vector2(0, 70), Vector2(0, 120)],
			[Vector2(-70, 0), Vector2(-120, 0)], [Vector2(70, 0), Vector2(120, 0)]]:
		await _teleport(e[0].x, e[0].y)
		await _walk_to(e[1], 330, 0.1)
		var px := _player.global_position.x
		var pz := _player.global_position.z
		var py := _player.global_position.y
		var inside := absf(px) < 80.6 and absf(pz) < 80.6 and py > -0.5 and py < 6.0
		if not inside:
			edges_ok = false
		edge_report += " (%.1f,%.1f,%.1f)" % [px, py, pz]
	_check("player cannot leave the map at any edge", edges_ok, edge_report)

	var finite := _player.global_position.is_finite() and _player.velocity.is_finite()
	_check("player state finite at the end", finite)
	_finish()
