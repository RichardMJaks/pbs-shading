extends MeshInstance3D

func edit_property(property: String, value: float) -> void:
	var shader = mesh.material

	shader.set_shader_parameter(property, value)

func _process(delta: float) -> void:
	var color = Color(%Red.get_child(0).value, %Green.get_child(0).value, %Blue.get_child(0).value)
	mesh.material.set_shader_parameter("ambient_color", color)
