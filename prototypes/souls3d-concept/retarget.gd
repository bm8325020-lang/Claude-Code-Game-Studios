# PROTOTYPE - NOT FOR PRODUCTION
# Moves an animation from one humanoid skeleton to another with different bone names, proportions and rest pose
# (here: the Mixamo X Bot's tuned sword moves onto the customisable Quaternius hero). Each mapped bone copies the
# source bone's rotation change from its rest pose in model space; the hips also copy their movement, scaled to the
# target's hip height. Sampled at FPS frames per second.
extends RefCounted

const FPS := 30.0
# Mixamo bone (without the mixamorig_ prefix) -> Unreal mannequin bone used by the Quaternius characters
const MAP := {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r",
	"LeftHandThumb1": "thumb_01_l", "LeftHandThumb2": "thumb_02_l", "LeftHandThumb3": "thumb_03_l",
	"LeftHandIndex1": "index_01_l", "LeftHandIndex2": "index_02_l", "LeftHandIndex3": "index_03_l",
	"LeftHandMiddle1": "middle_01_l", "LeftHandMiddle2": "middle_02_l", "LeftHandMiddle3": "middle_03_l",
	"LeftHandRing1": "ring_01_l", "LeftHandRing2": "ring_02_l", "LeftHandRing3": "ring_03_l",
	"LeftHandPinky1": "pinky_01_l", "LeftHandPinky2": "pinky_02_l", "LeftHandPinky3": "pinky_03_l",
	"RightHandThumb1": "thumb_01_r", "RightHandThumb2": "thumb_02_r", "RightHandThumb3": "thumb_03_r",
	"RightHandIndex1": "index_01_r", "RightHandIndex2": "index_02_r", "RightHandIndex3": "index_03_r",
	"RightHandMiddle1": "middle_01_r", "RightHandMiddle2": "middle_02_r", "RightHandMiddle3": "middle_03_r",
	"RightHandRing1": "ring_01_r", "RightHandRing2": "ring_02_r", "RightHandRing3": "ring_03_r",
	"RightHandPinky1": "pinky_01_r", "RightHandPinky2": "pinky_02_r", "RightHandPinky3": "pinky_03_r"}

# a context for one source/target skeleton pair, reused for every clip
static func pair(src: Skeleton3D, dst: Skeleton3D, prefix := "mixamorig_") -> Dictionary:
	var ctx := {"src": src, "dst": dst, "map": {}, "src_rest_g": [], "dst_rest_g": [], "order": []}
	for s in MAP:
		var si := src.find_bone(prefix + s)
		var di := dst.find_bone(MAP[s])
		if si >= 0 and di >= 0:
			ctx.map[di] = si
	for i in src.get_bone_count():
		ctx.src_rest_g.append(src.get_bone_global_rest(i).basis.get_rotation_quaternion())
	for i in dst.get_bone_count():
		ctx.dst_rest_g.append(dst.get_bone_global_rest(i).basis.get_rotation_quaternion())
	ctx.src_hips = src.find_bone(prefix + "Hips")
	ctx.dst_hips = dst.find_bone("pelvis")
	ctx.ratio = dst.get_bone_global_rest(ctx.dst_hips).origin.y / maxf(0.01, src.get_bone_global_rest(ctx.src_hips).origin.y)
	return ctx

static func clip(ctx: Dictionary, a: Animation) -> Animation:
	var src: Skeleton3D = ctx.src
	var dst: Skeleton3D = ctx.dst
	var rot_track := {}  # source bone -> rotation track
	var hips_pos := -1
	for t in a.get_track_count():
		var bone := src.find_bone(String(a.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_track[bone] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == ctx.src_hips:
			hips_pos = t
	var out := Animation.new()
	out.length = a.length
	out.loop_mode = a.loop_mode
	var tracks := {}
	for di in ctx.map:
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("Skeleton3D:" + dst.get_bone_name(di)))
		tracks[di] = tr
	var pos_tr := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pos_tr, NodePath("Skeleton3D:" + dst.get_bone_name(ctx.dst_hips)))
	var src_hips_rest: Vector3 = src.get_bone_rest(ctx.src_hips).origin
	var n := maxi(1, ceili(a.length * FPS))
	var sg := []  # source global rotations at this frame
	sg.resize(src.get_bone_count())
	var dg := []
	dg.resize(dst.get_bone_count())
	for f in n + 1:
		var time := minf(f / FPS, a.length)
		for i in src.get_bone_count():  # forward kinematics of the source pose (parents come first)
			var local: Quaternion = a.rotation_track_interpolate(rot_track[i], time) if rot_track.has(i) else src.get_bone_rest(i).basis.get_rotation_quaternion()
			var p := src.get_bone_parent(i)
			sg[i] = (sg[p] * local) if p >= 0 else local
		for i in dst.get_bone_count():
			var p := dst.get_bone_parent(i)
			var parent_g: Quaternion = dg[p] if p >= 0 else Quaternion.IDENTITY
			if ctx.map.has(i):
				var s: int = ctx.map[i]
				dg[i] = sg[s] * ctx.src_rest_g[s].inverse() * ctx.dst_rest_g[i]
				out.rotation_track_insert_key(tracks[i], time, (parent_g.inverse() * dg[i]).normalized())
			else:
				dg[i] = parent_g * dst.get_bone_rest(i).basis.get_rotation_quaternion()
		var move := Vector3.ZERO
		if hips_pos >= 0:
			move = (a.position_track_interpolate(hips_pos, time) - src_hips_rest) * ctx.ratio
		var hp := dst.get_bone_parent(ctx.dst_hips)
		var hp_g: Quaternion = dg[hp] if hp >= 0 else Quaternion.IDENTITY
		out.position_track_insert_key(pos_tr, time, dst.get_bone_rest(ctx.dst_hips).origin + hp_g.inverse() * move)
	return out
