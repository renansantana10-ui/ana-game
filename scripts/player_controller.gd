class_name PlayerController
extends CharacterBody3D
## Camera-relative WASD movement, hold-to-sprint and grounded jump for the placeholder player.
## Independent of the visual mesh: only rotates `visual_root` to face the movement direction.
## Movement authority: only active while `move_state == ON_FOOT`; while MOUNTED the vehicle
## controller owns movement and this controller neither moves, jumps nor sprints.

enum MoveState { ON_FOOT, MOUNTED }

@export_group("Movement")
@export var move_speed: float = 2.5
@export var sprint_speed: float = 5.0  ## m/s while the `sprint` action (Shift) is held
@export var jump_velocity: float = 3.5
@export var ground_acceleration: float = 18.0
@export var ground_deceleration: float = 24.0

@export_group("Visual")
@export var visual_root: Node3D
@export var turn_speed: float = 12.0

var move_state: MoveState = MoveState.ON_FOOT
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta: float) -> void:
	if move_state != MoveState.ON_FOOT:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var direction := _get_move_direction()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var target_velocity := direction * speed
	var rate := ground_acceleration if direction != Vector3.ZERO else ground_deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target_velocity.x, target_velocity.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()
	_face_direction(direction, delta)


## Hands movement authority to/from the vehicle. Mounting also clears velocity so nothing carries over.
func set_move_state(new_state: MoveState) -> void:
	move_state = new_state
	if new_state == MoveState.MOUNTED:
		velocity = Vector3.ZERO


## World-space horizontal direction from WASD, relative to the active camera.
func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var cam_basis := camera.global_basis if camera else global_basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	return right * input.x + forward * -input.y


func _face_direction(direction: Vector3, delta: float) -> void:
	if visual_root == null or direction.length_squared() < 0.01:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw,
			1.0 - exp(-turn_speed * delta))
