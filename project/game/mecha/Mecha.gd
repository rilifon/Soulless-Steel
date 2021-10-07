extends KinematicBody2D
class_name Mecha

enum SIDE {LEFT, RIGHT}

const DECAL = preload("res://game/mecha/Decal.tscn")
const ARM_WEAPON_INITIAL_ROT = 9

signal create_projectile
signal shoot
signal took_damage
signal died

onready var CoreDecals = $Core/Decals
onready var LeftShoulderDecals = $LeftShoulder/Decals
onready var RightShoulderDecals = $RightShoulder/Decals

var max_hp = 10
var hp = 10
var max_shield = 10
var shield = 10
var max_energy = 100
var energy = 75

var movement_type = "free"
var velocity = Vector2()
var max_speed = 500
var friction = 0.1
var move_acc = 50
var rotation_acc = 5

var arm_weapon_left = null
var arm_weapon_right = null
var shoulder_weapon_left = null
var shoulder_weapon_right = null
var head = null
var core = null


func set_max_life(value):
	max_hp = value
	hp = max_hp


func set_max_shield(value):
	max_shield = value
	shield = max_shield


func set_max_energy(value):
	max_energy = value
	energy = max_energy


func take_damage(amount):
	var temp_shield = shield
	shield = max(shield - amount, 0)
	amount = max(amount - temp_shield, 0)
	
	hp = max(hp - amount, 0)
	
	emit_signal("took_damage", self)
	if hp <= 0:
		die()


func die():
	emit_signal("died", self)
	queue_free()


func add_decal(id, pos, type, size):
	var shape = shape_owner_get_owner(shape_find_owner(id))
	var decals_node
	var mask_node
	if shape == $CoreCollision:
		decals_node = CoreDecals
		mask_node = $Core
	elif shape == $LeftShoulderCollision:
		decals_node = LeftShoulderDecals
		mask_node = $LeftShoulder
	elif shape == $RightShoulderCollision:
		decals_node = RightShoulderDecals
		mask_node = $RightShoulder
	else:
		push_error("Not a valid shape id: " + str(id))
	var decal = DECAL.instance()
	decal.setup(type, size, pos-decals_node.global_position, mask_node.texture)
	decals_node.add_child(decal)

#PARTS SETTERS

func set_arm_weapon(part_name, side):
	var node
	if side == SIDE.LEFT:
		node = $ArmWeaponLeft
	elif side == SIDE.RIGHT:
		node = $ArmWeaponRight
	else:
		push_error("Not a valid side: " + str(side))


	if not part_name:
		if side == SIDE.LEFT:
			arm_weapon_left = null
		else:
			arm_weapon_right = null
		node.texture = null
		return
	
	var part_data = PartManager.get_part("arm_weapon", part_name)
	if side == SIDE.LEFT:
		arm_weapon_left = part_data
		node.rotation_degrees = -ARM_WEAPON_INITIAL_ROT
	else:
		arm_weapon_right = part_data
		node.rotation_degrees = ARM_WEAPON_INITIAL_ROT
	node.texture = part_data.image
	node.set_shooting_pos(part_data.shooting_pos)
	node.setup(part_data)


func set_shoulder_weapon(part_name, side):
	var node
	if side == SIDE.LEFT:
		node = $ShoulderWeaponLeft
	elif side == SIDE.RIGHT:
		node = $ShoulderWeaponRight
	else:
		push_error("Not a valid side: " + str(side))


	if not part_name:
		if side == SIDE.LEFT:
			shoulder_weapon_left = null
		else:
			shoulder_weapon_right = null
		node.texture = null
		return
	
	var part_data = PartManager.get_part("shoulder_weapon", part_name)
	if side == SIDE.LEFT:
		shoulder_weapon_left = part_data
	else:
		shoulder_weapon_right = part_data
	node.texture = part_data.image
	node.set_shooting_pos(part_data.shooting_pos)
	node.setup(part_data)


func set_core(part_name):
	var part_data = PartManager.get_part("core", part_name)
	$Core.texture = part_data.image
	$CoreCollision.polygon = part_data.collision
	core = part_data


func set_head(part_name):
	var part_data = PartManager.get_part("head", part_name)
	$Head.texture = part_data.image
	head = part_data


