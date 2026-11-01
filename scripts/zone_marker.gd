class_name ZoneMarker
extends Node3D
## Greybox marker for a reserved zone (parking, future barn, future expansion). Visual only:
## no collision, so a reserve can never become a hidden obstacle.

@export var label_text: String = ""
@export var color: Color = Color(0.9, 0.3, 0.3)
@export var post_height: float = 2.5
@export var label_pixel_size: float = 0.007
## If non-zero, draws a translucent blockout volume (width, height, depth) centered on the node.
@export var blockout_size: Vector3 = Vector3.ZERO
@export var blockout_roof: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	var solid := StandardMaterial3D.new()
	solid.albedo_color = color
	solid.roughness = 0.8

	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.06
	post_mesh.height = post_height
	post_mesh.material = solid
	post.mesh = post_mesh
	post.position = Vector3(0.0, post_height * 0.5, 0.0)
	add_child(post)

	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.7, 0.4, 0.05)
	flag_mesh.material = solid
	flag.mesh = flag_mesh
	flag.position = Vector3(0.38, post_height - 0.25, 0.0)
	add_child(flag)

	if label_text != "":
		var label := Label3D.new()
		label.name = "Label"
		label.text = label_text
		label.font_size = 48
		label.pixel_size = label_pixel_size
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0.1, 0.1, 0.1)
		label.position = Vector3(0.0, post_height + 0.5, 0.0)
		add_child(label)

	if blockout_size != Vector3.ZERO:
		var ghost := StandardMaterial3D.new()
		ghost.albedo_color = Color(color, 0.45)
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var body := MeshInstance3D.new()
		body.name = "BlockoutBody"
		var body_mesh := BoxMesh.new()
		body_mesh.size = blockout_size
		body_mesh.material = ghost
		body.mesh = body_mesh
		body.position = Vector3(0.0, blockout_size.y * 0.5, 0.0)
		add_child(body)
		if blockout_roof:
			var roof := MeshInstance3D.new()
			roof.name = "BlockoutRoof"
			var roof_mesh := PrismMesh.new()
			roof_mesh.size = Vector3(blockout_size.x, blockout_size.y * 0.35, blockout_size.z)
			roof_mesh.material = ghost
			roof.mesh = roof_mesh
			roof.position = Vector3(0.0, blockout_size.y + roof_mesh.size.y * 0.5, 0.0)
			add_child(roof)
