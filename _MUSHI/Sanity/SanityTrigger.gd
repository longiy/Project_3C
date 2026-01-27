extends Area3D

@export var target_sanity: float = 1.0
@export var transition_speed: float = 2.0
@export var world_environment_path: NodePath

var sanity_effect: CompositorEffect
var is_player_inside: bool = false
var original_sanity: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	var world_env = get_node(world_environment_path) as WorldEnvironment
	
	if world_env and world_env.compositor:
		var compositor_effects = world_env.compositor.compositor_effects
		
		for effect in compositor_effects:
			# Check if it has sanity_level property
			if "sanity_level" in effect:
				sanity_effect = effect
				original_sanity = effect.sanity_level
				print("Sanity effect found!")
				break

func _process(delta):
	if not sanity_effect:
		return
	
	var target = target_sanity if is_player_inside else original_sanity
	sanity_effect.sanity_level = move_toward(sanity_effect.sanity_level, target, transition_speed * delta)

func _on_body_entered(body):
	if body.is_in_group("player"):
		is_player_inside = true
		print("Player entered! Transitioning to sanity: ", target_sanity)

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_inside = false
		print("Player exited! Returning to sanity: ", original_sanity)
