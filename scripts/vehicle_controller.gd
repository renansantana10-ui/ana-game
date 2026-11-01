class_name VehicleController
extends CharacterBody3D
## Arcade controller for the child-sized ride-on toy.
##
## Physics approach (documented decision): a kinematic CharacterBody3D, not VehicleBody3D. For a toy
## at <= 7 m/s on a 1 m triangle-mesh terrain this gives predictable, tunable, Web-safe behavior with
## no suspension jitter, flipping or spin-outs. Ground speed is a single signed scalar along the body's
## forward axis projected onto the floor plane, so hills and ramps are followed by real collision.
## Leaving a ramp lip leaves the floor naturally (velocity keeps its upward component, gravity takes
## over), so airtime is physical. There is deliberately NO jump/boost code and `jump` is never read:
## Space reaches the vehicle only as `vehicle_handbrake` (braking / arcade drift, ground only).
##
## Drift (handbrake + A/D, forward speed >= drift_min_speed): the heading turns faster
## (drift_steer_multiplier) while the velocity keeps its direction; the sideways speed (`lateral`) is
## bled at a reduced grip rate and total speed is preserved, so the vehicle slides but keeps moving
## forward. Releasing Space restores grip over grip_recovery_time. Normal driving never enters this path.
##
## The body only ever rotates around Y (yaw). Ground tilt is applied to `visual_root` only.
## Local axes: forward is -Z, up is +Y. The node origin is the ground contact point.

@export_group("Driving")
@export var max_forward_speed: float = 7.0
@export var max_reverse_speed: float = 2.5
@export var acceleration: float = 5.0            ## m/s² under throttle
@export var reverse_acceleration: float = 3.0
@export var brake_strength: float = 12.0         ## m/s² when S is held while moving forward
@export var coast_drag: float = 2.0              ## m/s² slowdown with no throttle
@export var reverse_engage_speed: float = 0.4    ## S switches from braking to reverse below this speed

@export_group("Steering")
@export var turn_radius_low_speed: float = 2.5   ## meters at full lock when slow
@export var turn_radius_high_speed: float = 8.0  ## meters at full lock at max speed (less aggressive)
@export var steering_response: float = 6.0       ## how fast the steering input is followed (1/s)
@export var max_steer_visual_angle: float = 0.5  ## rad, front wheel presentation only

@export_group("Handbrake / Drift")
@export var drift_min_speed: float = 3.0          ## m/s needed to start a drift
@export var drift_steer_multiplier: float = 1.85  ## extra turning while drifting
@export_range(0.1, 1.0) var drift_lateral_grip: float = 0.38  ## fraction of grip_reference_rate kept while drifting
@export var grip_reference_rate: float = 6.0      ## 1/s sideways-speed decay at "full" slide grip (reference for the factor above)
@export var normal_grip_rate: float = 60.0        ## 1/s sideways-speed decay when not drifting (near instant)
@export var grip_recovery_time: float = 0.2       ## s to get grip and steering back after releasing Space
@export var drift_entry_time: float = 0.12        ## s to ease into a drift
@export var handbrake_decel: float = 8.0          ## m/s² handbrake braking when not sliding
@export var handbrake_decel_drift: float = 3.0    ## m/s² partial braking while sliding

@export_group("Terrain")
@export_range(0.0, 1.0) var slope_gravity_factor: float = 0.6  ## how much slopes speed up / slow down
@export var park_hold_acceleration: float = 3.0  ## slopes gentler than this hold a stopped vehicle still
@export var max_downhill_overspeed: float = 1.3  ## speed cap on descents, as a multiple of max speed
@export var ground_stick_speed: float = 0.4      ## m/s pressed into the floor so contact never flickers on slopes
@export var align_speed_ground: float = 14.0     ## visual tilt follow rate on the ground (1/s)
@export var align_speed_air: float = 2.5         ## visual tilt relaxation rate in the air (1/s)

@export_group("Dismount")
@export var dismount_max_speed: float = 0.6      ## must be slower than this (m/s) to get off

@export_group("Nodes")
@export var visual_root: Node3D
@export var seat_anchor: Marker3D
@export var camera_target: Marker3D
@export var dismount_anchor: Marker3D            ## right-hand exit; mirrored for the left side

## True only while the rider is mounted. When false the vehicle ignores all driving input.
var driven: bool = false
## Signed speed along the forward axis (m/s); negative = reversing.
var speed: float = 0.0
var steer: float = 0.0  ## smoothed steering, -1 (right) .. +1 (left)

