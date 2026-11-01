class_name RideOnVisual
extends Node3D
## Greybox visual of the pink four-wheeled children's ride-on toy (placeholder primitives only).
## Replaceable by a future GLB without touching the driving controller: the controller only calls
## `update_wheels()`. Local axes: forward is -Z, up is +Y, origin is on the ground between the axles.
## Reference: "Ficha de Personagem na Fazenda" (pink low body, 4 mint-green wheels with pink hubs,
## elongated pink seat, triangular handlebar with a horizontal grip). Not a final model.

@export_group("Proportions (meters)")
@export var wheel_radius: float = 0.13
@export var wheel_width: float = 0.09
@export var wheelbase: float = 0.56
@export var front_track: float = 0.46
@export var rear_track: float = 0.40
@export var seat_height: float = 0.31
@export var handlebar_height: float = 0.64

@export_group("Colors")
@export var body_color: Color = Color(1.0, 0.55, 0.76)
@export var seat_color: Color = Color(1.0, 0.66, 0.82)
@export var wheel_color: Color = Color(0.62, 0.86, 0.74)  ## mint green
@export var hub_color: Color = Color(1.0, 0.55, 0.76)

var _front_wheels: Array[Node3D] = []
var _spin_nodes: Array[Node3D] = []


func _ready() -> void:
	_build()


## Rolls all wheels for `speed` (m/s, signed) and steers the front pair by `steer_angle` (rad, + = left).
func update_wheels(speed: float, steer_angle: float, delta: float) -> void:
	for wheel in _front_wheels:
		wheel.rotation.y = steer_angle
	for spin in _spin_nodes:
		spin.rotation.x = wrapf(spin.rotation.x - speed * delta / wheel_radius, -PI, PI)


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	return m


func _add_mesh(parent: Node3D, node_name: String, mesh: PrimitiveMesh, color: Color, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mesh.material = _material(color)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _build() -> void:
	var half_base := wheelbase * 0.5
	var front_z := -half_base
	var rear_z := half_base

	# Low rounded pink chassis bar connecting both axles.
	var bar := BoxMesh.new()
	bar.size = Vector3(0.14, 0.07, wheelbase + 0.16)
	_add_mesh(self, "PinkBody", bar, body_color, Vector3(0, 0.2, 0))

	# Mint axles.
	for axle in [["FrontAxle", front_z, front_track], ["RearAxle", rear_z, rear_track]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = axle[2]
		_add_mesh(self, axle[0], cyl, wheel_color, Vector3(0, wheel_radius, axle[1]), Vector3(0, 0, 90))

	# Elongated seat (flattened capsule lying along Z).
	var seat := CapsuleMesh.new()
	seat.radius = 0.1
	seat.height = 0.46
	_add_mesh(self, "ElongatedSeat", seat, seat_color, Vector3(0, seat_height - 0.045, rear_z * 0.35),
			Vector3(90, 0, 0), Vector3(1, 1, 0.45))

	# Steering post, triangular handlebar and horizontal grip.
	var post := CylinderMesh.new()
	post.top_radius = 0.03
	post.bottom_radius = 0.03
	post.height = handlebar_height - 0.2
	_add_mesh(self, "SteeringPost", post, body_color, Vector3(0, 0.2 + post.height * 0.5, front_z + 0.02))
	var tri := PrismMesh.new()
	tri.size = Vector3(0.2, 0.14, 0.035)
	_add_mesh(self, "TriangularHandlebar", tri, body_color, Vector3(0, handlebar_height - 0.07, front_z + 0.02))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.02
	grip.bottom_radius = 0.02
	grip.height = 0.42
	_add_mesh(self, "HandlebarGrip", grip, body_color, Vector3(0, handlebar_height, front_z + 0.02), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		var knob := SphereMesh.new()
		knob.radius = 0.035
		knob.height = 0.07
		_add_mesh(self, "GripKnob" + ("L" if side < 0.0 else "R"), knob, hub_color,
				Vector3(side * 0.21, handlebar_height, front_z + 0.02))

	# Four separate wheels. Each wheel node is a pivot at its axle; "Spin" rolls, front pivots steer.
	_add_wheel("FrontLeftWheel", Vector3(-front_track * 0.5, wheel_radius, front_z), true)
	_add_wheel("FrontRightWheel", Vector3(front_track * 0.5, wheel_radius, front_z), true)
	_add_wheel("RearLeftWheel", Vector3(-rear_track * 0.5, wheel_radius, rear_z), false)
	_add_wheel("RearRightWheel", Vector3(rear_track * 0.5, wheel_radius, rear_z), false)


func _add_wheel(wheel_name: String, pos: Vector3, steers: bool) -> void:
	var wheel := Node3D.new()
	wheel.name = wheel_name
	wheel.position = pos
	add_child(wheel)
	var spin := Node3D.new()
	spin.name = "Spin"
	wheel.add_child(spin)
	var tire := CylinderMesh.new()
	tire.top_radius = wheel_radius
	tire.bottom_radius = wheel_radius
	tire.height = wheel_width
	_add_mesh(spin, "Tire", tire, wheel_color, Vector3.ZERO, Vector3(0, 0, 90))
	var hub := CylinderMesh.new()
	hub.top_radius = wheel_radius * 0.62
	hub.bottom_radius = wheel_radius * 0.62
	hub.height = wheel_width + 0.012
	_add_mesh(spin, "Hub", hub, hub_color, Vector3.ZERO, Vector3(0, 0, 90))
	_spin_nodes.append(spin)
	if steers:
		_front_wheels.append(wheel)
