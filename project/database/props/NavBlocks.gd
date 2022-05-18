extends Node2D



func get_collision_transform():
	return self.get_global_transform()


func get_collision():
	return self.polygon


func create_collision_polygon(distance):
	var pool_vector = PoolVector2Array()
	var prop_transform = get_collision_transform()
	var pool = Geometry.offset_polygon_2d(get_collision(), distance, 2)
	for vertex in pool[0]:
		pool_vector.append(prop_transform.xform(vertex))
	return pool_vector