## Sideways speed (m/s, + = to the vehicle's right) while sliding. Zero in normal driving.
var lateral: float = 0.0
## 0..1: how far into a drift the vehicle is (eases in/out; scales steering boost and grip loss).
var drift_amount: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _was_grounded: bool = false
var _drifting: bool = false


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := false
	if driven:
		throttle = Input.get_axis("move_backward", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("vehicle_handbrake")
	steer = move_toward(steer, steer_input, steering_response * delta)

	var grounded := is_on_floor()
	var floor_normal := get_floor_normal() if grounded else Vector3.UP

	if grounded:
		_update_drift_state(handbrake, steer_input, delta)
		# Yaw first (kinematic bicycle-like: no turning on the spot, natural when reversing).
		var yaw_step := speed * steer * _curvature() * lerpf(1.0, drift_steer_multiplier, drift_amount) * delta
		var slipping := drift_amount > 0.001 or absf(lateral) > 0.05
		if slipping:
			# Velocity keeps its world direction while the heading turns: re-express it in the new frame.
			var s := speed * cos(yaw_step) - lateral * sin(yaw_step)
			lateral = lateral * cos(yaw_step) + speed * sin(yaw_step)
			speed = s
		rotate_y(yaw_step)
		global_basis = global_basis.orthonormalized()
		var forward := -global_basis.z
		var along := (forward - floor_normal * forward.dot(floor_normal)).normalized()
		var right := along.cross(floor_normal).normalized()
		if not _was_grounded:
			speed = velocity.dot(along)  # keep momentum when landing
			lateral = velocity.dot(right)
		if slipping or absf(lateral) > 0.0:
			_apply_lateral_grip(delta)
		_update_speed(0.0 if handbrake else throttle, along.y, delta, handbrake)
		velocity = along * speed + right * lateral - floor_normal * ground_stick_speed
	else:
		_drifting = false  # no handbrake effects in the air
		drift_amount = move_toward(drift_amount, 0.0, delta / grip_recovery_time)
		velocity.y -= _gravity * delta
		var forward_flat := -global_basis.z
		forward_flat.y = 0.0
		speed = velocity.dot(forward_flat.normalized())  # keep `speed` meaningful for wheels / landing

	_was_grounded = grounded
	move_and_slide()

	if is_on_floor():
		var along_after := (-global_basis.z - get_floor_normal() * (-global_basis.z).dot(get_floor_normal())).normalized()
		var measured := get_real_velocity().dot(along_after)
		if absf(measured) < absf(speed) * 0.9:
			speed = measured  # clearly blocked by something: never keep phantom speed
		var measured_side := get_real_velocity().dot(along_after.cross(get_floor_normal()).normalized())
		if absf(measured_side) < absf(lateral) * 0.9:
			lateral = measured_side

	_align_visual(floor_normal if is_on_floor() else Vector3.UP, is_on_floor(), delta)
	if visual_root is RideOnVisual:
		(visual_root as RideOnVisual).update_wheels(speed, steer * max_steer_visual_angle, delta)


## True when the vehicle is on the ground and slow enough for the rider to get off.
func can_dismount() -> bool:
	return is_on_floor() and get_real_velocity().length() <= dismount_max_speed


func _curvature() -> float:
	var t := clampf(absf(speed) / max_forward_speed, 0.0, 1.0)
	return 1.0 / lerpf(turn_radius_low_speed, turn_radius_high_speed, t)


## Drift starts only with the handbrake + a steering key while moving forward fast enough, and keeps
## going while Space is held until the vehicle is nearly slow. Never active when stopped or airborne.
func _update_drift_state(handbrake: bool, steer_input: float, delta: float) -> void:
	if _drifting:
		_drifting = handbrake and speed >= drift_min_speed * 0.5
	else:
		_drifting = handbrake and absf(steer_input) > 0.1 and speed >= drift_min_speed
	var time := drift_entry_time if _drifting else grip_recovery_time
	drift_amount = move_toward(drift_amount, 1.0 if _drifting else 0.0, delta / time)


## Bleeds sideways speed at the current grip rate while preserving total speed (the vehicle keeps
## moving forward as it slides); grip returns progressively when the drift ends.
func _apply_lateral_grip(delta: float) -> void:
	var rate := lerpf(normal_grip_rate, grip_reference_rate * drift_lateral_grip, drift_amount)
	var new_lateral := lateral * exp(-rate * delta)
	var energy := speed * speed + lateral * lateral - new_lateral * new_lateral
	var direction := -1.0 if speed < 0.0 else 1.0
	speed = direction * sqrt(maxf(energy, 0.0))
	lateral = new_lateral
	if drift_amount <= 0.001 and absf(lateral) < 0.05:
		lateral = 0.0


func _update_speed(throttle: float, slope_up: float, delta: float, handbrake: bool = false) -> void:
	if handbrake:
		# Partial braking: gentler while sliding so the vehicle keeps carrying its speed.
		var decel := lerpf(handbrake_decel, handbrake_decel_drift, drift_amount)
		speed = move_toward(speed, 0.0, decel * delta)
	elif throttle > 0.0:
		if speed < -reverse_engage_speed:
			speed = move_toward(speed, 0.0, brake_strength * delta)  # brake out of reverse first
		else:
			speed = move_toward(speed, max_forward_speed, acceleration * delta)
	elif throttle < 0.0:
		if speed > reverse_engage_speed:
			speed = move_toward(speed, 0.0, brake_strength * delta)  # brake; reverse only when slow
		else:
			speed = move_toward(speed, -max_reverse_speed, reverse_acceleration * delta)
	else:
		speed = move_toward(speed, 0.0, coast_drag * delta)

	# Slope: climbing slows, descending speeds up (arcade-scaled gravity along the slope).
	var slope_accel := _gravity * slope_up * slope_gravity_factor
	speed -= slope_accel * delta
	if throttle == 0.0 and absf(speed) < 0.25 and absf(lateral) < 0.05 and absf(slope_accel) < park_hold_acceleration:
		speed = 0.0  # parked on a moderate slope: stay put
	speed = clampf(speed, -max_reverse_speed * 1.3, max_forward_speed * max_downhill_overspeed)


## Tilts only the visual root to the ground normal (or levels it in the air). Never touches collision.
func _align_visual(up: Vector3, on_ground: bool, delta: float) -> void:
	if visual_root == null:
		return
	var z := global_basis.z
	var x := up.cross(z).normalized()
	z = x.cross(up).normalized()
	var target := Basis(x, up, z).get_rotation_quaternion()
	var current := visual_root.global_basis.get_rotation_quaternion()
	var rate := align_speed_ground if on_ground else align_speed_air
	visual_root.global_basis = Basis(current.slerp(target, 1.0 - exp(-rate * delta)))
