extends KinematicBody2D
class_name Mecha

enum SIDE {LEFT, RIGHT}

const DECAL = preload("res://game/mecha/Decal.tscn")
const ARM_WEAPON_INITIAL_ROT = 9

signal create_projectile
signal shoot
signal took_damage
signal died
signal player_kill
signal mecha_extracted

export var speed_modifier = 1.0

onready var CoreDecals = $Core/Decals
onready var LeftShoulderDecals = $LeftShoulder/Decals
onready var RightShoulderDecals = $RightShoulder/Decals
onready var MovementAnimation = $MovementAnimation

onready var Core = $Core
onready var CoreSub = $CoreSub
onready var CoreGlow = $CoreGlow
onready var Head = $Head
onready var HeadSub = $HeadSub
onready var HeadGlow = $HeadGlow
onready var HeadPort = $HeadPort
onready var LeftShoulder = $LeftShoulder
onready var RightShoulder = $RightShoulder
onready var LeftArmWeapon = $ArmWeaponLeft
onready var RightArmWeapon = $ArmWeaponRight
onready var LeftShoulderWeapon = $ShoulderWeaponLeft
onready var RightShoulderWeapon = $ShoulderWeaponRight

var mecha_name = "Mecha Name"

var is_dead = false
var max_hp = 100
var hp = 100
var max_shield = 100
var shield = 100
var max_energy = 100
var energy = 100
var total_kills = 0
var mecha_heat = 0
var move_heat = 70 #move when implementing new legs

var movement_type = "free"
var velocity = Vector2()
var moving = false
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
var legs = null


func _ready():
	for node in [Core, CoreSub, CoreGlow, Head, HeadSub, HeadGlow, HeadPort, LeftShoulder, RightShoulder,\
				 LeftArmWeapon, RightArmWeapon, LeftShoulderWeapon, RightShoulderWeapon]:
		node.material = CoreSub.material.duplicate(true)


func _physics_process(dt):
	if shield < max_shield:
		shield += 0.2
	if not is_stunned():
		var all_collisions = []
		for i in get_slide_count():
			all_collisions.append(get_slide_collision(i))
		
		var collided = false
		for collision in all_collisions:
			if collision and collision.collider.is_in_group("mecha"):
				collided = true
				var mod = 2.0
				var rand = rand_range(-PI/8, PI/8)
				var dir = (global_position - collision.collider.global_position).rotated(rand)
				apply_movement(mod*dt, dir)
		if collided:
			stun(0.1)
	else:
		apply_movement(dt, Vector2())
	
	if moving and not MovementAnimation.is_playing():
		MovementAnimation.play("Walking")
	elif not moving and velocity.length() <= 2.0:
		MovementAnimation.stop()
	
	update_heat(dt)


func is_player():
	return mecha_name == "Player"


func set_speed(_max_speed, _move_acc):
	max_speed = _max_speed
	move_acc = min(_move_acc, 100.0)
	MovementAnimation.playback_speed = max_speed/200
	var animation = MovementAnimation.get_animation("Walking")
	var track = 0 #animation.find_track("Mecha:speed_modifier")
	animation.track_set_key_value(track, 2, move_acc/100.0)
	animation.track_set_key_value(track, 5, move_acc/100.0)


func set_max_life(value):
	max_hp = value
	hp = max_hp


func set_max_shield(value):
	max_shield = value
	shield = max_shield


func set_max_energy(value):
	max_energy = value
	energy = max_energy


func take_damage(amount, source_info, weapon_name, calibre):
	if is_dead:
		return
	
	var temp_shield = shield
	shield = max(shield - amount, 0)
	amount = max(amount - temp_shield, 0)
	
	hp = max(hp - amount, 0)
	if shield <= 0:
		select_impact(calibre, false)
	else:
		select_impact(calibre, true)
	emit_signal("took_damage", self)
	if hp <= 0:
		AudioManager.play_sfx("final_explosion", global_position, 0.0, 0.0, 1.25, 10000)
		die(source_info, weapon_name)


func die(source_info, weapon_name):
	emit_signal("died", self)
	is_dead = true
	TickerManager.new_message({
		"type": "mecha_died",
		"source": source_info.name,
		"self": self.mecha_name,
		"weapon_name": weapon_name,
		})
	if source_info.name == "Player":
		emit_signal("player_kill")
	queue_free()


func is_shape_id_legs(id):
	return shape_owner_get_owner(shape_find_owner(id)) == $LegsCollision


