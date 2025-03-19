extends HBoxContainer

@export var property_name: String

func edit_property(value: float) -> void:
	%Controls.change_var(property_name, value)
