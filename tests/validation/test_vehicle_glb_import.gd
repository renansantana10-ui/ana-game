extends SceneTree
## ANA-GAME-003-A: import integrity tests for the official vehicle GLB (inspection only, no gameplay).
## Run: godot --headless --path <project> --script res://tests/validation/test_vehicle_glb_import.gd
## Exit code 0 = no FAIL, 1 = at least one FAIL. Statuses: PASS / FAIL / NOT VERIFIED (+ INFO lines).
## Works against the real imported GLB. Temporary pivot rotations happen only on an in-memory instance
## and are restored; nothing is saved to the asset.

const GLB_PATH := "res://assets/vehicles/ana-veiculo-integracao-v01.glb"
const SOURCE_GLB := "D:/ana game/producao-assets-3d/exports-glb/ana-veiculo-integracao-v01.glb"
const SOURCE_SHA256 := "e1725ef7618c869daff49477002eb977c2633bc0ee4a11e9b6d2c2ee2ace846e"
const SOURCE_SIZE := 400436
const A_COMMIT := "76fa645bbd2a3f889b399c7b6bf7b1ffee94a86a"  ## ANA-GAME-003-A commit (this file is edited after it)

const REF_DIMS := Vector3(0.40, 0.578, 0.745)  ## Blender-side report (X, Y, Z)
const REF_TRIANGLES := 25772
const REF_MATERIALS := 5
const REF_WHEEL_RADIUS := 0.12
const REF_SEAT_Y := 0.2876
const WHEEL_NAMES: Array[String] = ["FrontLeftWheel", "FrontRightWheel", "RearLeftWheel", "RearRightWheel"]

var _pass := 0
var _fail := 0
var _nv := 0
var _vehicle: Node3D
var _scene_root: Node3D


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])


func _not_verified(label: String, detail: String = "") -> void:
	_nv += 1
	print("[NOT VERIFIED] %s %s" % [label, detail])


func _info(label: String, detail: String = "") -> void:
	print("[INFO] %s %s" % [label, detail])


func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


func _meshes_of(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(_meshes_of(c))
	return out


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_all_nodes(c))
	return out


## Exact vertex bounds of one mesh instance, expressed in the space of `space_root`.
func _bounds(space_root: Node3D, mi: MeshInstance3D) -> AABB:
	var xf: Transform3D = space_root.global_transform.affine_inverse() * mi.global_transform
	var box := AABB()
	var first := true
	for s in mi.mesh.get_surface_count():
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p: Vector3 = xf * v
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


