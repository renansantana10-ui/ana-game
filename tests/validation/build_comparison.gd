extends SceneTree
## ANA-GAME-003-A-FIX-01: builds A | B | C comparison boards (needs a real rendering backend).
##   A = original Godot preview, B = refined Godot preview, C = approved Blender v02 render.
##   godot --path <project> --rendering-driver opengl3 --script res://tests/validation/build_comparison.gd

const A_DIR := "res://validation/ana-game-003-a/fix01/A_original/"
const B_DIR := "res://validation/ana-game-003-a/fix01/B_refined/"
const C_DIR := "D:/ana game/producao-assets-3d/previews/"
const OUT_DIR := "res://validation/ana-game-003-a/fix01/comparison/"
const COL_W := 700
const COL_H := 538
## board name -> [A/B file, C file]
const BOARDS := {
	"compare_three_quarter": ["blender_34.png", "ana-veiculo-blockout-v02_perspectiva_34.png"],
	"compare_side": ["blender_side.png", "ana-veiculo-blockout-v02_lateral.png"],
	"compare_front": ["blender_front.png", "ana-veiculo-blockout-v02_frontal.png"],
	"compare_rear": ["blender_rear.png", "ana-veiculo-blockout-v02_traseira.png"],
}

var _failures := 0


func _initialize() -> void:
	_run()


func _column(title: String, path: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
	tr.custom_minimum_size = Vector2(COL_W, COL_H)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	col.add_child(tr)
	return col


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[NOT VERIFIED] comparison - GUI capture required")
		quit(2)
		return
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	for board in BOARDS:
		var names: Array = BOARDS[board]
		var vp := SubViewport.new()
		vp.size = Vector2i(COL_W * 3 + 40, COL_H + 40)
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(vp)
		var bg := ColorRect.new()
		bg.color = Color(0.12, 0.12, 0.14)
		bg.size = Vector2(vp.size)
		vp.add_child(bg)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.position = Vector2(10, 5)
		row.add_child(_column("A - Godot original", A_DIR + names[0]))
		row.add_child(_column("B - Godot refinado", B_DIR + names[0]))
		row.add_child(_column("C - Blender v02 (aprovado)", C_DIR + names[1]))
		vp.add_child(row)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path: String = out + board + ".png"
		var ok := img.save_png(path) == OK and FileAccess.get_file_as_bytes(path).size() > 1000
		print("[%s] %s %dx%d" % ["PASS" if ok else "FAIL", path, img.get_width(), img.get_height()])
		if not ok:
			_failures += 1
		vp.queue_free()
	quit(1 if _failures > 0 else 0)