func add_decal(id, projectile_transform, type, size):
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
	var offset = projectile_transform.origin-decals_node.global_transform.origin
	offset = offset.rotated(-decals_node.global_transform.get_rotation())
	offset *= decals_node.global_transform.get_scale()
	offset *= rand_range(.6,.9) #Random depth for decal on mecha
	decals_node.add_child(decal)
	decal.setup(type, size, offset, mask_node.texture, mask_node.get_global_transform().get_scale())


func update_heat(dt):
	#Main Mecha Heat
	if core:
		mecha_heat = max(mecha_heat - core.heat_dispersion*dt, 0)
	for node in [Core, CoreSub, CoreGlow, Head, HeadSub, HeadGlow, HeadPort, LeftShoulder, RightShoulder]:
		node.material.set_shader_param("heat", mecha_heat) 


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
	node.texture = part_data.get_image()
	node.set_shooting_pos(part_data.get_shooting_pos())
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
	node.texture = part_data.get_image()
	node.set_shooting_pos(part_data.get_shooting_pos())
	node.setup(part_data)


func set_core(part_name):
	var part_data = PartManager.get_part("core", part_name)
	$Core.texture = part_data.get_image()
	$CoreCollision.polygon = part_data.get_collision()
	core = part_data
	#HeadPort
	if core.get_head_port() != null:
		$HeadPort.texture = core.get_head_port()
		$HeadPort.position = core.get_head_port_offset()
		$HeadPort.show()
	else:
		$HeadPort.texture = null
		$HeadPort.hide()
	#CoreSub
	if core.get_sub() != null:
		$CoreSub.texture = core.get_sub()
		$CoreSub.show()
	else:
		$CoreSub.texture = null
		$CoreSub.hide()

func set_legs(part_name):
	if not part_name:
		legs = null
		$Legs.texture = null
		$LegsCollision.polygon = []
		return
		
	var part_data = PartManager.get_part("legs", part_name)
	$Legs.texture = part_data.get_image()
	$LegsCollision.polygon = part_data.get_collision()
	legs = part_data



func set_head(part_name):
	var part_data = PartManager.get_part("head", part_name)
	$Head.texture = part_data.image
	head = part_data
	if core:
		$Head.position = core.get_head_port_offset()


func set_shoulder(part_name, side):
	var part_data = PartManager.get_part("shoulder", part_name)
	var node
	var collision_node
	if side == SIDE.LEFT:
		node = $LeftShoulder
		collision_node = $LeftShoulderCollision
		if core:
			node.position = core.get_shoulder_offset("left")
			collision_node.position = core.get_shoulder_offset("left")
	elif side == SIDE.RIGHT:
		node = $RightShoulder
		collision_node = $RightShoulderCollision
		if core:
			node.position = core.get_shoulder_offset("right")
			collision_node.position = core.get_shoulder_offset("right")
	else:
		push_error("Not a valid side: " + str(side))
	
	node.texture = part_data.get_image()
	collision_node.polygon = part_data.get_collision()

#ATTRIBUTE METHODS


func get_max_hp():
	return max_hp


func get_weight():
	assert(core, "Mecha doesn't have an assigned core")
	return float(core.weight)


func get_weapon_part(part_name):
	if part_name == "arm_weapon_left":
		if arm_weapon_left:
			return $ArmWeaponLeft
	elif part_name == "arm_weapon_right":
		if arm_weapon_right:
			return $ArmWeaponRight
	elif part_name == "shoulder_weapon_left":
		if shoulder_weapon_left:
			return $ShoulderWeaponLeft
	elif part_name == "shoulder_weapon_right":
		if shoulder_weapon_right:
			return $ShoulderWeaponRight
	else:
		push_error("Not a valid weapon part name: " + str(part_name))
	
	return false


func get_clip_ammo(part_name):
	var part = get_weapon_part(part_name)
	if part:
		return part.clip_ammo
	return false


func get_clip_size(part_name):
	var part = get_weapon_part(part_name)
	if part:
		return part.clip_size
	return false


func get_total_ammo(part_name):
	var part = get_weapon_part(part_name)
	if part:
		return part.total_ammo - (get_clip_size(part_name) - get_clip_ammo(part_name))
	return false
	
func get_max_ammo(part_name):
	var part = get_weapon_part(part_name)
	if part:
		return part.max_ammo
	return false

