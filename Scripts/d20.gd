extends RigidBody3D

# D20 Controller: assembles the body from DiceManager.gd (Class)

var face_directions := {}
var result_label: Label


func _ready():
	var vertices := DiceManager.generate_vertices()
	var faces := DiceManager.get_faces()

	# Visible die body
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = DiceManager.build_mesh(vertices, faces)
	add_child(mesh_instance)

	# Collision hull (slightly larger than the mesh so nothing clips the table)
	var collision_shape := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = DiceManager.build_collision_points(vertices)
	collision_shape.shape = shape
	add_child(collision_shape)

	# Face numbers — keep the direction -> number map for scoring the roll
	var label_data := DiceManager.create_face_labels(vertices, faces)
	face_directions = label_data.face_directions
	for label in label_data.labels:
		add_child(label)

	# Wire up the Roll button
	if has_node("CanvasLayer/Button"):
		$CanvasLayer/Button.pressed.connect(roll)
	else:
		push_error("Could not find the UI Button! Check your node paths.")

	_create_result_label()


# A small read-out at the top-center of the screen that announces the result.
func _create_result_label():
	if not has_node("CanvasLayer"):
		push_error("No CanvasLayer found for the result label.")
		return

	result_label = Label.new()
	result_label.text = "Roll is: -"
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.add_theme_color_override("font_color", Color.WHITE)

	# Small dark box behind the text so it reads against any background.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.55)
	box.set_content_margin_all(10)
	box.set_corner_radius_all(6)
	result_label.add_theme_stylebox_override("normal", box)

	$CanvasLayer.add_child(result_label)

	# Pin to the top-center with a 20px margin from the top, centered horizontally.
	result_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE
	)
	result_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_label.offset_top = 20


# --- PHYSICAL ROLLING LOGIC ---
func roll():
	print("The roll button was definitely clicked!")

	if result_label:
		result_label.text = "Rolling..."

	# Kill old momentum first so it doesn't stack on repeated rolls
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# keeps d20 die from flying off the table
	global_position = Vector3(0, 2.5, 0)
	rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	sleeping = false

	await get_tree().physics_frame

	# Build a throw that travels FORWARD across the table with a little lift with random directions
	var angle := randf() * TAU
	var throw_dir := Vector3(cos(angle), 0.0, sin(angle))   # flat, across the table
	var throw := throw_dir * randf_range(2.0, 3.5)          # forward push
	throw.y = randf_range(2.0, 3.0)                         # gentle lift

	apply_central_impulse(throw)

	
	# The roll axis is perpendicular to the throw direction (cross with UP).
	var roll_axis := throw_dir.cross(Vector3.UP).normalized()
	var spin := roll_axis * randf_range(6.0, 10.0)          # main tumbling roll
	# A touch of yaw + random wobble so faces don't land predictably.
	spin += Vector3(
		randf_range(-2.0, 2.0),
		randf_range(-3.0, 3.0),
		randf_range(-2.0, 2.0)
	)

	apply_torque_impulse(spin)

	# Re-arm the result-checking process
	set_physics_process(true)


func _physics_process(delta):
	if sleeping:
		get_rolled_number()
		set_physics_process(false)


# Finds the face whose outward normal points most directly upward.
func get_rolled_number():
	var best_face = 0
	var highest_dot = -1.0

	for local_dir in face_directions.keys():
		var global_dir = basis * local_dir
		var dot_product = global_dir.normalized().dot(Vector3.UP)

		if dot_product > highest_dot:
			highest_dot = dot_product
			best_face = face_directions[local_dir]

	print("The die landed on: ", best_face)

	if result_label:
		result_label.text = "Roll is: %d!" % best_face
