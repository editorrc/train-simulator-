class_name RigidMeshBatch
extends RefCounted
## Bake solid-colour meshes within one rigid part without changing their geometry/materials.
## Doors, lights and labels keep their own transforms. UV/UV2 carry scalar material inputs.

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
	EMISSION = COLOR.rgb * UV.x;
}
"""
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func merge(part: Node3D, exclude: Array[Node3D] = []) -> MeshInstance3D:
	var sources: Array[MeshInstance3D] = []
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collect(part, Transform3D.IDENTITY, exclude, tool, sources)
	if sources.is_empty():
		return null
	tool.index()
	var merged := MeshInstance3D.new()
	merged.mesh = tool.commit()
	merged.material_override = material()
	# Children are collected before removal; free deepest-first to preserve source transforms.
	sources.reverse()
	for source: MeshInstance3D in sources:
		source.free()
	part.add_child(merged)
	return merged


static func _collect(
	node: Node3D,
	local: Transform3D,
	exclude: Array[Node3D],
	tool: SurfaceTool,
	sources: Array[MeshInstance3D]
) -> void:
	for child: Node in node.get_children():
		var spatial: Node3D = child as Node3D
		if spatial == null or spatial in exclude or spatial is Light3D or spatial is Label3D:
			continue
		var transform: Transform3D = local * spatial.transform
		var mesh: MeshInstance3D = spatial as MeshInstance3D
		if mesh != null:
			if not _append(mesh, transform, tool):
				continue
			sources.append(mesh)
		_collect(spatial, transform, exclude, tool, sources)


static func _append(instance: MeshInstance3D, transform: Transform3D, tool: SurfaceTool) -> bool:
	var mat: StandardMaterial3D = instance.material_override as StandardMaterial3D
	if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	tool.set_color(mat.albedo_color)
	tool.set_uv2(Vector2(mat.metallic, mat.roughness))
	tool.set_uv(Vector2(mat.emission_energy_multiplier if mat.emission_enabled else 0.0, 0))
	var normal_basis: Basis = transform.basis.inverse().transposed()
	for surface: int in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		if indices.is_empty():
			for index: int in vertices.size():
				indices.append(index)
		for triangle: int in range(0, indices.size(), 3):
			var order: Array[int] = [
				indices[triangle], indices[triangle + 1], indices[triangle + 2]
			]
			var a: Vector3 = transform * vertices[order[0]]
			var b: Vector3 = transform * vertices[order[1]]
			var c: Vector3 = transform * vertices[order[2]]
			var normal: Vector3 = (
				normal_basis * (normals[order[0]] + normals[order[1]] + normals[order[2]])
			)
			# Godot front faces are clockwise. Repair procedural shells before enabling culling.
			if (b - a).cross(c - a).dot(normal) > 0:
				order.reverse()
			for index: int in order:
				tool.set_normal((normal_basis * normals[index]).normalized())
				tool.add_vertex(transform * vertices[index])
	return true