func get_ammo_cost(part_name):
	var part = get_weapon_part(part_name)
	if part:
		return part.ammo_cost
	return false

func set_ammo(part_name, target_val):
	var part = get_weapon_part(part_name)
	if typeof(target_val) == TYPE_INT:
		part.total_ammo = target_val

#MOVEMENT METHODS

func get_direction_from_vector(dir_vec, eight_directions = false):
	var margin = PI/8
	var angle = dir_vec.angle()
	if angle < 0:
		angle += 2*PI
	if not eight_directions:
		if angle > PI/4 - margin and angle <= 3*PI/4 + margin:
			return "down"
		if angle > 3*PI/4 - margin and angle <= 5*PI/4 + margin:
			return "left"
		if angle > 5*PI/4 - margin and angle <= 7*PI/4 + margin:
			return "up"
		if angle > 7*PI/4 - margin or angle <= PI/4 + margin:
			return "right"
	else:
		if angle > PI/2 - margin and angle <= PI/2 + margin:
			return "down"
		if angle >  PI/2 + PI/4 - margin and angle <= PI/2 + PI/4 + margin:
			return "downleft"
		if angle > PI - margin and angle <= PI + margin:
			return "left"
		if angle >  PI + PI/4 - margin and angle <= PI + PI/4 + margin:
			return "upleft"
		if angle > 3*PI/2 - margin and angle <= 3*PI/2 + margin:
			return "up"
		if angle > 3*PI/2 + PI/4 - margin and angle <= 3*PI/2 + PI/4 + margin:
			return "upright"
		if angle > 3*PI/2 + PI/4 + margin or angle <= margin:
			return "right"
		if angle > PI/4 - margin or angle <= PI/4 + margin:
			return "downright"
	

func apply_movement(dt, direction):
	if movement_type == "free":
		if direction.length() > 0:
			moving = true
			velocity = lerp(velocity, direction.normalized() * max_speed, move_acc*dt)
			mecha_heat = min(mecha_heat + move_heat*dt, 100)
		else:
			moving = false
			velocity = lerp(velocity, Vector2.ZERO, friction)
		velocity = move_and_slide(velocity*speed_modifier)
	elif movement_type == "relative":
		if direction.length() > 0:
			moving = true
			match get_direction_from_vector(direction, true):
				"down":
					direction = Vector2(0,1).rotated(deg2rad(rotation_degrees))
				"downleft":
					direction = Vector2(0,1).rotated(deg2rad(rotation_degrees))
					direction += -Vector2(1,0).rotated(deg2rad(rotation_degrees))
				"left":
					direction = -Vector2(1,0).rotated(deg2rad(rotation_degrees))
				"upleft":
					direction = -Vector2(0,1).rotated(deg2rad(rotation_degrees))
					direction += -Vector2(1,0).rotated(deg2rad(rotation_degrees))
				"up":
					direction = -Vector2(0,1).rotated(deg2rad(rotation_degrees))
				"upright":
					direction = -Vector2(0,1).rotated(deg2rad(rotation_degrees))
					direction += Vector2(1,0).rotated(deg2rad(rotation_degrees))
				"right":
					direction = Vector2(1,0).rotated(deg2rad(rotation_degrees))
				"downright":
					direction = Vector2(0,1).rotated(deg2rad(rotation_degrees))
					direction += Vector2(1,0).rotated(deg2rad(rotation_degrees))
			velocity = lerp(velocity, direction.normalized() * max_speed, move_acc*dt)
			mecha_heat = min(mecha_heat + move_heat*dt, 100)
		else:
			moving = false
			velocity = lerp(velocity, Vector2.ZERO, friction)
		velocity = move_and_slide(velocity*speed_modifier)
	elif movement_type == "tank":
		if direction.length() > 0:
			moving = false
			match get_direction_from_vector(direction):
				"down":
					direction = Vector2(0,1).rotated(deg2rad(rotation_degrees))
					moving = true
				"left":
					apply_rotation_by_direction(dt, "counter")
				"up":
					direction = -Vector2(0,1).rotated(deg2rad(rotation_degrees))
					moving = true
				"right":
					apply_rotation_by_direction(dt, "clock")

			if not moving:
				velocity = lerp(velocity, Vector2.ZERO, friction)
			else:
				velocity = lerp(velocity, direction.normalized() * max_speed, move_acc*dt)
				mecha_heat = min(mecha_heat + move_heat*dt, 100)
			velocity = move_and_slide(velocity)

		else:
			velocity = lerp(velocity, Vector2.ZERO, friction)
			velocity = move_and_slide(velocity*speed_modifier)
	else:
		push_error("Not a valid movement type: " + str(movement_type))


