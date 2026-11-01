extends SceneTree
## Regression test ANA-GAME-001-FIX-01: the third-person camera rig must follow the player's CameraTarget.
## Run: godot --headless --path <project> --script res://tests/test_camera_follow.gd
## Exit code 0 = pass, 1 = fail. Does not need mouse capture or a GUI.

const FOLLOW_TOLERANCE := 0.15  # meters, after settling
const MIN_DISPLACEMENT := 1.0   # meters the player must travel for the test to be meaningful
const TIMEOUT_MSEC := 20000

var _failures := 0
var _started_msec := 0


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
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	# Step 1: load the real gameplay scene.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player: CharacterBody3D = main.get_node_or_null("Player")
	var target: Node3D = main.get_node_or_null("Player/CameraTarget")
	var rig: ThirdPersonCamera = main.get_node_or_null("ThirdPersonCamera")
	_check("player, CameraTarget and camera rig found", player != null and target != null and rig != null)
	if player == null or target == null or rig == null:
		_finish()
		return
	_check("rig.target is the active player's CameraTarget", rig.target == target,
			"rig.target=%s" % rig.target)
	var yaw: Node3D = rig.get_node("YawPivot")
	var pitch: Node3D = rig.get_node("YawPivot/PitchPivot")
	var camera: Camera3D = rig.get_node("YawPivot/PitchPivot/SpringArm3D/Camera3D")

	# Step 5 (setup): non-zero orbit so we can verify it is preserved.
	rig._rotate_view(Vector2(200.0, 60.0))
	await _frames(60)

	# Step 2: initial state.
	var yaw0 := yaw.rotation.y
	var pitch0 := pitch.rotation.x
	var player0 := player.global_position
	var target0 := target.global_position
	var rig0 := rig.global_position
	var cam_offset0 := camera.global_position - rig.global_position
	_check("rig starts at target", rig0.distance_to(target0) < FOLLOW_TOLERANCE,
			"rig=%s target=%s" % [rig0, target0])

	# Step 3: real input path. Camera yaw is non-zero, so W moves along the camera's forward.
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")

	# Step 4: settle, then verify follow.
	await _frames(120)
	var displacement := player.global_position.distance_to(player0)
	_check("player displaced", displacement > MIN_DISPLACEMENT, "d=%.2f m" % displacement)
	_check("CameraTarget moved with player", target.global_position.distance_to(target0) > MIN_DISPLACEMENT)
	_check("rig moved from original position", rig.global_position.distance_to(rig0) > MIN_DISPLACEMENT,
			"d=%.2f m" % rig.global_position.distance_to(rig0))
	var error := rig.global_position.distance_to(target.global_position)
	_check("follow error within tolerance", error < FOLLOW_TOLERANCE,
			"error=%.3f m (tolerance %.2f)" % [error, FOLLOW_TOLERANCE])
	var cam_offset1 := camera.global_position - rig.global_position
	_check("camera keeps orbit offset to rig", cam_offset1.distance_to(cam_offset0) < 0.1,
			"offset0=%s offset1=%s" % [cam_offset0, cam_offset1])

	# Step 5: orbit state untouched by translation.
	_check("yaw preserved", is_equal_approx(yaw.rotation.y, yaw0), "%.4f -> %.4f" % [yaw0, yaw.rotation.y])
	_check("pitch preserved", is_equal_approx(pitch.rotation.x, pitch0), "%.4f -> %.4f" % [pitch0, pitch.rotation.x])

	# Camera stays framed on the player: the target lies on the camera's view axis.
	var to_target := (target.global_position - camera.global_position).normalized()
	var alignment := to_target.dot(-camera.global_basis.z)
	_check("player framed on camera view axis", alignment > 0.99, "alignment=%.4f" % alignment)
	_finish()
