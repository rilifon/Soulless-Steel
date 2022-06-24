extends CanvasLayer


func _ready():
	reset()


func reset():
	$Label.visible = false
	$ReturnButton.visible = false
	$VCREffect.visible = false


func killed():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Label.visible = true
	$ReturnButton.visible = true
	$VCREffect.visible = true


func _on_ReturnButton_pressed():
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://game/start_menu/StartMenu.tscn")