#Rotates solely the body given a direction ('clock' or 'counter'clock wise)
func apply_rotation_by_direction(dt, direction):
	if direction == "clock":
		rotation_degrees += 90*rotation_acc*dt
	elif direction == "counter":
		rotation_degrees -= 90*rotation_acc*dt
	else:
		push_error("Not a valid direction: " + str(direction))


func apply_rotation_by_point(dt, target_pos, stand_still):
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


func knockback(pos, strength, should_rotate = true):
	apply_movement(sqrt(strength)*2/get_weight(), global_position - pos)
	if should_rotate:
		apply_rotation_by_point(sqrt(strength)*2/get_weight(), pos, false)


#COMBAT METHODS

func shoot(type):
	var node
	var weapon_ref
	if type == "arm_weapon_left":
		node = $ArmWeaponLeft
		weapon_ref = arm_weapon_left
	elif type ==  "arm_weapon_right":
		node = $ArmWeaponRight
		weapon_ref = arm_weapon_right
	elif type == "shoulder_weapon_left":
		node = $ShoulderWeaponLeft
		weapon_ref = shoulder_weapon_left
	elif type ==  "shoulder_weapon_right":
		node = $ShoulderWeaponRight
		weapon_ref = shoulder_weapon_right
	else:
		push_error("Not a valid type of weapon to shoot: " + str(type))
	
	var amount = min(weapon_ref.number_projectiles, get_clip_ammo(type))
	amount = max(amount, 1) #Tries to shoot at least 1 projectile
	
	if not node.can_shoot(amount):
		if mecha_name == "Player":
			if node.clip_ammo <= 0:
				AudioManager.play_sfx("no_ammo", global_position)
		return
	
	node.shoot(amount)
	
	var variation = weapon_ref.bullet_spread/float(amount + 1) 
	var angle_offset = -weapon_ref.bullet_spread /2
	for _i in range(amount):
		angle_offset += variation
		emit_signal("create_projectile", self, 
					{
						"weapon_data": weapon_ref.projectile,
						"weapon_name": weapon_ref.name,
						"pos": node.get_shoot_position(),
						"dir": node.get_direction(angle_offset, weapon_ref.bullet_accuracy_margin),
						"damage_mod": weapon_ref.damage_modifier,
						"delay": rand_range(0, weapon_ref.bullet_spread_delay),
					})
	apply_recoil(type, weapon_ref.recoil_force)
	emit_signal("shoot")

func apply_recoil(type, recoil):
	var rotation = recoil*300/get_weight()
	if "left" in type:
		rotation *= -1
	rotation_degrees += rotation


func is_stunned():
	return not $StunTimer.is_stopped()


func stun(time):
	$StunTimer.wait_time = time
	$StunTimer.start()

# MISC METHODS

func play_step_sound(is_left := true):
	if mecha_name != "Player" or not moving:
		return
	var pitch
	if is_left:
		pitch = rand_range(.7, .72)
	else:
		pitch = rand_range(.95, .97)
	
	var volume = min(pow(velocity.length(), 1.3)/300.0 - 23.0, -5.0)
	AudioManager.play_sfx("robot_step", global_position, pitch, volume)

func extracting():
	$ExtractTimer.start()

func _on_ExtractTimer_timeout():
	if self.name == "Player":
		emit_signal("mecha_extracted", self)
	else:
		emit_signal("died", self)
		queue_free()

func cancel_extract():
	$ExtractTimer.stop()
	$ExtractTimer.wait_time = 5

func select_impact(calibre, is_shield):
	var sfx_idx
	match calibre:
		"Large":
			if is_shield:
				sfx_idx = "large_shield_impact" + str((randi()%2) + 1)
			else:
				sfx_idx = "large_impact" + str((randi()%2) + 1)
		"Medium":
			if is_shield:
				sfx_idx = "small_shield_impact" + str((randi()%3) + 1)
			else:
				sfx_idx = "medium_impact" + str((randi()%2) + 1)
		_:
			if is_shield:
				sfx_idx = "small_shield_impact" + str((randi()%3) + 1)
			else:
				sfx_idx = "small_impact" + str((randi()%2) + 1)
	AudioManager.play_sfx(sfx_idx, global_position)
