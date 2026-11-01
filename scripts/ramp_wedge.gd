class_name RampWedge
extends StaticBody3D
## Greybox ramp with real convex collision. Local axes: the low edge is at +Z (y = 0, flush with
## flat ground) and the lip is at -Z (y = ramp_height). Rotate the node around Y to aim it.
## Behind the lip is a vertical drop, so a vehicle leaves the surface naturally (no scripted jump).

@export var ramp_length: float = 4.0  ## meters along travel (local Z)
@export var ramp_width: float = 3.0   ## meters (local X)
@export var ramp_height: float = 0.5  ## rise at the lip (m)
@export var color: Color = Color(1.0, 0.62, 0.2)

const EMBED := 0.3  ## how far the wedge sinks below ground so no gap can show


func _ready() -> void:
	_build()


func _build() -> void:
	var hw := ramp_width * 0.5
	var hl := ramp_length * 0.5
	var low_l := Vector3(-hw, 0.0, hl)
	var low_r := Vector3(hw, 0.0, hl)
	var top_l := Vector3(-hw, ramp_height, -hl)
	var top_r := Vector3(hw, ramp_height, -hl)
	var bot_low_l := Vector3(-hw, -EMBED, hl)
	var bot_low_r := Vector3(hw, -EMBED, hl)
	var bot_top_l := Vector3(-hw, -EMBED, -hl)
	var bot_top_r := Vector3(hw, -EMBED, -hl)

	var slope_normal := Vector3(0.0, ramp_length, ramp_height).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, low_l, low_r, top_r, top_l, slope_normal)                      # driving surface
	_quad(st, top_l, top_r, bot_top_r, bot_top_l, Vector3.FORWARD)           # back wall at the lip
	_quad(st, low_l, top_l, bot_top_l, bot_low_l, Vector3.LEFT)              # left side
	_quad(st, top_r, low_r, bot_low_r, bot_top_r, Vector3.RIGHT)             # right side
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.surface_set_material(0, material)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RampMesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([low_l, low_r, top_l, top_r, bot_low_l, bot_low_r, bot_top_l, bot_top_r])
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	add_child(collision)


## Height of the driving surface at local Z (valid for -length/2 <= z <= length/2).
func surface_height_at_local_z(local_z: float) -> float:
	return ramp_height * (ramp_length * 0.5 - local_z) / ramp_length


## Adds a quad (a, b, c, d in any winding) facing `outward`, as two triangles with a flat normal.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st, a, b, c, outward)
	_tri(st, a, c, d, outward)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot front faces are clockwise seen from outside: (b-a)x(c-a) must point inward.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(outward)
		st.add_vertex(v)