func _bounds_all(space_root: Node3D, node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes_of(node):
		var b := _bounds(space_root, mi)
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _tri_count(mi: MeshInstance3D) -> int:
	var tris := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			tris += idx.size() / 3
		else:
			tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _mat_of(mi: MeshInstance3D, s: int) -> Material:
	var m := mi.get_active_material(s)
	if m == null:
		m = mi.mesh.surface_get_material(s)
	return m


func _find(name: String) -> Node3D:
	return _vehicle.find_child(name, true, false) as Node3D


func _spin_of(wheel: Node3D) -> Node3D:
	for c in wheel.get_children():
		if c is Node3D:
			return c as Node3D
	return null


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("[FAIL] test timeout")
		quit(1))
	print("== ANA-GAME-003-A - Vehicle GLB import integrity ==")
	print("Godot ", Engine.get_version_info().string, " | renderer: ",
			ProjectSettings.get_setting("rendering/renderer/rendering_method"))

	# ---------- Test 01 - resource availability ----------
	print("-- Test 01: resource availability")
	_check("T01 GLB resource exists", ResourceLoader.exists(GLB_PATH), GLB_PATH)
	var packed = load(GLB_PATH)
	_check("T01 GLB loads as PackedScene", packed is PackedScene)
	if not (packed is PackedScene):
		_summary()
		return
	_vehicle = (packed as PackedScene).instantiate() as Node3D
	_check("T01 scene instantiable, root is Node3D", _vehicle != null,
			"root=%s class=%s" % [_vehicle.name if _vehicle else "-", _vehicle.get_class() if _vehicle else "-"])
	if _vehicle == null:
		_summary()
		return
	_scene_root = Node3D.new()
	_scene_root.name = "TestRoot"
	get_root().add_child(_scene_root)
	_scene_root.add_child(_vehicle)
	await process_frame
	await process_frame

	_print_hierarchy()

	# ---------- Test 02 - geometry ----------
	print("-- Test 02: geometry integrity")
	var meshes := _meshes_of(_vehicle)
	_check("T02 at least one valid mesh", meshes.size() > 0, "mesh instances=%d" % meshes.size())
	var tri_instances := 0
	var unique_meshes := {}
	var all_valid := true
	for mi in meshes:
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			all_valid = false
			continue
		var b := _bounds(_vehicle, mi)
		if not _finite(b.position) or not _finite(b.size) or b.size.length() < 0.001:
			all_valid = false
		var t := _tri_count(mi)
		tri_instances += t
		unique_meshes[mi.mesh] = t
	_check("T02 every mesh has surfaces and finite, non-degenerate bounds", all_valid)
	var tri_unique := 0
	for k in unique_meshes:
		tri_unique += unique_meshes[k]
	_info("triangles", "instance-level (each MeshInstance3D counted) = %d | unique mesh resources = %d (%d resources)"
			% [tri_instances, tri_unique, unique_meshes.size()])
	_check("T02 triangle count matches Blender-side %d (instance-level)" % REF_TRIANGLES, tri_instances == REF_TRIANGLES,
			"actual=%d" % tri_instances)
	for part in ["PinkBody", "ElongatedSeat", "TriangularHandlebar", "HandlebarGrip"]:
		var n := _find(part)
		_check("T02 part present: %s" % part, n is MeshInstance3D)
	var wheel_meshes := 0
	for wn in WHEEL_NAMES:
		var w := _find(wn)
		if w and _meshes_of(w).size() > 0:
			wheel_meshes += 1
	_check("T02 four wheel assemblies with geometry", wheel_meshes == 4, "found=%d" % wheel_meshes)
	var forbidden := []
	for n in _all_nodes(_vehicle):
		if n is AnimationPlayer or n is Light3D or n is Camera3D or n is CollisionObject3D or n is CollisionShape3D \
				or n is Skeleton3D or n is Area3D:
			forbidden.append("%s[%s]" % [n.name, n.get_class()])
	_check("T02 no animation/light/camera/collision/skeleton nodes (contract section 10)", forbidden.is_empty(), str(forbidden))

	# ---------- Test 03 - materials ----------
	print("-- Test 03: material integrity")
	var mats := {}  # name -> {mat, users}
	var missing := 0
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var m := _mat_of(mi, s)
			if m == null:
				missing += 1
				continue
			var key: String = m.resource_name if m.resource_name != "" else str(m)
			if not mats.has(key):
				mats[key] = {"mat": m, "users": []}
			mats[key]["users"].append("%s/s%d" % [mi.name, s])
	_check("T03 no surface without material", missing == 0, "missing=%d" % missing)
	for key in mats:
		var m = mats[key]["mat"]
		var line := "%s | %s" % [key, m.get_class()]
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			line += " | albedo=%s rough=%.2f metal=%.2f transparency=%d albedo_tex=%s normal_tex=%s" % [
					bm.albedo_color, bm.roughness, bm.metallic, bm.transparency, bm.albedo_texture, bm.normal_texture]
		line += " | used by %s" % str(mats[key]["users"])
		_info("material", line)
	_check("T03 unique material count vs reference %d" % REF_MATERIALS, mats.size() == REF_MATERIALS, "actual=%d" % mats.size())
	var pink_ok := false
	var mint_ok := false
	for key in mats:
		var m = mats[key]["mat"]
		if m is BaseMaterial3D:
			var c := (m as BaseMaterial3D).albedo_color
			if key.contains("Rosa_") and c.r > 0.7 and c.r > c.g + 0.15:
				pink_ok = true
			if key.contains("VerdeMenta") and c.g > c.r + 0.05 and c.g > 0.6:
				mint_ok = true
	_check("T03 pink body material identifiable by color", pink_ok)
	_check("T03 mint-green wheel material identifiable by color", mint_ok)
	var body_mat := _mat_of(_find("PinkBody") as MeshInstance3D, 0)
	var seat_mat := _mat_of(_find("ElongatedSeat") as MeshInstance3D, 0)
	_check("T03 body and seat use the pink material", body_mat != null and seat_mat != null
			and body_mat.resource_name.contains("Rosa") and seat_mat.resource_name.contains("Rosa"),
			"body=%s seat=%s" % [body_mat.resource_name if body_mat else "-", seat_mat.resource_name if seat_mat else "-"])

	# ---------- Test 04 - wheels ----------
	print("-- Test 04: wheel pivot integrity")
	var wheels: Array[Node3D] = []
	var spins: Array[Node3D] = []
	var wheel_mesh_nodes: Array[MeshInstance3D] = []
	var wheel_radii: Array[float] = []
	var struct_ok := true
	for wn in WHEEL_NAMES:
		var w := _find(wn)
		if w == null:
			struct_ok = false
			continue
		wheels.append(w)
		var sp := _spin_of(w)
		spins.append(sp)
		var wm := _meshes_of(w)
		if sp == null or wm.size() != 1:
			struct_ok = false
			continue
		wheel_mesh_nodes.append(wm[0])
		var local := _bounds(w, wm[0])
		var center := local.get_center()
		var radius := minf(local.size.y, local.size.z) * 0.5
		wheel_radii.append(radius)
		_info("wheel", "%s pivot_local=%s spin=%s mesh=%s surfaces=%d | mesh bounds in pivot space: center=%s size=%s radius_yz=%.4f"
				% [wn, w.position, sp.name if sp else "-", wm[0].name, wm[0].mesh.get_surface_count(), center, local.size, radius])
		if absf(center.y) > 0.005 or absf(center.z) > 0.005 or absf(center.x) > 0.01:
			struct_ok = false
		if not (local.size.x < local.size.y and local.size.x < local.size.z):
			struct_ok = false  # axle must be the narrow X axis
		if not _finite(w.position):
			struct_ok = false
	_check("T04 four distinct wheel pivots, each with a Spin child and one wheel mesh centered on the pivot, axle = X",
			struct_ok and wheels.size() == 4 and wheel_mesh_nodes.size() == 4)
	if wheels.size() == 4 and wheel_mesh_nodes.size() == 4:
		_check("T04 all pivot transforms finite and unscaled", wheels.all(func(w: Node3D) -> bool:
				return _finite(w.position) and w.scale.is_equal_approx(Vector3.ONE)))
		var fl := wheels[0].position
		var fr := wheels[1].position
		var rl := wheels[2].position
		var rr := wheels[3].position
		_check("T04 layout plausible: left/right mirrored, front axle ahead (-Z) of rear",
				is_equal_approx(fl.x, -fr.x) and is_equal_approx(rl.x, -rr.x) and fl.x < 0.0 and rl.x < 0.0
				and fl.z < rl.z and is_equal_approx(fl.z, fr.z) and is_equal_approx(rl.z, rr.z),
				"FL=%s FR=%s RL=%s RR=%s" % [fl, fr, rl, rr])
		_info("wheel geometry", "wheelbase=%.4f front_track=%.4f rear_track=%.4f center_y=%.4f" % [rl.z - fl.z, fr.x - fl.x, rr.x - rl.x, fl.y])
		_check("T04 tire mesh has 2 surfaces (tire + hub) in one node; Tire/Hub are NOT separate nodes (contract section 4 deviation)",
				wheel_mesh_nodes.all(func(m: MeshInstance3D) -> bool: return m.mesh.get_surface_count() == 2))
		var spin_names: Array[String] = []
		for sp in spins:
			spin_names.append(String(sp.name))
		_info("spin node names", str(spin_names) + " (contract expects exact 'Spin' under each pivot; map by first child)")
		# Independence: spin roll and steer yaw on an in-memory instance, restored afterwards.
		var orig: Array[Transform3D] = []
		for m in wheel_mesh_nodes:
			orig.append(m.global_transform)
		var indep := true
		var restored := true
		for i in 4:
			spins[i].rotation.x = 1.0
			for j in 4:
				var changed := not wheel_mesh_nodes[j].global_transform.is_equal_approx(orig[j])
				if (j == i) != changed:
					indep = false
			spins[i].rotation.x = 0.0
			wheels[i].rotation.y = 0.5
			for j in 4:
				var changed2 := not wheel_mesh_nodes[j].global_transform.is_equal_approx(orig[j])
				if (j == i) != changed2:
					indep = false
			if not wheels[i].global_position.is_equal_approx(wheels[i].get_parent_node_3d().global_transform * wheels[i].position):
				indep = false  # pivot must stay on its axle when steering
			wheels[i].rotation.y = 0.0
		for j in 4:
			if not wheel_mesh_nodes[j].global_transform.is_equal_approx(orig[j]):
				restored = false
		_check("T04 rotating one wheel's Spin/pivot moves only that wheel (all 4 tested, roll + yaw)", indep)
		_check("T04 original wheel transforms restored after temporary rotations", restored)

	# ---------- Test 05 - handlebar ----------
	print("-- Test 05: handlebar hierarchy")
	var hp := _find("HandlebarPivot")
	_check("T05 HandlebarPivot exists (Node3D)", hp != null and hp.get_class() == "Node3D")
	if hp:
		_info("HandlebarPivot", "path=%s local=%s global=%s rotdeg=%s parent=%s" % [
				_vehicle.get_path_to(hp), hp.position, _local_to_vehicle(hp), hp.rotation_degrees, hp.get_parent().name])
		_check("T05 transform finite, identity rotation/scale", _finite(hp.position) and hp.rotation.is_zero_approx()
				and hp.scale.is_equal_approx(Vector3.ONE))
		var grip := _find("HandlebarGrip")
		var tri := _find("TriangularHandlebar")
		var post_up := _find("SteeringPostUpper")
		var post_low := _find("SteeringPostLower")
		var under := grip != null and tri != null and post_up != null \
				and hp.is_ancestor_of(grip) and hp.is_ancestor_of(tri) and hp.is_ancestor_of(post_up)
		_check("T05 grip, triangular handlebar and upper post are under HandlebarPivot", under)
		_check("T05 chassis, seat and lower post are NOT under HandlebarPivot", post_low != null and not hp.is_ancestor_of(post_low)
				and not hp.is_ancestor_of(_find("PinkBody")) and not hp.is_ancestor_of(_find("ElongatedSeat")))
		if post_up is MeshInstance3D and post_low is MeshInstance3D:
			var pu := _bounds(hp, post_up as MeshInstance3D)
			var pl := _bounds(_vehicle, post_low as MeshInstance3D)
			var axis_off := Vector2(pu.get_center().x, pu.get_center().z).length()
			var joint_gap := absf((pl.position.y + pl.size.y) - hp.position.y)
			_info("steering axis", "upper-post center offset from pivot axis XZ=%.4f m; lower-post top vs pivot Y gap=%.4f m" % [axis_off, joint_gap])
			_check("T05 pivot sits on the post axis and at the post joint (yaw steering axis = local Y)", axis_off < 0.005 and joint_gap < 0.005)
		var body_before := (_find("PinkBody") as Node3D).global_transform
		var grip_before := (grip as Node3D).global_transform
		hp.rotation.y = 0.4
		var steered := not (grip as Node3D).global_transform.is_equal_approx(grip_before)
		var chassis_still := (_find("PinkBody") as Node3D).global_transform.is_equal_approx(body_before)
		hp.rotation.y = 0.0
		_check("T05 temporary yaw of HandlebarPivot moves the handlebar only (restored)", steered and chassis_still
				and (grip as Node3D).global_transform.is_equal_approx(grip_before))

	# ---------- Test 06 - SeatAnchor ----------
	print("-- Test 06: SeatAnchor")
	var sa := _find("SeatAnchor")
	_check("T06 SeatAnchor exists and is a Node3D", sa != null)
	if sa:
		var sa_v := _local_to_vehicle(sa)
		var seat_b := _bounds(_vehicle, _find("ElongatedSeat") as MeshInstance3D)
		var body_b := _bounds(_vehicle, _find("PinkBody") as MeshInstance3D)
		_info("SeatAnchor", "path=%s class=%s local=%s vehicle-space=%s rotdeg=%s parent=%s" % [
				_vehicle.get_path_to(sa), sa.get_class(), sa.position, sa_v, sa.rotation_degrees, sa.get_parent().name])
		_info("seat geometry (vehicle space)", "seat bounds=%s | seat top y=%.4f | anchor is %.4f m below seat top | body bounds=%s" % [
				seat_b, seat_b.end.y, seat_b.end.y - sa_v.y, body_b])
		_check("T06 transform finite, identity rotation", _finite(sa.position) and sa.rotation.is_zero_approx())
		_check("T06 anchor plausible: within seat mesh in X/Y/Z extent", absf(sa_v.x) < 0.05 and sa_v.y > seat_b.position.y
				and sa_v.y <= seat_b.end.y and sa_v.z > seat_b.position.z and sa_v.z < seat_b.end.z)
		_check("T06 Y matches reference %.4f (+/-0.001)" % REF_SEAT_Y, absf(sa_v.y - REF_SEAT_Y) < 0.001, "actual=%.4f" % sa_v.y)

	# ---------- Test 07 - dimensions / scale ----------
	print("-- Test 07: dimensions and scale")
	_check("T07 root transform is identity (scale 1, no offset)", _vehicle.transform.is_equal_approx(Transform3D.IDENTITY))
	var all_ok := true
	for n in _all_nodes(_vehicle):
		if n is Node3D:
			var n3 := n as Node3D
			if not (_finite(n3.position) and _finite(n3.scale) and n3.scale.x > 0.0 and n3.scale.y > 0.0 and n3.scale.z > 0.0):
				all_ok = false
	_check("T07 all node transforms finite with positive scale", all_ok)
	var vb := _bounds_all(_vehicle, _vehicle)
	_info("vehicle bounds (GLB root space, mesh vertices)", "min=%s max=%s size X/Y/Z=%s" % [vb.position, vb.end, vb.size])
	var dd := vb.size - REF_DIMS
	_info("dimension delta vs Blender report", "dX=%.4f (%.2f%%) dY=%.4f (%.2f%%) dZ=%.4f (%.2f%%)" % [
			dd.x, 100.0 * dd.x / REF_DIMS.x, dd.y, 100.0 * dd.y / REF_DIMS.y, dd.z, 100.0 * dd.z / REF_DIMS.z])
	_check("T07 dimensions within 2% of Blender report 0.40 x 0.578 x 0.745 (X,Y,Z)",
			absf(dd.x / REF_DIMS.x) < 0.02 and absf(dd.y / REF_DIMS.y) < 0.02 and absf(dd.z / REF_DIMS.z) < 0.02)
	_check("T07 child-sized scale (each axis 0.3..1.2 m)", vb.size.x > 0.3 and vb.size.y > 0.3 and vb.size.z > 0.3
			and vb.size.x < 1.2 and vb.size.y < 1.2 and vb.size.z < 1.2)
	if wheel_mesh_nodes.size() == 4:
		var lowest := INF
		for m in wheel_mesh_nodes:
			lowest = minf(lowest, _bounds(_vehicle, m).position.y)
		var r_eff := wheel_radii[0]
		_info("wheel radius", "effective (mesh) = %.4f m | pivot height = %.4f | lowest tire point y = %.4f" % [r_eff, wheels[0].position.y, lowest])
		_check("T07 effective wheel radius within 5% of 0.12 m", absf(r_eff - REF_WHEEL_RADIUS) / REF_WHEEL_RADIUS < 0.05, "actual=%.4f" % r_eff)
		_check("T07 tires touch the ground plane y=0 (|lowest| <= 0.01)", absf(lowest) <= 0.01, "lowest=%.4f" % lowest)

	# Existing placeholder (real scene, in memory, physics disabled) for comparison.
	var ph_pack := load("res://scenes/ride_on_vehicle.tscn") as PackedScene
	var ph := ph_pack.instantiate() as Node3D
	ph.process_mode = Node.PROCESS_MODE_DISABLED
	_scene_root.add_child(ph)
	ph.position = Vector3(5, 0, 0)
	await process_frame
	await process_frame
	var ph_visual := ph.get_node("VehicleVisualRoot") as Node3D
	var ph_b := _bounds_all(ph_visual, ph_visual)
	var ph_seat := ph.get_node("VehicleVisualRoot/SeatAnchor") as Node3D
	var ph_r: float = ph_visual.get("wheel_radius")
	_info("PLACEHOLDER (RideOnVisual) bounds in VehicleVisualRoot space", "size=%s min=%s max=%s" % [ph_b.size, ph_b.position, ph_b.end])
	_info("PLACEHOLDER wheel_radius / SeatAnchor", "radius=%.3f seat_anchor(local to VehicleVisualRoot)=%s class=%s" % [ph_r, ph_seat.position, ph_seat.get_class()])
	var capsule := (ph.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	_info("PLACEHOLDER capsule", "radius=%.2f height=%.2f (physics body untouched)" % [capsule.radius, capsule.height])
	_info("GLB vs PLACEHOLDER", "size ratio X/Y/Z = %.3f / %.3f / %.3f | wheel radius delta = %.4f m (%.1f%% of placeholder) | seat anchor delta = %s" % [
			vb.size.x / ph_b.size.x, vb.size.y / ph_b.size.y, vb.size.z / ph_b.size.z, REF_WHEEL_RADIUS - ph_r,
			100.0 * (wheel_radii[0] - ph_r) / ph_r if wheel_radii.size() > 0 else 0.0, _local_to_vehicle(sa) - ph_seat.position])
	ph.queue_free()

	# ---------- Test 08 - orientation ----------
	print("-- Test 08: orientation (what can be measured)")
	var basis_ok := _vehicle.global_basis.is_equal_approx(Basis.IDENTITY)
	_check("T08 root basis identity (no hidden rotation / mirrored axes)", basis_ok and _vehicle.global_basis.determinant() > 0.0)
	if hp and sa and wheels.size() == 4:
		var lamp := _find("FrontLamp") as MeshInstance3D
		var lamp_z := _bounds(_vehicle, lamp).get_center().z
		_info("orientation markers (vehicle-space Z)", "HandlebarPivot z=%.3f | FrontLamp z=%.3f | SeatAnchor z=%.3f | front wheels z=%.3f | rear wheels z=%.3f"
				% [_local_to_vehicle(hp).z, lamp_z, _local_to_vehicle(sa).z, wheels[0].position.z, wheels[2].position.z])
		_check("T08 handlebar, front lamp and wheels named 'Front*' are on the -Z side; seat on +Z (front = -Z, like the placeholder)",
				_local_to_vehicle(hp).z < 0.0 and lamp_z < 0.0 and _local_to_vehicle(sa).z > 0.0 and wheels[0].position.z < 0.0 and wheels[2].position.z > 0.0)
		_check("T08 up = +Y (seat/handlebar above wheel centers)", _local_to_vehicle(sa).y > wheels[0].position.y and _local_to_vehicle(hp).y > wheels[0].position.y)
	_not_verified("T08 semantic front/left/right of the physical shape", "confirm visually in the Godot screenshots (validation/ana-game-003-a/screenshots)")

	# ---------- Test 09 - source preservation ----------
	print("-- Test 09: source preservation")
	var copy_hash := FileAccess.get_sha256(GLB_PATH)
	_check("T09 project copy SHA-256 equals recorded source hash", copy_hash == SOURCE_SHA256, copy_hash)
	var cf := FileAccess.open(GLB_PATH, FileAccess.READ)
	_check("T09 project copy size = %d" % SOURCE_SIZE, cf != null and cf.get_length() == SOURCE_SIZE)
	if FileAccess.file_exists(SOURCE_GLB):
		var src_hash := FileAccess.get_sha256(SOURCE_GLB)
		_check("T09 original source GLB unchanged (hash equals recorded value and the project copy)", src_hash == SOURCE_SHA256 and src_hash == copy_hash, src_hash)
	else:
		_not_verified("T09 original source GLB not accessible", SOURCE_GLB)

	# ---------- Test 10 - gameplay isolation ----------
	print("-- Test 10: gameplay isolation")
	_gameplay_isolation()

	# ---------- Test 11 - refined preview scenes (FIX-01) ----------
	print("-- Test 11: preview scenes")
	for scene_path in ["res://scenes/validation/ana_vehicle_glb_preview.tscn", "res://scenes/validation/ana_vehicle_glb_preview_refined.tscn"]:
		var ps := load(scene_path) as PackedScene
		_check("T11 loads: %s" % scene_path, ps != null)
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		_scene_root.add_child(inst)
		await process_frame
		var veh_inst := inst.get_node_or_null("Vehicle")
		_check("T11 official GLB instanced as 'Vehicle' (scene_file_path = the GLB)", veh_inst != null and String(veh_inst.scene_file_path) == GLB_PATH)
		var overridden := 0
		var stock_mats := {}
		for mi in _meshes_of(veh_inst):
			if mi.material_override != null:
				overridden += 1
			for s in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(s) != null:
					overridden += 1
				stock_mats[mi.mesh.surface_get_material(s)] = true
		_check("T11 official materials preserved (no material_override / surface overrides)", overridden == 0 and stock_mats.size() == REF_MATERIALS,
				"overrides=%d materials=%d" % [overridden, stock_mats.size()])
		_check("T11 has Camera3D, light and WorldEnvironment; no vehicle controller / physics body",
				inst.find_children("*", "Camera3D", true, false).size() == 1 and inst.find_children("*", "DirectionalLight3D", true, false).size() >= 1
				and inst.find_children("*", "WorldEnvironment", true, false).size() == 1
				and inst.find_children("*", "PhysicsBody3D", true, false).is_empty())
		_check("T11 vehicle transform untouched by preview scene (identity)", (veh_inst as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
		inst.queue_free()

	_summary()


func _local_to_vehicle(n: Node3D) -> Vector3:
	return (_vehicle.global_transform.affine_inverse() * n.global_transform).origin


func _print_hierarchy() -> void:
	print("-- Hierarchy (path | class | local pos | rot deg | scale | vehicle-space pos | mesh)")
	for n in _all_nodes(_vehicle):
		var line := "%s | %s" % [str(_vehicle.get_path_to(n)), n.get_class()]
		if n is Node3D:
			var n3 := n as Node3D
			line += " | pos=%s rot=%s scl=%s gpos=%s" % [n3.position, n3.rotation_degrees, n3.scale, _local_to_vehicle(n3)]
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			line += " | mesh=%s surfaces=%d tris=%d" % [mi.mesh.resource_name, mi.mesh.get_surface_count(), _tri_count(mi)]
		print("   ", line)


func _git(args: Array) -> Array:
	var out: Array = []
	var full: Array = ["-C", ProjectSettings.globalize_path("res://")]
	full.append_array(args)
	var code := OS.execute("git", PackedStringArray(full), out, true)
	return [code, (out[0] if out.size() > 0 else "")]


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


func _gameplay_isolation() -> void:
	# Since ANA-GAME-003-B the playable vehicle uses the GLB on purpose; its isolation checks live in
	# tests/validation/test_vehicle_official_visual.gd. Here: the 003-A deliverables must stay as committed.
	var main_txt := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_check("T10 main scene is still res://scenes/main.tscn", str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main.tscn")
	_check("T10 main.tscn does not reference the GLB or preview", not main_txt.contains("ana-veiculo-integracao") and not main_txt.contains("ana_vehicle_glb_preview"))
	var res := _git_changed_paths(["diff", "--name-only", A_COMMIT, "--", "assets/vehicles", "scenes/validation"])
	if res[0] != 0:
		_not_verified("T10 git diff unavailable", "exit=%s" % str(res[0]))
		return
	_check("T10 ANA-GAME-003-A assets and preview scenes unchanged since commit %s" % A_COMMIT.substr(0, 7),
			res[1].is_empty(), ", ".join(res[1]))

func _summary() -> void:
	print("== RESULT: %d PASS, %d FAIL, %d NOT VERIFIED ==" % [_pass, _fail, _nv])
	quit(1 if _fail > 0 else 0)
