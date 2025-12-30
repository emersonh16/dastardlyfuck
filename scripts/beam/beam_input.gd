extends Node

# BeamInput - Handles input for beam system
# Mouse wheel cycles modes, number keys switch directly

var beam_manager: Node = null

# Mode order for cycling (OFF → BUBBLE_MIN → BUBBLE_MAX → CONE → LASER)
var mode_order = [
	BeamManager.BeamMode.OFF,
	BeamManager.BeamMode.BUBBLE_MIN,
	BeamManager.BeamMode.BUBBLE_MAX,
	BeamManager.BeamMode.CONE,
	BeamManager.BeamMode.LASER
]

func _ready():
	beam_manager = get_node_or_null("/root/BeamManager")
	if not beam_manager:
		push_error("BeamInput: BeamManager not found!")
		return
	
	print("BeamInput initialized")

func _input(event):
	if not beam_manager:
		return
	
	# Mouse wheel - cycle through modes
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_mode(1)  # Forward
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_mode(-1)  # Backward
			get_viewport().set_input_as_handled()
	
	# Number keys - direct mode switching
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				beam_manager.set_mode(BeamManager.BeamMode.OFF)
			KEY_2:
				beam_manager.set_mode(BeamManager.BeamMode.BUBBLE_MIN)
			KEY_3:
				beam_manager.set_mode(BeamManager.BeamMode.BUBBLE_MAX)
			KEY_4:
				beam_manager.set_mode(BeamManager.BeamMode.CONE)
			KEY_5:
				beam_manager.set_mode(BeamManager.BeamMode.LASER)

func _cycle_mode(direction: int):
	# Find current mode index
	var current_mode = beam_manager.get_mode()
	var current_index = mode_order.find(current_mode)
	
	if current_index == -1:
		# Current mode not in list, default to first
		current_index = 0
	
	# Cycle to next/previous mode
	var new_index = current_index + direction
	
	# Wrap around
	if new_index < 0:
		new_index = mode_order.size() - 1
	elif new_index >= mode_order.size():
		new_index = 0
	
	# Set new mode
	var new_mode = mode_order[new_index]
	beam_manager.set_mode(new_mode)
