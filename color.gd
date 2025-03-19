@tool
extends ColorRect

func _process(_delta: float) -> void:
    color.r = get_value(%Red)
    color.b = get_value(%Blue)
    color.g = get_value(%Green)

func get_value(obj) -> float:
    return obj.get_child(0).value