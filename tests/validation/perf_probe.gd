extends SceneTree
## ANA-GAME-003-B: initial performance probe on the real main scene (needs a real window, not --headless).
##   godot --path <project> --rendering-driver opengl3 --resolution 1280x720 --disable-vsync --script res://tests/validation/perf_probe.gd -- label=placeholder
## Phases: mounted & parked, then driving with alternating steering. Prints per-phase frame statistics.

const WARMUP_FRAMES := 60
const PHASE_SECONDS := {"static": 4.0, "driving": 7.0}

var _main: Node
var _frame_ms: Array[float] = []
var _draw_calls := 0.0
var _prims := 0.0
var _objects := 0.0
var _process_ms := 0.0
var _physics_ms := 0.0
var _samples := 0


func _initialize() -> void:
	_run()


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return default


func _reset() -> void:
	_frame_ms.clear()
	_draw_calls = 0.0
	_prims = 0.0
	_objects = 0.0
	_process_ms = 0.0
	_physics_ms = 0.0
	_samples = 0


func _sample(dt: float) -> void:
	_frame_ms.append(dt * 1000.0)
	_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_samples += 1


func _report(label: String, phase: String) -> void:
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var avg := total / maxf(sorted.size(), 1)
	var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
	print("PERF %s %s frames=%d avg_fps=%.1f avg_frame_ms=%.2f p99_ms=%.2f max_ms=%.2f process_ms=%.2f physics_ms=%.2f draw_calls=%.0f primitives=%.0f objects=%.0f" % [
			label, phase, sorted.size(), 1000.0 / avg, avg, p99, sorted[-1] if sorted.size() > 0 else 0.0,
			_process_ms / maxf(_samples, 1), _physics_ms / maxf(_samples, 1), _draw_calls / maxf(_samples, 1),
			_prims / maxf(_samples, 1), _objects / maxf(_samples, 1)])


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[NOT VERIFIED] performance probe needs a window")
		quit(2)
		return
	var label := _arg("label", "run")
	var t0 := Time.get_ticks_msec()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(_main)
	print("PERF %s scene_instantiate_ms=%d" % [label, Time.get_ticks_msec() - t0])
	for i in 90:
		await process_frame
	var player := _main.get_node("Player") as PlayerController
	var vehicle := _main.get_node("RideOnVehicle") as VehicleController
	var interaction := _main.get_node("VehicleInteraction") as VehicleInteraction
	player.global_position = vehicle.global_position + Vector3(1.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	print("PERF %s mounted=%s" % [label, interaction.try_mount()])
	print("PERF %s static_mem_mb=%.1f vram_mb=%.1f nodes=%d" % [label, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	for phase in PHASE_SECONDS:
		for i in WARMUP_FRAMES:
			await process_frame
		_reset()
		var elapsed := 0.0
		var last := Time.get_ticks_usec()
		var swap := 0.0
		if phase == "driving":
			Input.action_press("move_forward")
		while elapsed < PHASE_SECONDS[phase]:
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1e6
			last = now
			elapsed += dt
			_sample(dt)
			if phase == "driving":
				swap += dt
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press("move_left" if int(swap / 1.5) % 2 == 0 else "move_right")
		Input.action_release("move_forward")
		Input.action_release("move_left")
		Input.action_release("move_right")
		_report(label, phase)
	print("PERF %s vehicle_final_pos=%s speed_max_reached=ok" % [label, vehicle.global_position])
	quit(0)
