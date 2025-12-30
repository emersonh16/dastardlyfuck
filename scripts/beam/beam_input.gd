extends Node

# BeamInput - Handles input for beam system
# Mouse wheel cycles modes, number keys switch directly

var beam_manager: Node = null

# Mode order for cycling (OFF → BUBBLE_MIN → BUBBLE_MAX → CONE_MIN → CONE_MAX → LASER)
var mode_order = [
	BeamManager.BeamMode.OFF,
	BeamManager.BeamMode.BUBBLE_MIN,
	BeamManager.BeamMode.BUBBLE_MAX,
	BeamManager.BeamMode.CONE_MIN,
	BeamManager.BeamMode.CONE_MAX,
	BeamManager.BeamMode.LASER
]

# Scroll sensitivity - require this many scroll events before changing mode
const SCROLL_THRESHOLD: int = 3
var scroll_accumulator: int = 0

func _ready():
	beam_manager = get_node_or_null("/root/BeamManager")
	if not beam_manager:
		push_error("BeamInput: BeamManager not found!")
		return
	
	print("BeamInput initialized")

func _input(event):
	if not beam_manager:
		return
	
	# Mouse wheel - cycle through modes (less sensitive)
	# Note: Mouse wheel events use factor, not pressed
	# Scroll DOWN goes toward LASER (forward), Scroll UP goes toward OFF (backward)
	if event is InputEventMouseButton:
		var scroll_direction: int = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_direction = -1  # Scroll UP = backward toward OFF
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_direction = 1  # Scroll DOWN = forward toward LASER
		
		if scroll_direction != 0:
			# Accumulate scroll events
			scroll_accumulator += scroll_direction
			
			# Only change mode when threshold is reached
			if abs(scroll_accumulator) >= SCROLL_THRESHOLD:
				var mode_change = 1 if scroll_accumulator > 0 else -1
				_cycle_mode(mode_change)
				scroll_accumulator = 0  # Reset accumulator
			
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
				beam_manager.set_mode(BeamManager.BeamMode.CONE_MIN)
			KEY_5:
				beam_manager.set_mode(BeamManager.BeamMode.CONE_MAX)
			KEY_6:
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
	
	# Lock at ends (no wrapping)
	# direction > 0 (scroll down) locks at LASER (last index)
	# direction < 0 (scroll up) locks at OFF (index 0)
	if new_index < 0:
		new_index = 0  # Lock at OFF
	elif new_index >= mode_order.size():
		new_index = mode_order.size() - 1  # Lock at LASER
	
	# Set new mode
	var new_mode = mode_order[new_index]
	beam_manager.set_mode(new_mode)
