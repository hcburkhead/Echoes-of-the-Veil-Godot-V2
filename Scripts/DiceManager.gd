class_name DiceManager
extends RefCounted

# Shared builder for every dice prefab. Holds the "what a die is made of" logic
# made for D20 icosahedron shape


# The 12 vertices of an icosahedron, normalized onto the unit sphere.
static func generate_vertices() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0

	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)
	])

	for i in range(verts.size()):
		verts[i] = verts[i].normalized()

	return verts


# The 20 triangular faces, as triples of vertex indices.
static func get_faces() -> PackedInt32Array:
	return PackedInt32Array([
		0, 11, 5,   0, 5, 1,    0, 1, 7,    0, 7, 10,   0, 10, 11,
		1, 5, 9,    5, 11, 4,   11, 10, 2,  10, 7, 6,   7, 1, 8,
		3, 9, 4,    3, 4, 2,    3, 2, 6,    3, 6, 8,    3, 8, 9,
		4, 9, 5,    2, 4, 11,   6, 2, 10,   8, 6, 7,    9, 8, 1
	])


# Builds the visible die mesh in a blackish-gray material.
static func build_mesh(verts: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.17)  # blackish-gray
	surface_tool.set_material(mat)

	for v in verts:
		surface_tool.add_vertex(v)

	for index in indices:
		surface_tool.add_index(index)

	surface_tool.generate_normals()

	return surface_tool.commit()


# A collision hull slightly larger than the visible mesh (default 8%). The die
# rests on this invisible shell so its visual body and face numbers stay clear
# of the table instead of clipping through it.
static func build_collision_points(verts: PackedVector3Array, scale := 1.08) -> PackedVector3Array:
	var points := PackedVector3Array()
	for v in verts:
		points.append(v * scale)
	return points


# Builds a Label3D for each face. Returns a dictionary with:
#   "labels"          - Array[Label3D] for the caller to add to the tree
#   "face_directions" - { outward_dir (Vector3) : face_number (int) } for scoring
static func create_face_labels(verts: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var labels: Array[Label3D] = []
	var face_directions := {}
	var face_count := indices.size() / 3

	for i in range(face_count):
		var v0 := verts[indices[i * 3]]
		var v1 := verts[indices[i * 3 + 1]]
		var v2 := verts[indices[i * 3 + 2]]

		var center := (v0 + v1 + v2) / 3.0
		var outward_dir := center.normalized()

		var face_number := i + 1
		face_directions[outward_dir] = face_number

		var label := Label3D.new()
		label.text = str(face_number)
		label.font_size = 64
		label.outline_size = 12

		# Sit the number just barely proud of the face. A larger offset makes
		# the DOWN-facing number poke through the table when the die rests.
		label.position = center + (outward_dir * 0.005)

		var up_vec := Vector3.UP if abs(outward_dir.y) < 0.99 else Vector3.RIGHT
		label.transform.basis = Basis.looking_at(-outward_dir, up_vec)

		labels.append(label)

	return { "labels": labels, "face_directions": face_directions }
