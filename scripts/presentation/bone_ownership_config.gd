class_name BoneOwnershipConfig
extends Resource

const OWNER_ANIMATION := "AnimationTree"
const OWNER_PROCEDURAL := "ProceduralMotor"
const OWNER_REACTION := "ReactionSpring"
const OWNER_LIMITS := "Limits"

@export var owners := {
	"Head": OWNER_REACTION,
	"Neck": OWNER_REACTION,
	"Spine": OWNER_PROCEDURAL,
	"Spine1": OWNER_PROCEDURAL,
	"Spine2": OWNER_PROCEDURAL,
	"Hips": OWNER_PROCEDURAL,
	"LeftArm": OWNER_PROCEDURAL,
	"LeftForeArm": OWNER_PROCEDURAL,
	"LeftHand": OWNER_PROCEDURAL,
	"RightArm": OWNER_PROCEDURAL,
	"RightForeArm": OWNER_PROCEDURAL,
	"RightHand": OWNER_PROCEDURAL,
	"LeftUpLeg": OWNER_PROCEDURAL,
	"LeftLeg": OWNER_PROCEDURAL,
	"LeftFoot": OWNER_PROCEDURAL,
	"RightUpLeg": OWNER_PROCEDURAL,
	"RightLeg": OWNER_PROCEDURAL,
	"RightFoot": OWNER_PROCEDURAL,
}

@export var angular_limits_deg := {
	"Head": Vector3(35.0, 45.0, 35.0),
	"Neck": Vector3(25.0, 30.0, 25.0),
	"Spine": Vector3(25.0, 35.0, 25.0),
	"Spine1": Vector3(28.0, 45.0, 28.0),
	"Spine2": Vector3(32.0, 55.0, 32.0),
	"Hips": Vector3(18.0, 35.0, 18.0),
}


func owner_for_bone(bone_name: String) -> String:
	var clean := bone_name.replace("mixamorig_", "")
	return str(owners.get(clean, OWNER_ANIMATION))


func validate_unique_owners() -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for bone in owners.keys():
		if seen.has(bone):
			errors.append("duplicate bone owner for %s" % bone)
		seen[bone] = true
		if str(owners[bone]) == "":
			errors.append("empty owner for %s" % bone)
	return errors


func clamp_euler(bone_name: String, euler: Vector3) -> Vector3:
	var clean := bone_name.replace("mixamorig_", "")
	var limits: Vector3 = angular_limits_deg.get(clean, Vector3(45.0, 65.0, 45.0))
	return Vector3(
		clampf(euler.x, -deg_to_rad(limits.x), deg_to_rad(limits.x)),
		clampf(euler.y, -deg_to_rad(limits.y), deg_to_rad(limits.y)),
		clampf(euler.z, -deg_to_rad(limits.z), deg_to_rad(limits.z))
	)
