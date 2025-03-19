extends Camera3D

@onready var target = $"../Mirror Surface/Ball"

@export var radius: float = 3.0
@export var speed: float = 0.15
@export var height_offset: float = -0.2

var angle: float = 0.0

func _process(delta: float) -> void:
    if target:
        angle += speed * delta
        var x = target.global_position.x + radius * cos(angle)
        var z = target.global_position.z + radius * sin(angle)
        var y = target.global_position.y + height_offset
        
        global_position = Vector3(x, y, z)
        look_at(target.global_position, Vector3.UP)
