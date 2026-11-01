class_name FarmTerrain
extends StaticBody3D
## Builds the farm terrain from `FarmLayout.height_at()` at load time: one visual ArrayMesh and a
## static triangle-mesh collision shape made from the very same triangles (deterministic, no RNG).

const SHADER := preload("res://shaders/farm_terrain.gdshader")

## Vertex heights, row-major (z rows, x columns). Kept for tests and tools.
var heights := PackedFloat32Array()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_build()


func _build() -> void:
	var n := FarmLayout.GRID_VERTICES
	var half := FarmLayout.HALF_SIZE
	var cell := FarmLayout.CELL_SIZE

	heights.resize(n * n)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(n * n)
	colors.resize(n * n)
	for j in n:
		var z := -half + j * cell
		for i in n:
			var x := -half + i * cell
			var h := FarmLayout.height_at(x, z)
			heights[j * n + i] = h
			vertices[j * n + i] = Vector3(x, h, z)
			colors[j * n + i] = Color(FarmLayout.path_mask_at(x, z), FarmLayout.pad_mask_at(x, z), 0.0)

	# Normals from neighbouring heights (cheap, smooth).
	var normals := PackedVector3Array()
	normals.resize(n * n)
	for j in n:
		for i in n:
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hu := heights[maxi(j - 1, 0) * n + i]
			var hd := heights[mini(j + 1, n - 1) * n + i]
			var sx := float(mini(i + 1, n - 1) - maxi(i - 1, 0)) * cell
			var sz := float(mini(j + 1, n - 1) - maxi(j - 1, 0)) * cell
			normals[j * n + i] = Vector3(-(hr - hl) / sx, 1.0, -(hd - hu) / sz).normalized()

	# Two triangles per cell. Godot front faces are clockwise seen from outside; seen from above
	# (+Y, X right, Z down) a-b-c and b-d-c are clockwise, so the surface faces up.
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	indices.resize((n - 1) * (n - 1) * 6)
	faces.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			for idx in [a, b, c, b, d, c]:
				indices[k] = idx
				faces[k] = vertices[idx]
				k += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	mesh.surface_set_material(0, material)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	_mesh_instance.mesh = mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_collision = CollisionShape3D.new()
	_collision.name = "TerrainCollision"
	_collision.shape = shape
	add_child(_collision)


## Height of the built grid at integer vertex (i, j).
func vertex_height(i: int, j: int) -> float:
	return heights[j * FarmLayout.GRID_VERTICES + i]
