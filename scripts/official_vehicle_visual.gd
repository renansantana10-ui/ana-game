class_name OfficialVehicleVisual
extends RideOnVisual
## Presentation-only adapter between the arcade VehicleController and the official vehicle GLB
## (ANA-GAME-003-B). It replaces the primitive placeholder visual: it extends RideOnVisual only so the
## controller's existing `visual_root is RideOnVisual` / `update_wheels(speed, steer_angle, delta)` contract
## keeps working unchanged. It never builds the placeholder primitives, never reads input and never touches
## physics, collision, velocity or the camera.
##
## Imported hierarchy (verified in ANA-GAME-003-A), relative to the GLB instance:
##   Vehicle/{FrontLeft,FrontRight,RearLeft,RearRight}Wheel (pivot) -> Spin|Spin2|Spin3|Spin4 -> wheel mesh
##   Vehicle/HandlebarPivot (grip, triangular handlebar, upper post)   Vehicle/SeatAnchor
## The pivot names carry the physical role; the Spin node is the pivot's first Node3D child (its numeric
## suffix is not used). Axes: forward -Z, up +Y; wheels roll around local X, front pivots steer around Y.
## Rest transforms are recorded at start and every animated value is applied relative to them.

## GLB-relative paths, resolved once (never searched per frame).
const WHEEL_PIVOT_PATHS := {
	&"front_left": ^"Vehicle/FrontLeftWheel",
	&"front_right": ^"Vehicle/FrontRightWheel",
	&"rear_left": ^"Vehicle/RearLeftWheel",
	&"rear_right": ^"Vehicle/RearRightWheel",
}
const FRONT_ROLES: Array[StringName] = [&"front_left", &"front_right"]
const HANDLEBAR_PATH := ^"Vehicle/HandlebarPivot"
const SEAT_ANCHOR_PATH := ^"Vehicle/SeatAnchor"

@export_group("Official visual")
@export var glb_root_path: NodePath = ^"VisualAlignmentRoot/OfficialVehicleGLB"
@export var alignment_root_path: NodePath = ^"VisualAlignmentRoot"
@export var seat_marker_path: NodePath = ^"SeatAnchor"
## Rolling radius of the GLB tires in meters (measured from the mesh in ANA-GAME-003-A: 0.1226; the pivot
## sits at 0.12). Visual only: unrelated to the placeholder's 0.13 and to any physics value.
@export var visual_wheel_radius: float = 0.1226
## Visual-only lift of the whole GLB (m) so the tire bottoms meet the floor the kinematic body rests on.
@export var ground_lift: float = 0.0
## Extra offset applied to the effective seat transform, in VehicleVisualRoot space (m).
@export var seat_offset: Vector3 = Vector3.ZERO
## Handlebar yaw = steer_angle * ratio; it follows the (already smoothed) steering with this rate (1/s).
@export var handlebar_steer_ratio: float = 1.0
@export var handlebar_follow_rate: float = 24.0

## False when a mandatory node could not be resolved; the error is also pushed to the debugger.
var ready_ok: bool = false

var _alignment_root: Node3D
var _glb_root: Node3D
var _pivots: Dictionary = {}       ## role -> Node3D
var _spins: Dictionary = {}        ## role -> Node3D
var _pivot_rest: Dictionary = {}   ## role -> Transform3D
var _spin_rest: Dictionary = {}    ## role -> Transform3D
var _spin_angle: Dictionary = {}   ## role -> float (rad, wrapped to -PI..PI)
var _handlebar: Node3D
var _handlebar_rest: Transform3D
var _handlebar_angle: float = 0.0
var _glb_seat: Node3D
var _seat_marker: Marker3D


