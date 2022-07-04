extends Node2D

export var rotation_acc := 8
export var rotation_range := 45.0
export var has_radar := false


func get_image():
	return $Main.texture


func get_sub():
	return $Sub.texture


func get_glow():
	return $Glow.texture
