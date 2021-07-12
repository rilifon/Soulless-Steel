extends Mecha

const LOGIC = preload("res://game/mecha/enemy_logic/EnemyLogic.gd")

var health = 100
var speed = 100
var mov_vec = Vector2()
var moving = false
var final_pos = false
var REACH_RANGE = 1
var logic
var all_mechas
var valid_target = false
var engage_distance = 300
var shooting_distance = 50
var current_state
var move_d_rand = 50
var navigation_node
var path : Array = []
var pos_for_blocked
var regions = [1, 2, 3, 4]
var old_region
var arena_size = Vector2(1500, 1000)


func _ready():
	logic = LOGIC.new()
	logic.setup()


func _process(delta):
	var state = logic.get_current_state()
	
	check_for_targets()
	
	if has_method("do_"+state):
		call("do_"+state, delta)
		
	logic.updateFiniteLogic(self)
	
	$Label.text = logic.get_current_state()

func setup(_all_mechas, _path_stuff):
	all_mechas = _all_mechas
	navigation_node = _path_stuff
	set_max_life(100)
	set_arm_weapon("test_weapon1", SIDE.RIGHT)
	set_arm_weapon("test_weapon1", SIDE.LEFT)
	set_shoulder_weapon("test_weapon1", SIDE.RIGHT)
	set_shoulder_weapon("test_weapon1", SIDE.LEFT)
	set_head("head_test")
	set_core("core_test")
	set_shoulder("shoulder_test_left", SIDE.LEFT)
	set_shoulder("shoulder_test_right", SIDE.RIGHT)


func random_pos():
	var screen_x = arena_size.x
	var screen_y = arena_size.y
	var new_region
	randomize()
	regions.shuffle()
	new_region = regions[0]
		
	if new_region != old_region:
		old_region = new_region
		if new_region == 1:
			return Vector2(rand_range(move_d_rand, screen_x/2),\
					  	   rand_range(move_d_rand, screen_y/2))
		elif new_region == 2:
			return Vector2(rand_range(screen_x/2, screen_x),\
					  	   rand_range(move_d_rand, screen_y/2))
		elif new_region == 3:
			return Vector2(rand_range(move_d_rand, screen_x/2),\
					  	   rand_range(screen_y/2, screen_y))
		else:
			return Vector2(rand_range(screen_x/2, screen_x),\
					  	   rand_range(screen_y/2, screen_y))
	else:
		old_region = regions[1]
		if new_region == 1:
			return Vector2(rand_range(move_d_rand, screen_x/2),\
					  	   rand_range(move_d_rand, screen_y/2))
		elif new_region == 2:
			return Vector2(rand_range(screen_x/2, screen_x),\
					  	   rand_range(move_d_rand, screen_y/2))
		elif new_region == 3:
			return Vector2(rand_range(move_d_rand, screen_x/2),\
					  	   rand_range(screen_y/2, screen_y))
		else:
			return Vector2(rand_range(screen_x/2, screen_x),\
					  	   rand_range(screen_y/2, screen_y))
		
		

func random_pos_targeting():
	randomize()
	var v_closeness = Vector2()
	var rand_pos = Vector2()
	
	## ifs to check where the enemy is and add the proper distance between them
	if position.x - valid_target.position.x < 0:
		v_closeness.x = -50
	else:
		v_closeness.x = 50
	
	if position.x - valid_target.position.y < 0:
		v_closeness.y = -50
	else:
		v_closeness.y = 50
	
	rand_pos = Vector2(rand_range(max(move_d_rand, valid_target.position.x-move_d_rand+v_closeness.x),\
				   min(arena_size.x-move_d_rand, valid_target.position.x+move_d_rand+v_closeness.x)),\
				   
				   rand_range(max(move_d_rand, valid_target.position.y-move_d_rand+v_closeness.y),\
				   min(arena_size.y-move_d_rand, valid_target.position.y+move_d_rand+v_closeness.y)))


	return navigation_node.get_closest_point(rand_pos)

func do_roaming(delta):
	var start_point = position
	
	if not final_pos:
		final_pos = random_pos()
	
	if not path:
		path = navigation_node.get_simple_path(self.global_position, final_pos)
	
	
	if path.size() > 0:
		
		apply_rotation(delta, Vector2(path[0].x-position.x,\
				   			  path[0].y-position.y), false)
								
		apply_movement(delta, Vector2(path[0].x-position.x,\
				   			  path[0].y-position.y))
		
		print(global_position.distance_to(path[0]))
		
		if global_position.distance_to(path[0]) <= 1:
			path.pop_front()
			if path.size() == 0:
				final_pos = random_pos()
				path = navigation_node.get_simple_path(self.global_position, final_pos)
	
		
	if not valid_target:
		check_for_targets()

	
	
func do_targeting(delta):
	if not valid_target:
		return
	var enemy_area =  random_pos_targeting()
	path = navigation_node.get_simple_path(self.position, enemy_area)
	
	if self.position.x < enemy_area.x + 10 or self.position.x < enemy_area.x - 10 and\
	   self.position.y < enemy_area.y + 10 or self.position.y < enemy_area.y - 10:
		apply_rotation(delta, valid_target.position, false)
		apply_movement(delta, Vector2(0,0))
	else:		
		for place in path:
			apply_rotation(delta, valid_target.position, false)
			apply_movement(delta, Vector2(enemy_area.x-self.position.x,\
								  enemy_area.y-self.position.y))

	shoot("left_arm_weapon")
	shoot("right_arm_weapon")


func do_idle(_delta):
	pass


func check_for_targets():
	var shortest_distance = 10000
	var target_to_return
	
	for target in all_mechas:
		if target != self:
			shortest_distance = min(target.position.distance_to(self.position), shortest_distance)
			if target.position.distance_to(self.position) == shortest_distance:
				target_to_return = target
		
	if abs(shortest_distance) < engage_distance:
		valid_target = target_to_return
	else:
		valid_target = false


 
