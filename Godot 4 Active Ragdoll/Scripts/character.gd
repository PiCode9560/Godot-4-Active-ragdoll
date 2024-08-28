extends Node3D


# movement/walking/jumping stuff
const JUMP_STRENGTH = 70
const SPEED = 50
const DAMPING = 0.9
@onready var on_floor_left = $"Physical/Armature/Skeleton3D/Physical Bone LLeg2/OnFloorLeft" # shapecast on the feet to check if its on floor
@onready var on_floor_right = $"Physical/Armature/Skeleton3D/Physical Bone RLeg2/OnFloorRight" # shapecast on the feet to check if its on floor
@onready var jump_timer = $Physical/JumpTimer # timer to stop excidental double jump
var can_jump = true
var is_on_floor = false
var walking = false # if it is walking


# spring stuff
@export var angular_spring_stiffness: float = 4000.0
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

var physics_bones = [] # all physical bones

# turn it into ragdoll
@export var ragdoll_mode := false


@onready var physical_skel : Skeleton3D = $Physical/Armature/Skeleton3D
@onready var animated_skel : Skeleton3D = $Animated/Armature/Skeleton3D
@onready var camera_pivot = $CameraPivot
@onready var animation_tree = $Animated/AnimationTree
@onready var physical_bone_body : PhysicalBone3D = $"Physical/Armature/Skeleton3D/Physical Bone Body"


# grabbing related stuff
var active_arm_left = false
var active_arm_right = false
var grabbed_object = null
var grabbing_arm_left = false
var grabbing_arm_right = false
@onready var grab_joint_right = $Physical/GrabJointRight
@onready var grab_joint_left = $Physical/GrabJointLeft
@onready var physical_bone_l_arm_2 = $"Physical/Armature/Skeleton3D/Physical Bone LArm2"
@onready var physical_bone_r_arm_2 = $"Physical/Armature/Skeleton3D/Physical Bone RArm2"
@onready var l_grab_area = $"Physical/Armature/Skeleton3D/Physical Bone LArm2/LGrabArea"
@onready var r_grab_area = $"Physical/Armature/Skeleton3D/Physical Bone RArm2/RGrabArea"

var current_delta:float

func _ready():
	physical_skel.physical_bones_start_simulation()# activate ragdoll
	physics_bones = physical_skel.get_children().filter(func(x): return x is PhysicalBone3D) # get all the physical bones
	

func _input(event):
	if Input.is_action_just_pressed("ragdoll"): ragdoll_mode = bool(1-int(ragdoll_mode)) # toggle ragdoll mode

	active_arm_left = Input.is_action_pressed("grab_left")# activate left arm with mouse left click
	active_arm_right = Input.is_action_pressed("grab_right")# activate right arm with mouse right click
	
	if (not active_arm_left and grabbing_arm_left) or ragdoll_mode:
		#release whatever the arm is holding when ragdoll mode or the arm is deactivate
		grabbing_arm_left = false
		grab_joint_left.node_a = NodePath()
		grab_joint_left.node_b = NodePath()
		
	if (not active_arm_right and grabbing_arm_right) or ragdoll_mode:
		#release whatever the arm is holding when ragdoll mode or the arm is deactivate
		grabbing_arm_right = false
		grab_joint_right.node_a = NodePath()
		grab_joint_right.node_b = NodePath()

func _process(delta):
	var r = clamp((camera_pivot.rotation.x*2)/(PI)*2.1,-1,1)
	if active_arm_left or active_arm_right:
		animation_tree.set("parameters/grab_dir/blend_position",r) # move the arms toward the direction you're looking at
	else:
		animation_tree.set("parameters/grab_dir/blend_position",0)


func _physics_process(delta):
	current_delta = delta
	if not ragdoll_mode:# if not in ragdoll mode
		
		# walking control
		walking = false
		var dir = Vector3.ZERO
		if Input.is_action_pressed("move_forward"):
			dir += animated_skel.global_transform.basis.z
			walking = true
		if Input.is_action_pressed("move_left"):
			dir += animated_skel.global_transform.basis.x
			walking = true
		if Input.is_action_pressed("move_right"):
			dir -= animated_skel.global_transform.basis.x
			walking = true
		if Input.is_action_pressed("move_backward"):
			dir -= animated_skel.global_transform.basis.z
			walking = true
		dir = dir.normalized()

		physical_bone_body.linear_velocity += dir*SPEED*delta #move character
		physical_bone_body.linear_velocity *= Vector3(DAMPING,1,DAMPING)# add damping to make it less slippery
		
		
		#check if is on floor
		is_on_floor = false
		if on_floor_left.is_colliding():
			for i in on_floor_left.get_collision_count():
				if on_floor_left.get_collision_normal(i).y > 0.5:
					is_on_floor = true
					break
		if not is_on_floor: 
			if on_floor_right.is_colliding():
				for i in on_floor_right.get_collision_count():
					if on_floor_right.get_collision_normal(i).y > 0.5:
						is_on_floor = true
						break
		
		#jump
		if Input.is_action_pressed("jump"):
			if is_on_floor and can_jump:
				physical_bone_body.linear_velocity.y += JUMP_STRENGTH
				jump_timer.start()
				can_jump = false
		
		#play walking animation/idle
		if walking:animation_tree.set("parameters/walking/blend_amount",1)
		else:animation_tree.set("parameters/walking/blend_amount",0)

		#rotate the character toward the camera direction
		animated_skel.rotation.y = camera_pivot.rotation.y
# spring related function
func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)


func _on_r_grab_area_body_entered(body:Node3D):
	# check if the arm is touching something for grabbing
	if body is PhysicsBody3D and body.get_parent() != physical_skel:
		if active_arm_right and not grabbing_arm_right:
			grabbing_arm_right = true
			grab_joint_right.global_position = r_grab_area.global_position
			grab_joint_right.node_a = physical_bone_r_arm_2.get_path()
			grab_joint_right.node_b = body.get_path()


func _on_l_grab_area_body_entered(body:Node3D):
	# check if the arm is touching something for grabbing
	if body is PhysicsBody3D and body.get_parent() != physical_skel:
		if active_arm_left and not grabbing_arm_left:
			grabbing_arm_left = true
			grabbed_object = body
			grab_joint_left.global_position = l_grab_area.global_position
			grab_joint_left.node_a = physical_bone_l_arm_2.get_path()
			grab_joint_left.node_b = body.get_path()



func _on_jump_timer_timeout():
	# jump timer to avoid spamming jump and then fly away
	can_jump = true


func _on_skeleton_3d_skeleton_updated() -> void:
	if not ragdoll_mode:# if not in ragdoll mode
		# rotate the physical bones toward the animated bones rotations using hookes law
		for b:PhysicalBone3D in physics_bones:
			if not active_arm_left and b.name.contains("LArm"): continue # only rotated the arms if its activated
			if not active_arm_right and b.name.contains("RArm"): continue # only rotated the arms if its activated
			var target_transform: Transform3D = animated_skel.global_transform * animated_skel.get_bone_global_pose(b.get_bone_id())
			var current_transform: Transform3D = physical_skel.global_transform * physical_skel.get_bone_global_pose(b.get_bone_id())
			var rotation_difference: Basis = (target_transform.basis * current_transform.basis.inverse())
			var torque = hookes_law(rotation_difference.get_euler(), b.angular_velocity, angular_spring_stiffness, angular_spring_damping)
			torque = torque.limit_length(max_angular_force)
			
			b.angular_velocity += torque * current_delta
			
