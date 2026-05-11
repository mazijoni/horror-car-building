class_name PartDefinition
extends Resource

enum Category { STRUCTURAL, MECHANICAL, POWER, CONTROL, WEAPON, COSMETIC }

# Identity
@export var part_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.STRUCTURAL
@export var thumbnail: Texture2D

# Grid
@export var grid_size: Vector3i = Vector3i(1, 1, 1)

# Physics
@export var mass: float = 10.0
@export var linear_damp: float = 0.5
@export var angular_damp: float = 0.5
@export var is_mechanical: bool = false

# Durability
@export var max_health: float = 100.0
@export var break_force: float = 5000.0

# Power
@export var power_consumption: float = 0.0
@export var power_generation: float = 0.0
@export var fuel_consumption: float = 0.0

# Aerodynamics
@export var drag_area: float = 0.1

# 24 orientations (6 faces × 4 rotations) — built lazily
static var _orientations: Array[Basis] = []

static func get_orientation(index: int) -> Basis:
	if _orientations.is_empty():
		_build_orientations()
	return _orientations[clampi(index, 0, 23)]

static func orientation_count() -> int:
	return 24

static func _build_orientations() -> void:
	var faces: Array[Basis] = [
		Basis.IDENTITY,
		Basis(Vector3.RIGHT, PI * 0.5),
		Basis(Vector3.RIGHT, PI),
		Basis(Vector3.RIGHT, PI * 1.5),
		Basis(Vector3.FORWARD, PI * 0.5),
		Basis(Vector3.FORWARD, PI * 1.5),
	]
	var spins: Array[Basis] = [
		Basis.IDENTITY,
		Basis(Vector3.UP, PI * 0.5),
		Basis(Vector3.UP, PI),
		Basis(Vector3.UP, PI * 1.5),
	]
	for face: Basis in faces:
		for spin: Basis in spins:
			_orientations.append((face * spin).orthonormalized())
