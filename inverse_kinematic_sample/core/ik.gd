@tool
extends EditorScript

class LimitCone:
	var direction: Vector3
	var angle: float

	func _init(direction: Vector3, angle: float):
		self.direction = direction
		self.angle = angle

class BoneConstraint:
	var twist_from: float
	var twist_range: float
	var swing_limit_cones: Array

	func _init(twist_from: float = 0, twist_range : float = TAU, swing_limit_cones: Array = []):
		self.twist_from = twist_from
		self.twist_range = twist_range
		self.swing_limit_cones = swing_limit_cones

var bone_names = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftThumb", "RightThumb"]

func mirror_hand_pose(skeleton: Skeleton3D, source_bone_name: String, target_bone_name: String):
	var source_bone_index = skeleton.find_bone(source_bone_name)
	var target_bone_index = skeleton.find_bone(target_bone_name)
	if source_bone_index == -1 or target_bone_index == -1:
		return
	
	var source_transform = skeleton.get_bone_global_pose(source_bone_index)
	var target_transform = source_transform
	
	# Mirror the transform along the YZ plane (assuming the X-axis is the mirror axis)
	target_transform.origin.x = -source_transform.origin.x
	target_transform.basis.x = -source_transform.basis.x
	target_transform.basis.y = source_transform.basis.y
	target_transform.basis.z = source_transform.basis.z
	
	skeleton.set_bone_global_pose_override(target_bone_index, target_transform, 1.0, true)

