extends CharacterBody3D

func _ready():
	print("Player script loaded")

func _on_area_3d_body_entered(body):
	print("Player entered area: ", body.name)

func _on_area_3d_body_exited(body):
	print("Player exited area: ", body.name)
