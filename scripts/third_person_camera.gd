class_name ThirdPersonCamera
extends Node3D
## Mouse-orbit third-person camera. Follows a logical target (e.g. the player's CameraTarget)
## and owns the mouse capture state. Mouse is only captured after a user click (Web-safe).

@export var target: Node3D
@export_group("Look")
@export var mouse_sensitivity: float = 0.0025  ## radians per pixel
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -70.0
@export_range(-30.0, 30.0) var max_pitch_degrees: float = 10.0
@export_range(-89.0, 30.0) var initial_pitch_degrees: float = -20.0
@export_group("Follow")
@export var follow_speed: float = 18.0
@export var distance: float = 3.5

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D

# Active follow profile. Eases toward the goal values so switching targets never pops.
var _active_distance: float
var _active_follow_speed: float
var _goal_distance: float
var _goal_follow_speed: float
var _excluded_body: CollisionObject3D


func _ready() -> void:
	_active_distance = distance
	_goal_distance = distance
	_active_follow_speed = follow_speed
	_goal_follow_speed = follow_speed
	_spring_arm.spring_length = distance
	_pitch_pivot.rotation.x = deg_to_rad(clampf(initial_pitch_degrees, min_pitch_degrees, max_pitch_degrees))
	if target:
		global_position = target.global_position
		_exclude_target_body()


func _process(delta: float) -> void:
	_active_distance = lerpf(_active_distance, _goal_distance, 1.0 - exp(-6.0 * delta))
	_active_follow_speed = lerpf(_active_follow_speed, _goal_follow_speed, 1.0 - exp(-6.0 * delta))
	_spring_arm.spring_length = _active_distance
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-_active_follow_speed * delta))


## Switches the follow target (e.g. player <-> vehicle). The rig keeps its position and orbit and
## glides to the new target; a negative distance/speed means "use the default values".
func set_target(new_target: Node3D, new_distance: float = -1.0, new_follow_speed: float = -1.0) -> void:
	target = new_target
	_goal_distance = new_distance if new_distance > 0.0 else distance
	_goal_follow_speed = new_follow_speed if new_follow_speed > 0.0 else follow_speed
	_exclude_target_body()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		release_mouse()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not is_mouse_captured():
		capture_mouse()
	elif event is InputEventMouseMotion and is_mouse_captured():
		_rotate_view(event.screen_relative)


func _notification(what: int) -> void:
	# Never leave the cursor locked when the window loses focus.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_mouse()


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _rotate_view(relative: Vector2) -> void:
	_yaw_pivot.rotation.y = wrapf(_yaw_pivot.rotation.y - relative.x * mouse_sensitivity, -PI, PI)
	_pitch_pivot.rotation.x = clampf(_pitch_pivot.rotation.x - relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


## The spring arm must not collide with the body it is following.
func _exclude_target_body() -> void:
	if _excluded_body and is_instance_valid(_excluded_body):
		_spring_arm.remove_excluded_object(_excluded_body.get_rid())
	_excluded_body = _find_collision_ancestor(target) if target else null
	if _excluded_body:
		_spring_arm.add_excluded_object(_excluded_body.get_rid())


func _find_collision_ancestor(node: Node) -> CollisionObject3D:
	var current := node
	while current:
		if current is CollisionObject3D:
			return current
		current = current.get_parent()
	return null
