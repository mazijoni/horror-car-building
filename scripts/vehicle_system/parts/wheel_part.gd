class_name WheelPart
extends VehiclePartBase

const WHEEL_RADIUS: float = VehicleRoot.CELL_SIZE * 0.55

@export_category("Wheel Config")
@export var is_motor: bool = true
@export var is_steering: bool = false
@export var motor_torque: float = 300.0
@export var steer_angle: float = 0.3
@export var suspension_stiffness: float = 1500.0
@export var suspension_damping: float = 400.0
@export var suspension_travel: float = VehicleRoot.CELL_SIZE * 0.4

# Accumulated wheel rotation angle (radians) used for visual spin.
var _roll_angle: float = 0.0
# Original mesh basis (the 90° cylinder rotation baked in the catalog scene).
var _mesh_rest_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	super._ready()
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		_mesh_rest_basis = mesh.basis

func _get_settings() -> Dictionary:
	return {
		"is_motor": is_motor,
		"is_steering": is_steering,
		"motor_torque": motor_torque,
		"steer_angle": steer_angle,
		"suspension_stiffness": suspension_stiffness,
		"suspension_damping": suspension_damping,
	}

func physics_tick(delta: float) -> void:
	if not vehicle_root:
		return

	# Axle is the vehicle's local X; wheels roll along the vehicle's local -Z.
	var chassis_up: Vector3 = vehicle_root.global_basis.y
	var mount: Vector3 = vehicle_root.to_global(vehicle_root.grid_to_local(grid_position))

	# Effective rolling direction (steered or straight).
	var steer_rot := Basis.IDENTITY
	if is_steering:
		steer_rot = Basis(chassis_up, vehicle_root.steer_input * steer_angle)
	var roll_dir: Vector3 = steer_rot * (-global_basis.z)

	# ── Raycast ───────────────────────────────────────────────────────────────
	var ray_end: Vector3 = mount - chassis_up * (suspension_travel + WHEEL_RADIUS)
	var space := vehicle_root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(mount, ray_end)
	var excluded := [vehicle_root.get_rid()]
	var player := vehicle_root.get_tree().get_first_node_in_group("Player")
	if player is CollisionObject3D:
		excluded.append((player as CollisionObject3D).get_rid())
	q.exclude = excluded
	var hit := space.intersect_ray(q)

	var wheel_center: Vector3 = mount - chassis_up * suspension_travel  # default: fully extended

	if not hit.is_empty():
		var contact: Vector3 = hit["position"]
		wheel_center = contact + chassis_up * WHEEL_RADIUS

		# ── Suspension spring/damper ───────────────────────────────────────────
		var dist: float = mount.distance_to(contact)
		var compression: float = clampf(suspension_travel + WHEEL_RADIUS - dist, 0.0, suspension_travel)

		# Project actual chassis velocity at the mount point onto the suspension
		# axis — this gives a smooth, physically correct damping signal.
		var vel_at_mount: Vector3 = (
				vehicle_root.linear_velocity
				+ vehicle_root.angular_velocity.cross(mount - vehicle_root.global_position))
		# susp_vel: positive = moving up (decompressing), negative = compressing.
		var susp_vel: float = vel_at_mount.dot(chassis_up)
		var spring_f: float = maxf(0.0,
				suspension_stiffness * compression - suspension_damping * susp_vel)
		vehicle_root.apply_force(chassis_up * spring_f, mount - vehicle_root.global_position)

		# ── Drive force ────────────────────────────────────────────────────────
		if is_motor:
			var throttle := vehicle_root.throttle_input
			if absf(throttle) > 0.01:
				vehicle_root.apply_force(roll_dir * throttle * motor_torque,
						mount - vehicle_root.global_position)

		# ── Accumulate roll angle from contact-point velocity ──────────────────
		_roll_angle += vel_at_mount.dot(roll_dir) / WHEEL_RADIUS * delta
	
	# ── Visual mesh: position at contact (suspension travel) + rolling spin ───
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		# global_basis = chassis basis × part orientation — keeps wheel locked to chassis.
		# Spin is applied around the world-space axle on top of that.
		var axle := global_basis.x
		var spin := Basis(axle, _roll_angle)
		mesh.global_transform = Transform3D(spin * global_basis * _mesh_rest_basis, wheel_center)
