extends Node3D

@onready var light: DirectionalLight3D = $"../WorldEnvironment/DirectionalLight3D"

func _ready():
    if light:
        var light_dir = -light.transform.basis.z
        print("Directional Light Direction: ", light_dir)
    else:
        print("DirectionalLight3D not found!")
