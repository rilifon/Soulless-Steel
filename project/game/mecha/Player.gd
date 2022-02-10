extends Mecha

signal update_reload_mode
signal reloading
signal finished_reloading

const ROTATION_DEADZONE = 20

onready var Cam = $Camera2D

var reload_mode := false

func _ready():
	setup()


func _physics_process(delta):
	if is_stunned():
		return
	
	check_input()
	
	apply_movement(delta, get_input())
	
	var target_pos = get_global_mouse_position()
	if target_pos.distance_to(global_position) > ROTATION_DEADZONE:
		apply_rotation_by_point(delta, target_pos, \
					   movement_type == "tank" or Input.is_action_pressed("strafe"))

func _input(event):
	if event.is_action_pressed("honk"):
		AudioManager.play_sfx("test", global_position)
	elif event.is_action_pressed("arm_weapon_left_shoot") and arm_weapon_left:
		if reload_mode:
			$ArmWeaponLeft.reload()
		elif not $ArmWeaponLeft.reloading:
			shoot("arm_weapon_left")
	elif event.is_action_pressed("arm_weapon_right_shoot") and arm_weapon_right:
		if reload_mode:
			$ArmWeaponRight.reload()
		elif not $ArmWeaponRight.reloading:
			shoot("arm_weapon_right")
	elif event.is_action_pressed("shoulder_weapon_left_shoot") and shoulder_weapon_left:
		shoot("shoulder_weapon_left")
	elif event.is_action_pressed("shoulder_weapon_right_shoot") and shoulder_weapon_right:
		shoot("shoulder_weapon_right")
	elif event.is_action_pressed("reload_mode") and not reload_mode:
		reload_mode = true
		emit_signal("update_reload_mode", reload_mode)
	elif event.is_action_released("reload_mode") and reload_mode:
		reload_mode = false
		emit_signal("update_reload_mode", reload_mode)
	elif event.is_action_pressed("debug_1"):
		die(self, "Myself")


func knockback(pos, strength, should_rotate = true):
	.knockback(pos, strength, should_rotate)
	if strength > 0:
		var dur = sqrt(strength)/10
		var freq = pow(strength, .3)*5
		var amp = pow(strength, .3)*5
		Cam.shake(dur, freq, amp, strength)


func apply_recoil(type, recoil):
	.apply_recoil(type, recoil)
	if recoil > 0:
		var dur = sqrt(recoil)/10
		var freq = pow(recoil, .3)*5
		var amp = pow(recoil, .3)*5
		Cam.shake(dur, freq, amp, recoil)


func check_input():
	check_weapon_input("arm_weapon_left", $ArmWeaponLeft, arm_weapon_left)
	check_weapon_input("arm_weapon_right", $ArmWeaponRight, arm_weapon_right)
	check_weapon_input("shoulder_weapon_left", $ShoulderWeaponLeft, shoulder_weapon_left)
	check_weapon_input("shoulder_weapon_right", $ShoulderWeaponRight, shoulder_weapon_right)


func check_weapon_input(name, node, weapon_ref):
	if weapon_ref and weapon_ref.auto_fire and not reload_mode and\
	   not node.reloading and Input.is_action_pressed(name+"_shoot"):
		shoot(name)


func setup():
	mecha_name = "Player"
	movement_type = "free"
	#rotation_acc = 2.0
	#friction = 0.3
	set_speed(500, 120)
	set_max_life(100)
	set_core("core_test2")
	set_head("head_test2")
	set_legs("legs_test1")
	set_arm_weapon("test_weapon3", SIDE.LEFT)
	set_arm_weapon("test_weapon2", SIDE.RIGHT)
	set_shoulder_weapon("test_weapon1", SIDE.RIGHT)
	set_shoulder_weapon(false, SIDE.LEFT)
	set_shoulder("shoulder_test2_left", SIDE.LEFT)
	set_shoulder("shoulder_test2_right", SIDE.RIGHT)


func set_arm_weapon(part_name, side):
	.set_arm_weapon(part_name, side)
	var node
	if side == SIDE.LEFT:
		node = $ArmWeaponLeft
	elif side == SIDE.RIGHT:
		node = $ArmWeaponRight
	node.connect("finished_reloading", self, "_on_finished_reloading")
	node.connect("reloading", self, "_on_reloading", [side])


func get_input():
	var mov_vec = Vector2()
	if Input.is_action_pressed('right'):
		mov_vec.x += 1
	if Input.is_action_pressed('left'):
		mov_vec.x -= 1
	if Input.is_action_pressed('down'):
		mov_vec.y += 1
	if Input.is_action_pressed('up'):
		mov_vec.y -= 1
	
	return mov_vec


func get_cam():
	return Cam


func _on_finished_reloading():
	emit_signal("finished_reloading")


func _on_reloading(reload_time, side):
	emit_signal("reloading", reload_time, side)
