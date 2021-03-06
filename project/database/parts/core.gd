extends Node

enum SIDE {LEFT, RIGHT, SINGLE}

export var weight:= 300
export var health := 10
export var shield := 10


func get_image():
	return $Core.texture


func get_collision():
	return $Collision.polygon


func get_sub():
	return $CoreSub.texture


func get_glow():
	return $CoreGlow.texture


func get_head_port():
	return $HeadPort.texture


func get_head_port_offset():
	return $HeadOffset.position


func get_shoulder_offset(side):
	if side == SIDE.LEFT:
		return $LeftShoulderOffset.position
	elif side == SIDE.RIGHT:
		return $RightShoulderOffset.position
	else:
		push_error("Not a valid side: " + str(side))


func get_arm_weapon_offset(side):
	if side == SIDE.LEFT:
		return $LeftArmWeaponOffset.position
	elif side == SIDE.RIGHT:
		return $RightArmWeaponOffset.position
	else:
		push_error("Not a valid side: " + str(side))


func get_shoulder_weapon_offset(side):
	if side == SIDE.LEFT:
		return $LeftShoulderWeaponOffset.position
	elif side == SIDE.RIGHT:
		return $RightShoulderWeaponOffset.position
	else:
		push_error("Not a valid side: " + str(side))


func get_leg_offset(side):
	if side == SIDE.LEFT:
		return $LeftLegOffset.position
	elif side == SIDE.RIGHT:
		return $RightLegOffset.position
	else:
		push_error("Not a valid side: " + str(side))
