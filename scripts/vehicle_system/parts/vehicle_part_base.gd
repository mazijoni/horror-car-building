class_name VehiclePartBase
extends Node3D

signal part_damaged(amount: float)
signal part_destroyed()

# ── @export — fill these in the Inspector on each part scene ──────────────────
@export_category("Identity")
@export var part_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: PartDefinition.Category = PartDefinition.Category.STRUCTURAL

@export_category("Physics")
@export var mass: float = 10.0
@export var is_mechanical: bool = false

@export_category("Durability")
@export var max_health: float = 100.0
@export var break_force: float = 5000.0

@export_category("Power")
@export var power_consumption: float = 0.0
@export var power_generation: float = 0.0
@export var fuel_consumption: float = 0.0

@export_category("Grid")
@export var grid_size: Vector3i = Vector3i(1, 1, 1)

# ── Runtime state (set by the vehicle system, not exported) ───────────────────
var definition: PartDefinition
var grid_position: Vector3i = Vector3i.ZERO
var orientation_idx: int = 0
var health: float = 100.0
var vehicle_root: VehicleRoot

var shape_owner_id: int = -1
var mechanical_body: RigidBody3D = null
var joint_node: Joint3D = null

func _ready() -> void:
	if definition:
		health = definition.max_health

# ── Definition builder — reads @export vars into a PartDefinition ─────────────
func build_definition() -> PartDefinition:
	var def := PartDefinition.new()
	def.part_id          = part_id
	def.display_name     = display_name
	def.description      = description
	def.category         = category
	def.mass             = mass
	def.is_mechanical    = is_mechanical
	def.max_health       = max_health
	def.break_force      = break_force
	def.power_consumption = power_consumption
	def.power_generation  = power_generation
	def.fuel_consumption  = fuel_consumption
	def.grid_size         = grid_size
	return def

func setup(def: PartDefinition, gp: Vector3i, orient_idx: int) -> void:
	definition    = def
	grid_position = gp
	orientation_idx = orient_idx
	health        = def.max_health
	name          = def.part_id + "_%d_%d_%d" % [gp.x, gp.y, gp.z]
	_build_visual()

func _build_visual() -> void:
	# Parts use the materials set in the catalog scene — no override applied.
	var found := false
	for child: Node in get_children():
		if child is MeshInstance3D:
			found = true
			break
	if not found:
		_build_mesh_fallback()

## Override in subclasses only if you have NO mesh children in the scene.
func _build_mesh_fallback() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * VehicleRoot.CELL_SIZE * 0.9
	mi.mesh = bm
	add_child(mi)

func get_collision_shape() -> Shape3D:
	# Only use an explicit CollisionShape3D child — no automatic fallback.
	for child: Node in get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).shape
	return null

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	emit_signal("part_damaged", amount)
	if health <= 0.0:
		emit_signal("part_destroyed")

func to_save_data() -> PartSaveData:
	var s := PartSaveData.new()
	s.part_id         = definition.part_id
	s.grid_pos        = grid_position
	s.orientation_idx = orientation_idx
	s.health          = health
	s.settings        = _get_settings()
	return s

func _get_settings() -> Dictionary:
	return {}

func physics_tick(_delta: float) -> void:
	pass
