extends Node3D

@export var target_node: Node3D# target position (to follow the character)

@export var mouse_sensitivity = 0.1# camera rotation speed

@export var physical_skel:Skeleton3D# character physical skeleton

@onready var spring_arm = $SpringArm3D

var mouse_lock = false # is mouse locked

func _physics_process(delta):
	for child in physical_skel.get_children():
		# prevent the camera from clipping into the character
		if child is PhysicalBone3D:spring_arm.add_excluded_object(child.get_rid())
		
	if target_node != null:
		# lerp position to the target position
		global_position = lerp(global_position,target_node.global_position,0.5)

func _input(event):
	# mouse lock
	if Input.is_action_just_pressed("exit_camera"):
		mouse_lock = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		mouse_lock = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#rotate camera
	if event is InputEventMouseMotion and mouse_lock:
		rotation_degrees.y -= mouse_sensitivity*event.relative.x
		rotation_degrees.x -= mouse_sensitivity*event.relative.y
		rotation_degrees.x = clamp(rotation_degrees.x,-45,45)
	
		
