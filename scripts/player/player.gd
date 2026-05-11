extends CharacterBody3D

# Player Nodes
@onready var head = $Head
@onready var eyes = $Head/eyes
@onready var standing_collision_shape = $standing_collision_shape
@onready var chrouching_collision_shape = $chrouching_collision_shape
@onready var ray_cast_3d = $RayCast3D
@onready var ledge_check_forward = $LedgeCheckForward
@onready var ledge_check_top = $LedgeCheckTop

# Speed Vars
@export var current_speed = 5.0
@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 2.0
@export var jump_velocity = 4.5
@export var mouse_sens = 0.5
@export var lerp_spead = 10.0
@export var direction: Vector3 = Vector3.ZERO
@export var crouching_depth = -0.5

# States
var walking = false
var sprinting = false
var crouching = false

# Head bobbing vars
@export var head_bobbing_sprinting_speed = 22.0
@export var head_bobbing_walking_speed = 14.0
@export var head_bobbing_crouching_speed = 10.0

@export var head_bobbing_sprinting_intensity = 0.2
@export var head_bobbing_walking_intensity = 0.1
@export var head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Extra sway/tilt strengths
@export var head_sway_strength: float = 0.4
@export var head_tilt_strength: float = 0.3

@export var crouch_look_down_limit: float = 50.0

# Ledge grab vars
var is_ledge_grabbing := false
var ledge_top_y := 0.0
var ledge_grab_yaw := 0.0
var ledge_release_timer := 0.0
const LEDGE_RELEASE_COOLDOWN := 0.4
@export var ledge_grab_look_limit_up: float = 60.0
@export var ledge_grab_look_limit_down: float = 25.0
@export var ledge_grab_yaw_limit: float = 45.0
@export var ledge_hang_offset: float = 1.6

# Vault vars
var is_vaulting := false
var vault_onto := false
var vault_timer := 0.0
var vault_start_pos := Vector3.ZERO
var vault_end_pos := Vector3.ZERO
@export var vault_duration: float = 0.5
@export var vault_check_distance: float = 1.2
@export var vault_low_height: float = 0.15
@export var vault_over_height: float = 0.9
@export var vault_onto_height: float = 1.35
var vault_exit_speed: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("Player")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		if is_ledge_grabbing:
			var yaw_diff: float = rotation.y - ledge_grab_yaw
			yaw_diff = clamp(yaw_diff, deg_to_rad(-ledge_grab_yaw_limit), deg_to_rad(ledge_grab_yaw_limit))
			rotation.y = ledge_grab_yaw + yaw_diff
			head.rotation.x = clamp(
				head.rotation.x,
				deg_to_rad(-ledge_grab_look_limit_up),
				deg_to_rad(ledge_grab_look_limit_down)
			)
		else:
			if crouching:
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-crouch_look_down_limit), deg_to_rad(89))
			else:
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _physics_process(delta: float) -> void:
	if ledge_release_timer > 0:
		ledge_release_timer -= delta

	if is_vaulting:
		_handle_vault(delta)
		return

	if is_ledge_grabbing:
		_handle_ledge_hang(delta)
		move_and_slide()
		return

	# Movement state
	if Input.is_action_pressed("crouch"):
		walking = false
		sprinting = false
		crouching = true
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1.0 + crouching_depth, delta * lerp_spead)
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = false

	elif Input.is_action_pressed("sprint") and not ray_cast_3d.is_colliding():
		walking = false
		sprinting = true
		crouching = false
		current_speed = sprinting_speed
		standing_collision_shape.disabled = false
		chrouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	elif not ray_cast_3d.is_colliding():
		walking = true
		sprinting = false
		crouching = false
		current_speed = walking_speed
		standing_collision_shape.disabled = false
		chrouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	else:
		walking = false
		sprinting = false
		crouching = true
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta * lerp_spead)
		standing_collision_shape.disabled = true
		chrouching_collision_shape.disabled = false

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Try ledge grab while airborne
	if not is_on_floor() and ledge_release_timer <= 0:
		_try_ledge_grab()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_spead)

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# Head bobbing
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta

	if is_on_floor() and input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		eyes.position.y = lerp(
			eyes.position.y,
			head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0),
			delta * lerp_spead
		)
		var sway_x: float = sin(head_bobbing_index * 0.5) * head_bobbing_current_intensity * head_sway_strength
		var tilt_z: float = sin(head_bobbing_index * 0.5) * head_bobbing_current_intensity * head_tilt_strength
		eyes.position.x = lerp(eyes.position.x, sway_x, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, tilt_z, delta * lerp_spead)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	move_and_slide()

	# Vault detection — sprint only
	if is_on_floor() and sprinting and ledge_release_timer <= 0 and direction.length() > 0.1:
		_try_vault()


