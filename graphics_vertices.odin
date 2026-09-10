package foster_framework

PosTexColVertex :: struct #packed {
	Pos: [2]f32,
	Tex: [2]f32,
	Col: Color,
}

make_pos_tex_col_vertex :: proc(position, texcoord: [2]f32, color: Color) -> PosTexColVertex {
	return PosTexColVertex{
		Pos = position,
		Tex = texcoord,
		Col = color,
	}
}

make_batcher_vertex :: proc(position, texcoord: [2]f32, color, mode: Color) -> BatcherVertex {
	return BatcherVertex{
		Pos = position,
		Tex = texcoord,
		Col = color,
		Mode = mode,
	}
}

vertex_format_of :: proc($T: typeid) -> VertexFormat {
	when T == BatcherVertex {
		return default_batcher_vertex_format()
	} else when T == PosTexColVertex {
		return default_pos_tex_col_vertex_format()
	} else {
		return vertex_format_make(nil, size_of(T))
	}
}

index_format_of :: proc($T: typeid) -> IndexFormat {
	when T == u16 || T == i16 {
		return .Sixteen
	} else when T == u32 || T == i32 {
		return .ThirtyTwo
	} else {
		panic("Unsupported index type")
	}
}

mesh_init_typed :: proc($TVertex: typeid, mesh: ^Mesh, graphics_device: ^GraphicsDevice, index_format: IndexFormat, name: string = "") {
	format := vertex_format_of(TVertex)
	defer vertex_format_dispose(&format)
	mesh_init_with_format(mesh, graphics_device, format, index_format, name)
}

mesh_init_instanced_typed :: proc($TVertex, $TInstance: typeid, mesh: ^Mesh, graphics_device: ^GraphicsDevice, index_format: IndexFormat, name: string = "") {
	vertex_format := vertex_format_of(TVertex)
	instance_format := vertex_format_of(TInstance)
	defer vertex_format_dispose(&vertex_format)
	defer vertex_format_dispose(&instance_format)
	mesh_init_instanced_with_format(mesh, graphics_device, vertex_format, instance_format, index_format, name)
}

mesh_init_typed_indexed :: proc($TVertex, $TIndex: typeid, mesh: ^Mesh, graphics_device: ^GraphicsDevice, name: string = "") {
	mesh_init_typed(TVertex, mesh, graphics_device, index_format_of(TIndex), name)
}

mesh_init_instanced_typed_indexed :: proc($TVertex, $TInstance, $TIndex: typeid, mesh: ^Mesh, graphics_device: ^GraphicsDevice, name: string = "") {
	mesh_init_instanced_typed(TVertex, TInstance, mesh, graphics_device, index_format_of(TIndex), name)
}

mesh_set_vertices_typed :: proc($T: typeid, mesh: ^Mesh, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	mesh_set_vertices(mesh, raw_data(data), len(data), offset)
}

mesh_set_instances_typed :: proc($T: typeid, mesh: ^Mesh, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	mesh_set_instances(mesh, raw_data(data), len(data), offset)
}

mesh_set_indices_typed :: proc($T: typeid, mesh: ^Mesh, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	mesh_set_indices(mesh, raw_data(data), len(data), offset)
}

vertex_buffer_init_typed :: proc($T: typeid, vb: ^VertexBuffer, graphics_device: ^GraphicsDevice, name: string = "") {
	format := vertex_format_of(T)
	defer vertex_format_dispose(&format)
	vertex_buffer_init_with_format(vb, graphics_device, format, name)
}

vertex_buffer_upload_typed :: proc($T: typeid, vb: ^VertexBuffer, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	vertex_buffer_upload(vb, raw_data(data), len(data), offset)
}

index_buffer_init_typed :: proc($T: typeid, ib: ^IndexBuffer, graphics_device: ^GraphicsDevice, name: string = "") {
	index_buffer_init(ib, graphics_device, index_format_of(T), name)
}

index_buffer_upload_typed :: proc($T: typeid, ib: ^IndexBuffer, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	index_buffer_upload(ib, raw_data(data), len(data), offset)
}

storage_buffer_init_typed :: proc($T: typeid, sb: ^StorageBuffer, graphics_device: ^GraphicsDevice, name: string = "") {
	storage_buffer_init(sb, graphics_device, size_of(T), name)
}

storage_buffer_upload_typed :: proc($T: typeid, sb: ^StorageBuffer, data: []T, offset: int = 0) {
	if len(data) <= 0 {
		return
	}
	storage_buffer_upload(sb, raw_data(data), len(data), offset)
}

MakePosTexColVertex :: make_pos_tex_col_vertex
MakeBatcherVertex :: make_batcher_vertex
VertexFormatOf :: vertex_format_of
IndexFormatOf :: index_format_of
MeshInitTyped :: proc{mesh_init_typed, mesh_init_typed_indexed}
MeshInitInstancedTyped :: proc{mesh_init_instanced_typed, mesh_init_instanced_typed_indexed}
MeshSetVerticesTyped :: mesh_set_vertices_typed
MeshSetInstancesTyped :: mesh_set_instances_typed
MeshSetIndicesTyped :: mesh_set_indices_typed
VertexBufferInitTyped :: vertex_buffer_init_typed
VertexBufferUploadTyped :: vertex_buffer_upload_typed
IndexBufferInitTyped :: index_buffer_init_typed
IndexBufferUploadTyped :: index_buffer_upload_typed
StorageBufferInitTyped :: storage_buffer_init_typed
StorageBufferUploadTyped :: storage_buffer_upload_typed