## Replaces RideOnVisual._ready(): the placeholder primitives are intentionally never built.
func _ready() -> void:
	wheel_radius = visual_wheel_radius
	_alignment_root = get_node_or_null(alignment_root_path) as Node3D
	_glb_root = get_node_or_null(glb_root_path) as Node3D
	if _alignment_root == null or _glb_root == null:
		_fail("alignment root / GLB instance missing (%s, %s)" % [alignment_root_path, glb_root_path])
		return
	_alignment_root.position = Vector3(0.0, ground_lift, 0.0)
	for role in WHEEL_PIVOT_PATHS:
		var pivot := _glb_root.get_node_or_null(WHEEL_PIVOT_PATHS[role]) as Node3D
		if pivot == null:
			_fail("wheel pivot '%s' not found at %s" % [role, WHEEL_PIVOT_PATHS[role]])
			return
		var spin: Node3D = null
		for child in pivot.get_children():
			if child is Node3D and String(child.name).begins_with("Spin"):
				spin = child
				break
		if spin == null:
			_fail("Spin node missing under %s" % pivot.name)
			return
		_pivots[role] = pivot
		_spins[role] = spin
		_pivot_rest[role] = pivot.transform
		_spin_rest[role] = spin.transform
		_spin_angle[role] = 0.0
	_handlebar = _glb_root.get_node_or_null(HANDLEBAR_PATH) as Node3D
	if _handlebar == null:
		_fail("HandlebarPivot not found at %s" % HANDLEBAR_PATH)
		return
	_handlebar_rest = _handlebar.transform
	_glb_seat = _glb_root.get_node_or_null(SEAT_ANCHOR_PATH) as Node3D
	_seat_marker = get_node_or_null(seat_marker_path) as Marker3D
	if _glb_seat == null or _seat_marker == null:
		_fail("SeatAnchor (GLB) or gameplay seat marker missing")
		return
	_seat_marker.transform = effective_seat_transform()
	ready_ok = true


## Same contract as RideOnVisual: `speed` is signed m/s along -Z (negative = reverse), `steer_angle` in
## radians (+ = left), `delta` the physics step. Rolls all four wheels, steers the front pair and the handlebar.
func update_wheels(speed: float, steer_angle: float, delta: float) -> void:
	if not ready_ok:
		return
	var roll := speed * delta / visual_wheel_radius
	for role in _spins:
		var angle := wrapf((_spin_angle[role] as float) - roll, -PI, PI)
		_spin_angle[role] = angle
		var rest: Transform3D = _spin_rest[role]
		(_spins[role] as Node3D).transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, angle), rest.origin)
	for role in FRONT_ROLES:
		var pivot_rest: Transform3D = _pivot_rest[role]
		(_pivots[role] as Node3D).transform = Transform3D(Basis(Vector3.UP, steer_angle) * pivot_rest.basis, pivot_rest.origin)
	_handlebar_angle = lerpf(_handlebar_angle, steer_angle * handlebar_steer_ratio,
			1.0 - exp(-handlebar_follow_rate * delta))
	_handlebar.transform = Transform3D(Basis(Vector3.UP, _handlebar_angle) * _handlebar_rest.basis, _handlebar_rest.origin)


## The GLB SeatAnchor expressed in this node's (VehicleVisualRoot) space, plus `seat_offset`. Rest-pose
## values are used, so the result does not depend on the current wheel/handlebar animation.
func effective_seat_transform() -> Transform3D:
	var t := _alignment_root.transform * _glb_root.transform * _glb_seat.get_parent_node_3d().transform * _glb_seat.transform
	t.origin += seat_offset
	return t


func get_wheel_pivot(role: StringName) -> Node3D:
	return _pivots.get(role)


func get_spin_node(role: StringName) -> Node3D:
	return _spins.get(role)


func get_spin_angle(role: StringName) -> float:
	return _spin_angle.get(role, 0.0)


func get_handlebar_pivot() -> Node3D:
	return _handlebar


func get_handlebar_angle() -> float:
	return _handlebar_angle


func _fail(reason: String) -> void:
	ready_ok = false
	push_error("OfficialVehicleVisual: " + reason)