func _run():
	var root: Node = get_scene()
	var nodes : Array[Node] = root.find_children("*", "ManyBoneIK3D")
	if nodes.is_empty():
		return
	var many_bone_ik: ManyBoneIK3D = nodes[0]

	many_bone_ik.set_process_thread_group(Node.PROCESS_THREAD_GROUP_SUB_THREAD)
	many_bone_ik.set_process_thread_group_order(100)

	var skeleton: Skeleton3D = many_bone_ik.get_skeleton()

	skeleton.show_rest_only = true
	skeleton.reset_bone_poses()
	many_bone_ik.set_constraint_count(0)
	var twist_constraints = {
		"Hips": Vector2(0, PI / 4),
		"Spine": Vector2(0, PI / 4),
		"Chest": Vector2(0, PI / 4),
		"UpperChest": Vector2(0, PI / 4),
		"Neck": Vector2(0, PI / 4),
		"Head": Vector2(0, PI / 4),
		"LeftUpperLeg": Vector2(-PI / 8, PI / 8),
		"RightUpperLeg": Vector2(-PI / 8, PI / 8),
		"LeftLowerLeg": Vector2(-PI / 8, PI / 8),
		"RightLowerLeg": Vector2(-PI / 8, PI / 8),
		"LeftFoot": Vector2(-PI / 8, PI / 8),
		"RightFoot": Vector2(-PI / 8, PI / 8),
		"LeftShoulder": Vector2(-PI / 8, PI / 8),
		"RightShoulder": Vector2(-PI / 8, PI / 8),
		"LeftUpperArm": Vector2(-PI / 8, PI / 8),
		"RightUpperArm": Vector2(-PI / 8, PI / 8),
		"LeftLowerArm": Vector2(-PI / 8, PI / 8),
		"RightLowerArm": Vector2(-PI / 8, PI / 8),
		"LeftHand": Vector2(-PI / 8, PI / 8),
		"RightHand": Vector2(-PI / 8, PI / 8),
		"LeftThumb": Vector2(-PI / 8, PI / 8),
		"RightThumb": Vector2(-PI / 8, PI / 8)
	}
	for bone_name_i in range(skeleton.get_bone_count()):
		var bone_name: StringName = skeleton.get_bone_name(bone_name_i)
		var swing_limit_cones = []
		var twist_range = PI * 2
		var twist_from = 0
		var ref_pose = skeleton.get_bone_global_rest(bone_name_i)
		var x_axis = ref_pose.basis.x
		var y_axis = ref_pose.basis.y
		var z_axis = ref_pose.basis.z
		
		# Hard code the type of joint and set the cones accordingly
		var joint_type = "ball_and_socket"  # Change this to "hinge" if needed
		match joint_type:
			"ball_and_socket":
				swing_limit_cones.append(LimitCone.new(x_axis.normalized(), deg_to_rad(45.0)))
				swing_limit_cones.append(LimitCone.new(y_axis.normalized(), deg_to_rad(45.0)))
				swing_limit_cones.append(LimitCone.new(z_axis.normalized(), deg_to_rad(45.0)))
		
		set_bone_constraint(many_bone_ik, bone_name, twist_from, twist_range, swing_limit_cones)
	for bone_name in twist_constraints.keys():
		var twist_from = twist_constraints[bone_name].x
		var twist_range = twist_constraints[bone_name].y
		var existing_constraint = get_bone_constraint(bone_name)
		set_bone_constraint(many_bone_ik, bone_name, twist_from, twist_range, existing_constraint.swing_limit_cones)
		# Mirror the right side of the arm to the left side of the arm
		mirror_hand_pose(skeleton, "RightUpperArm", "LeftUpperArm")
		mirror_hand_pose(skeleton, "RightLowerArm", "LeftLowerArm")
		mirror_hand_pose(skeleton, "RightHand", "LeftHand")

	var bones: Array = [
		"Root",
		"Hips",
		"Chest",
		"Head",
		"LeftShoulder",
		"LeftHand",
		"RightShoulder",
		"RightHand",
		"LeftLowerLeg",
		"LeftFoot",
		"RightLowerLeg",
		"RightFoot",
	]

	many_bone_ik.set_pin_count(0)
	many_bone_ik.set_pin_count(bones.size())

	var children: Array[Node] = root.find_children("*", "Marker3D")
	for i in range(children.size()):
		var node: Node = children[i] as Node
		node.queue_free()
	
	for pin_i in range(bones.size()):
		var bone_name: String = bones[pin_i]
		var marker_3d: Marker3D = Marker3D.new()
		marker_3d.name = bone_name
		many_bone_ik.add_child(marker_3d, true)
		marker_3d.owner = root
		var bone_i: int = skeleton.find_bone(bone_name)
		if bone_i == -1:
			continue
		var pose: Transform3D =  skeleton.get_bone_global_rest(bone_i)
		marker_3d.global_transform = pose
		many_bone_ik.set_effector_pin_node_path(pin_i, many_bone_ik.get_path_to(marker_3d))
		many_bone_ik.set_effector_bone_name(pin_i, bone_name)
		if bone_name == "Root":
			continue
		many_bone_ik.set_pin_motion_propagation_factor(pin_i, 1.0)

	skeleton.show_rest_only = false

var bone_constraints: Dictionary

func get_bone_constraint(p_bone_name: String) -> BoneConstraint:
	if bone_constraints.has(p_bone_name):
		return bone_constraints[p_bone_name]
	else:
		return BoneConstraint.new()

func set_bone_constraint(many_bone_ik: ManyBoneIK3D, p_bone_name: String, p_twist_from: float, p_twist_range: float, p_swing_limit_cones: Array):
	bone_constraints[p_bone_name] = BoneConstraint.new(p_twist_from, p_twist_range, p_swing_limit_cones)
	var constraint_count = many_bone_ik.get_constraint_count()
	many_bone_ik.set_constraint_count(constraint_count + 1)
	many_bone_ik.set_constraint_name_at_index(constraint_count, p_bone_name)
	many_bone_ik.set_joint_twist(constraint_count, Vector2(p_twist_from, p_twist_range))
	many_bone_ik.set_kusudama_open_cone_count(constraint_count, p_swing_limit_cones.size())
	for cone_constraint_i: int in range(p_swing_limit_cones.size()):
		var cone_constraint: LimitCone = p_swing_limit_cones[cone_constraint_i]
		many_bone_ik.set_kusudama_open_cone_center(constraint_count, cone_constraint_i, cone_constraint.direction)
		many_bone_ik.set_kusudama_open_cone_radius(constraint_count, cone_constraint_i, cone_constraint.angle)
