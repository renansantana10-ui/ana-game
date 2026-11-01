class_name ControlsHUD
extends CanvasLayer
## Desktop HUD: on-foot controls, vehicle controls while riding, and a contextual prompt.

@onready var _foot_panel: Control = $Root/Margin/Panel
@onready var _vehicle_panel: Control = $Root/Margin/VehiclePanel
@onready var _prompt_panel: Control = $Root/PromptPanel
@onready var _prompt_label: Label = $Root/PromptPanel/Padding/Prompt


func _ready() -> void:
	set_mounted(false)
	set_prompt("")


## Shows the vehicle controls instead of the on-foot controls.
func set_mounted(mounted: bool) -> void:
	_foot_panel.visible = not mounted
	_vehicle_panel.visible = mounted


## Contextual prompt at the bottom of the screen; empty text hides it.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = text != ""


func get_prompt() -> String:
	return _prompt_label.text