func _try_vault() -> void:
	var move_dir := direction.normalized()
	var space := get_world_3d().direct_space_state

	var ray_origin := global_position + Vector3(0, 0.7, 0)
	var ray_end := ray_origin + move_dir * vault_check_distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	var sample: Vector3 = hit["position"] + move_dir * 0.2
	var top_origin := Vector3(sample.x, global_position.y + 2.2, sample.z)
	var top_end   := Vector3(sample.x, global_position.y - 0.3, sample.z)
	var top_query := PhysicsRayQueryParameters3D.create(top_origin, top_end)
	top_query.exclude = [self]
	var top_hit := space.intersect_ray(top_query)
	if top_hit.is_empty():
		return

	var obstacle_top_y: float = top_hit["position"].y
	var obstacle_height: float = obstacle_top_y - global_position.y

	if obstacle_height < vault_low_height or obstacle_height > vault_onto_height:
		return

	vault_onto = obstacle_height > vault_over_height
	vault_start_pos = global_position
	var travel: float = vault_check_distance + (0.4 if vault_onto else 0.9)
	vault_end_pos = global_position + move_dir * travel
	if vault_onto:
		vault_end_pos.y = obstacle_top_y + 0.05

	vault_duration = travel / current_speed
	vault_exit_speed = current_speed

	is_vaulting = true
	vault_timer = 0.0
	velocity = Vector3.ZERO


func _handle_vault(delta: float) -> void:
	vault_timer += delta
	var t: float = clamp(vault_timer / vault_duration, 0.0, 1.0)
	var smooth_t: float = smoothstep(0.0, 1.0, t)

	var arc_peak: float = 0.55 if not vault_onto else 0.25
	var target: Vector3 = vault_start_pos.lerp(vault_end_pos, smooth_t)
	target.y += sin(t * PI) * arc_peak

	global_position = target
	velocity = Vector3.ZERO

	eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
	eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
	eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)

	if t >= 1.0:
		_end_vault()


func _end_vault() -> void:
	is_vaulting = false
	var forward := vault_end_pos - vault_start_pos
	forward.y = 0.0
	velocity = forward.normalized() * vault_exit_speed


func _try_ledge_grab() -> void:
	if not ledge_check_forward.is_colliding():
		return
	if not ledge_check_top.is_colliding():
		return
	ledge_top_y = ledge_check_top.get_collision_point().y
	ledge_grab_yaw = rotation.y
	is_ledge_grabbing = true
	velocity = Vector3.ZERO
	standing_collision_shape.disabled = false
	chrouching_collision_shape.disabled = true
	walking = false
	sprinting = false
	crouching = false


func _handle_ledge_hang(delta: float) -> void:
	var target_y: float = ledge_top_y - ledge_hang_offset
	global_position.y = lerp(global_position.y, target_y, delta * lerp_spead)
	velocity = Vector3.ZERO

	eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_spead)
	eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_spead)
	eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta * lerp_spead)
	head.position.y = lerp(head.position.y, 1.8, delta * lerp_spead)

	# Jump → climb up
	if Input.is_action_just_pressed("jump"):
		is_ledge_grabbing = false
		ledge_release_timer = LEDGE_RELEASE_COOLDOWN
		global_position.y = ledge_top_y + 0.05
		global_position += -transform.basis.z * 0.6
		velocity = -transform.basis.z * 3.5
		return

	# Crouch → let go
	if Input.is_action_just_pressed("crouch"):
		is_ledge_grabbing = false
		ledge_release_timer = LEDGE_RELEASE_COOLDOWN
