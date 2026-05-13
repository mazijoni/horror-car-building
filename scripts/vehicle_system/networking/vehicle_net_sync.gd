class_name VehicleNetSync
extends Node

# Multiplayer-ready structure (stub — expand with MultiplayerSynchronizer)
# Architecture: each VehicleRoot has a unique vehicle_id
# Build actions are sent as RPCs to all peers
# Physics state is synchronized via MultiplayerSynchronizer
# Only the "owner" simulates physics; others receive state updates

@export var authority_id: int = 1

var _vehicle: VehicleRoot

func _ready() -> void:
	_vehicle = get_parent() as VehicleRoot
	# Future: set_multiplayer_authority(authority_id)

func rpc_add_part(part_id: String, gp: Vector3i, orient_idx: int) -> void:
	if not multiplayer.is_server():
		return
	# Future: rpc("_remote_add_part", part_id, [gp.x, gp.y, gp.z], orient_idx)
	pass

func rpc_remove_part(gp: Vector3i) -> void:
	if not multiplayer.is_server():
		return
	pass
