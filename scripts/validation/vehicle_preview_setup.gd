extends Node3D
## Preview-only helper (ANA-GAME-003-A-FIX-01): enables 4x MSAA on the viewport that hosts the refined vehicle
## preview. Local to this validation scene; project/renderer settings are not touched.


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
