extends Control

# Simple FPS display

var fps_label: Label

func _ready():
	# Create label
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	add_child(fps_label)
	
	# Position in top-left
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	fps_label.add_theme_constant_override("shadow_offset_x", 1)
	fps_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Make it always on top
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	if fps_label:
		var fps = Engine.get_frames_per_second()
		fps_label.text = "FPS: " + str(fps)