func set_shoulder(part_name, side):
	var part_data = PartManager.get_part("shoulder", part_name)
	var node
	var collision_node
	if side == SIDE.LEFT:
		node = $LeftShoulder
		collision_node = $LeftShoulderCollision
	elif side == SIDE.RIGHT:
		node = $RightShoulder
		collision_node = $RightShoulderCollision
	else:
		push_error("Not a valid side: " + str(side))
	
	node.texture = part_data.image
	collision_node.polygon = part_data.collision

#ATTRIBUTE METHODS


func get_max_hp():
	return max_hp


func get_weight():
	assert(core, "Mecha doesn't have an assigned core")
	return float(core.weight)


func get_ammo(part_name):
	if part_name == "left_arm":
		if arm_weapon_left:
			return $ArmWeaponLeft.clip_ammo
	elif part_name == "right_arm":
		if arm_weapon_right:
			return $ArmWeaponRight.clip_ammo
	elif part_name == "left_shoulder":
		pass
	elif part_name == "right_shoulder":
		pass
	return false


#MOVEMENT METHODS

func apply_movement(dt, direction):
	if movement_type == "free":
		if direction.length() > 0:
			velocity = lerp(velocity, direction.normalized() * max_speed, move_acc*dt)
		else:
			velocity = lerp(velocity, Vector2.ZERO, friction)
		
		velocity = move_and_slide(velocity)
	elif movement_type == "tank":
		pass
	else:
		push_error("Not a valid movement type: " + str(movement_type))


func apply_rotation(dt, target_pos, stand_still):
	#Rotate Body
	if not stand_still:
		rotation_degrees += get_target_rotation_diff(dt, global_position, target_pos, rotation_degrees, rotation_acc)
	
	
	#Rotate Arm Weapons
	for data in [[$ArmWeaponLeft, arm_weapon_left], [$ArmWeaponRight, arm_weapon_right],\
				 [$Head, head]]:
		var node_ref = data[1]
		if node_ref:
			var node = data[0]
			var actual_rot = node.rotation_degrees + rotation_degrees
			node.rotation_degrees += get_target_rotation_diff(dt, node.global_position, target_pos, actual_rot, node_ref.rotation_acc)
			node.rotation_degrees = clamp(node.rotation_degrees, -node_ref.rotation_range, node_ref.rotation_range)
	

func get_target_rotation_diff(dt, origin, target_pos, cur_rotation, acc):
	var target_rot = rad2deg(origin.angle_to_point(target_pos)) + 270
	var diff = target_rot - cur_rotation
	if diff > 180:
		diff -= 360
	elif diff < -180:
		diff += 360
	#Rotate properly clock or counter-clockwise fastest to target rotation
	if diff > 0:
		return abs(diff)*acc*dt
	else:
		return -abs(diff)*acc*dt


func knockback(pos, strength):
	apply_movement(sqrt(strength)*2/get_weight(), global_position - pos)
	apply_rotation(sqrt(strength)*2/get_weight(), pos, false)


#COMBAT METHODS

func shoot(type):
	var node
	var weapon_ref
	if type == "left_arm_weapon":
		node = $ArmWeaponLeft
		weapon_ref = arm_weapon_left
	elif type ==  "right_arm_weapon":
		node = $ArmWeaponRight
		weapon_ref = arm_weapon_right
	elif type == "left_shoulder_weapon":
		node = $ShoulderWeaponLeft
		weapon_ref = shoulder_weapon_left
	elif type ==  "right_shoulder_weapon":
		node = $ShoulderWeaponRight
		weapon_ref = shoulder_weapon_right
	else:
		push_error("Not a valid type of weapon to shoot: " + str(type))
	
	if not node.can_shoot():
		return
	
	node.shoot()
	emit_signal("create_projectile", self, 
				{
					"weapon_data": weapon_ref.projectile,
					"pos": node.get_shoot_position(),
					"dir": node.get_direction(weapon_ref.bullet_accuracy_margin),
					"damage_mod": weapon_ref.damage_modifier,
				})
	apply_recoil(type, weapon_ref.recoil_force)
	emit_signal("shoot")

func apply_recoil(type, recoil):
	var rotation = recoil*300/get_weight()
	if "left" in type:
		rotation *= -1
	rotation_degrees += rotation
