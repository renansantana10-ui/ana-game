class_name VehicleInteraction
extends Node
## Mount / dismount logic between the single player and the ride-on vehicle (E key).
##
## There is exactly one player node. Mounting hands movement authority to the vehicle
## (`PlayerController.move_state = MOUNTED`, player collision shape disabled so no invisible body
## blocks the vehicle) and the existing player node simply rides the seat anchor; nothing is
## instanced or duplicated. Dismounting finds a free, grounded spot beside the vehicle first and
## otherwise keeps the rider seated.

signal mounted
signal dismounted

@export var player: PlayerController
@export var vehicle: VehicleController
@export var camera_rig: ThirdPersonCamera
@export var hud: ControlsHUD

@export_group("Interaction")
@export var interaction_distance: float = 2.0     ## m, horizontal, player to vehicle
@export var cooldown_seconds: float = 0.3         ## blocks double handling of one key press
@export var back_front_exit_distance: float = 1.1

@export_group("Riding camera")
@export var riding_camera_distance: float = 4.5
@export var riding_follow_speed: float = 26.0

var _foot_camera_target: Node3D
var _player_shape: CollisionShape3D
var _cooldown: float = 0.0
var _message: String = ""
var _message_time: float = 0.0
var _foot_visual_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	process_physics_priority = 10  # after the vehicle moved, so the rider never lags the seat
	_foot_camera_target = camera_rig.target
	_player_shape = player.get_node("CollisionShape3D")
	if player.visual_root:
		_foot_visual_scale = player.visual_root.scale


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_message_time = maxf(_message_time - delta, 0.0)

	if is_mounted():
		_attach_rider()
	if _cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		if is_mounted():
			try_dismount()
		else:
			try_mount()
	_update_prompt()


func is_mounted() -> bool:
	return player.move_state == PlayerController.MoveState.MOUNTED


## True when the player is on foot, grounded and within reach of the vehicle.
func can_mount() -> bool:
	if is_mounted() or vehicle.driven or not player.is_on_floor():
		return false
	var offset := player.global_position - vehicle.global_position
	return Vector2(offset.x, offset.z).length() <= interaction_distance and absf(offset.y) < 1.5


func try_mount() -> bool:
	if not can_mount():
		return false
	player.set_move_state(PlayerController.MoveState.MOUNTED)
	_player_shape.set_deferred("disabled", true)
	if player.visual_root:
		player.visual_root.scale = Vector3(1.0, 0.7, 1.0)  # minimal seated placeholder pose
		player.visual_root.rotation = Vector3.ZERO
	vehicle.driven = true
	_attach_rider()
	camera_rig.set_target(vehicle.camera_target, riding_camera_distance, riding_follow_speed)
	hud.set_mounted(true)
	_cooldown = cooldown_seconds
	mounted.emit()
	return true


func try_dismount() -> bool:
	if not is_mounted():
		return false
	if not vehicle.can_dismount():
		_show_message("Pare o veículo para descer")
		return false
	var spot := _find_dismount_spot()
	if not spot.ok:
		_show_message("Sem espaço para descer")
		return false

	player.global_transform = Transform3D(Basis.IDENTITY, spot.position + Vector3(0.0, 0.02, 0.0))
	if player.visual_root:
		player.visual_root.scale = _foot_visual_scale
		player.visual_root.rotation = Vector3(0.0, vehicle.global_rotation.y, 0.0)
	player.velocity = Vector3.ZERO
	_player_shape.set_deferred("disabled", false)
	player.set_move_state(PlayerController.MoveState.ON_FOOT)
	vehicle.driven = false
	camera_rig.set_target(_foot_camera_target)
	hud.set_mounted(false)
	_cooldown = cooldown_seconds
	dismounted.emit()
	return true


## The rider is the existing player node, riding the seat anchor (position and tilt).
func _attach_rider() -> void:
	player.global_transform = vehicle.seat_anchor.global_transform
	player.velocity = Vector3.ZERO


## First free, grounded exit among: right, left, behind, in front of the vehicle.
func _find_dismount_spot() -> Dictionary:
	var side := vehicle.dismount_anchor.position
	var candidates: Array[Vector3] = [
		side, Vector3(-side.x, side.y, side.z),
		Vector3(0.0, 0.0, back_front_exit_distance), Vector3(0.0, 0.0, -back_front_exit_distance),
	]
	var space := vehicle.get_world_3d().direct_space_state
	var excluded: Array[RID] = [vehicle.get_rid(), player.get_rid()]
	var capsule := _player_shape.shape
	for local in candidates:
		var world := vehicle.global_transform * local
		var ray := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 2.0, world + Vector3.DOWN * 2.0)
		ray.exclude = excluded
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < 0.8:
			continue
		if absf(hit.position.y - vehicle.global_position.y) > 1.2:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY,
				hit.position + _player_shape.position + Vector3(0.0, 0.05, 0.0))
		query.exclude = excluded
		query.collision_mask = player.collision_mask
		if space.intersect_shape(query, 1).is_empty():
			return {"ok": true, "position": hit.position}
	return {"ok": false}


func _show_message(text: String) -> void:
	_message = text
	_message_time = 1.5


func _update_prompt() -> void:
	var text := ""
	if _message_time > 0.0:
		text = _message
	elif not is_mounted() and can_mount():
		text = "E — Subir no veículo"
	hud.set_prompt(text)
