package foster_framework

import "core:fmt"
import SDL "vendor:sdl3"

DrawableTarget :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Surface: rawptr,
	WidthInPixels: int,
	HeightInPixels: int,
	IsWindow: bool,
}

drawable_target_from_window :: proc(window: ^Window) -> DrawableTarget {
	if window == nil {
		return DrawableTarget{}
	}
	return DrawableTarget{
		GraphicsDevice = window.GraphicsDevice,
		Surface = window,
		WidthInPixels = Width(window),
		HeightInPixels = Height(window),
		IsWindow = true,
	}
}

drawable_target_from_target :: proc(target: ^Target) -> DrawableTarget {
	if target == nil {
		return DrawableTarget{}
	}
	return DrawableTarget{
		GraphicsDevice = target.GraphicsDevice,
		Surface = target,
		WidthInPixels = target.Width,
		HeightInPixels = target.Height,
		IsWindow = false,
	}
}

drawable_target_size_in_pixels :: proc(target: DrawableTarget) -> Point2 {
	return Point2{target.WidthInPixels, target.HeightInPixels}
}

drawable_target_bounds_in_pixels :: proc(target: DrawableTarget) -> RectInt {
	return RectInt{0, 0, target.WidthInPixels, target.HeightInPixels}
}

DrawableTargetFromWindow :: drawable_target_from_window
DrawableTargetFromTarget :: drawable_target_from_target
DrawableTargetSizeInPixels :: drawable_target_size_in_pixels
DrawableTargetBoundsInPixels :: drawable_target_bounds_in_pixels

TargetAttachmentSpec :: struct {
	Format: TextureFormat,
	SampleCount: SampleCount,
}

default_target_attachment_specs :: [1]TargetAttachmentSpec{{Format = .Color, SampleCount = .One}}

Target :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Name: string,
	Width: int,
	Height: int,
	Bounds: RectInt,
	Attachments: [dynamic]Texture,
	Disposed: bool,
}

target_init_with_attachments :: proc(target: ^Target, graphics_device: ^GraphicsDevice, width, height: int, attachments: []TargetAttachmentSpec, name: string = "") {
	if width <= 0 || height <= 0 {
		panic("Target width and height must be larger than 0")
	}
	if len(attachments) <= 0 {
		panic("Target needs at least 1 color attachment")
	}

	target.GraphicsDevice = graphics_device
	target.Name = name
	target.Width = width
	target.Height = height
	target.Bounds = RectInt{0, 0, width, height}
	target.Disposed = false
	target.Attachments = nil

	for attachment, index in attachments {
		usage: SDL.GPUTextureUsageFlags
		if texture_format_is_color_format(attachment.Format) {
			usage = SDL.GPUTextureUsageFlags{.SAMPLER, .COLOR_TARGET}
		} else {
			usage = SDL.GPUTextureUsageFlags{.DEPTH_STENCIL_TARGET}
		}

		attachment_name := name
		if attachment_name != "" {
			attachment_name = fmt.aprintf("%s-Attachment%d", name, index)
		}

		tex: Texture
		texture_init_ex(&tex, graphics_device, width, height, attachment.Format, attachment.SampleCount, usage, true, attachment_name)
		append(&target.Attachments, tex)
	}
}

target_init :: proc(target: ^Target, graphics_device: ^GraphicsDevice, width, height: int, name: string = "") {
	default_attachments := default_target_attachment_specs
	target_init_with_attachments(target, graphics_device, width, height, default_attachments[:], name)
}

target_dispose :: proc(target: ^Target) {
	if target == nil || target.Disposed {
		return
	}

	for i := 0; i < len(target.Attachments); i += 1 {
		if target.Attachments[i].GraphicsDevice != nil && target.Attachments[i].GraphicsDevice.Device != nil && target.Attachments[i].Resource != nil {
			SDL.ReleaseGPUTexture(target.Attachments[i].GraphicsDevice.Device, target.Attachments[i].Resource)
			target.Attachments[i].Resource = nil
		}
		if target.Attachments[i].GraphicsDevice != nil && target.Attachments[i].GraphicsDevice.Device != nil && target.Attachments[i].ResolveResource != nil {
			SDL.ReleaseGPUTexture(target.Attachments[i].GraphicsDevice.Device, target.Attachments[i].ResolveResource)
			target.Attachments[i].ResolveResource = nil
		}
		target.Attachments[i].Disposed = true
	}
	delete(target.Attachments)
	target.Disposed = true
}

target_attachment :: proc(target: ^Target, index: int = 0) -> ^Texture {
	if target == nil || index < 0 || index >= len(target.Attachments) {
		return nil
	}
	return &target.Attachments[index]
}

TargetInit :: proc{target_init, target_init_with_attachments}
TargetDispose :: target_dispose
TargetAttachment :: target_attachment

BoundSampler :: struct {
	Texture: ^Texture,
	Sampler: TextureSampler,
}

MaterialStage :: struct {
	Shader: ^Shader,
	Samplers: [16]BoundSampler,
	UniformBuffers: [8][dynamic]u8,
	UniformBufferObjects: [8]UniformBuffer,
	Stage: ShaderStage,
}

material_stage_init :: proc(stage: ^MaterialStage, shader_stage: ShaderStage) {
	stage.Stage = shader_stage
	stage.Shader = nil
	for i := 0; i < len(stage.UniformBuffers); i += 1 {
		stage.UniformBuffers[i] = nil
		uniform_buffer_init(&stage.UniformBufferObjects[i])
	}
}

material_stage_set_shader :: proc(stage: ^MaterialStage, shader: ^Shader) {
	if shader != nil && shader.Stage != stage.Stage {
		panic("Invalid Shader Stage")
	}
	stage.Shader = shader
}

material_stage_set_uniform_buffer :: proc(stage: ^MaterialStage, data: []u8, slot: int = 0) {
	if slot < 0 || slot >= len(stage.UniformBuffers) {
		panic("Uniform buffer slot out of range")
	}
	delete(stage.UniformBuffers[slot])
	stage.UniformBuffers[slot] = nil
	append(&stage.UniformBuffers[slot], ..data)
	uniform_buffer_clear(&stage.UniformBufferObjects[slot])
	uniform_buffer_set(&stage.UniformBufferObjects[slot], data)
}

material_stage_get_uniform_buffer :: proc(stage: ^MaterialStage, slot: int = 0) -> []u8 {
	if slot < 0 || slot >= len(stage.UniformBuffers) {
		return nil
	}
	return stage.UniformBuffers[slot][:]
}

material_stage_copy_to :: proc(stage: ^MaterialStage, to: ^MaterialStage) {
	to.Stage = stage.Stage
	to.Shader = stage.Shader
	to.Samplers = stage.Samplers
	for i := 0; i < len(stage.UniformBuffers); i += 1 {
		delete(to.UniformBuffers[i])
		to.UniformBuffers[i] = nil
		append(&to.UniformBuffers[i], ..stage.UniformBuffers[i][:])
		uniform_buffer_init(&to.UniformBufferObjects[i])
		uniform_buffer_set(&to.UniformBufferObjects[i], stage.UniformBufferObjects[i].Data[:])
	}
}

MaterialStageInit :: material_stage_init
MaterialStageSetShader :: material_stage_set_shader
MaterialStageSetUniformBuffer :: material_stage_set_uniform_buffer
MaterialStageGetUniformBuffer :: material_stage_get_uniform_buffer
MaterialStageGetUniformBufferObject :: proc(stage: ^MaterialStage, slot: int = 0) -> ^UniformBuffer {
	if stage == nil || slot < 0 || slot >= len(stage.UniformBufferObjects) { return nil }
	return &stage.UniformBufferObjects[slot]
}
MaterialStageCopyTo :: material_stage_copy_to
MaterialStageMaxUniformBuffers :: proc(stage:^MaterialStage)->int{if stage==nil{return 0};return len(stage.UniformBuffers)}
MaterialStageMaxSamplers :: proc(stage:^MaterialStage)->int{if stage==nil{return 0};return len(stage.Samplers)}
MaterialStageSetSampler :: proc(stage:^MaterialStage,index:int,texture:^Texture,sampler:TextureSampler){if stage==nil||index<0||index>=len(stage.Samplers){return};stage.Samplers[index]=BoundSampler{Texture=texture,Sampler=sampler}}
MaterialStageGetSampler :: proc(stage:^MaterialStage,index:int)->BoundSampler{if stage==nil||index<0||index>=len(stage.Samplers){return {}};return stage.Samplers[index]}

Material :: struct {
	Vertex: MaterialStage,
	Fragment: MaterialStage,
}

material_init_with_shaders :: proc(material: ^Material, vertex_shader: ^Shader, fragment_shader: ^Shader) {
	material_stage_init(&material.Vertex, .Vertex)
	material_stage_init(&material.Fragment, .Fragment)
	material_stage_set_shader(&material.Vertex, vertex_shader)
	material_stage_set_shader(&material.Fragment, fragment_shader)
}

material_init :: proc(material: ^Material) {
	material_init_with_shaders(material, nil, nil)
}

material_copy_to :: proc(material: ^Material, to: ^Material) {
	material_stage_copy_to(&material.Vertex, &to.Vertex)
	material_stage_copy_to(&material.Fragment, &to.Fragment)
}

material_copy_from :: proc(material: ^Material, from: ^Material) {
	material_copy_to(from, material)
}

material_clone :: proc(material: ^Material) -> Material {
	clone: Material
	material_init(&clone)
	material_copy_to(material, &clone)
	return clone
}

MaterialInit :: proc{material_init, material_init_with_shaders}
MaterialCopyTo :: material_copy_to
MaterialCopyFrom :: material_copy_from
MaterialClone :: material_clone

Mesh :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Name: string,
	VertexData: VertexBuffer,
	IndexData: IndexBuffer,
	InstanceData: VertexBuffer,
	HasInstanceBuffer: bool,
}

mesh_init_with_format :: proc(mesh: ^Mesh, graphics_device: ^GraphicsDevice, vertex_format: VertexFormat, index_format: IndexFormat, name: string = "") {
	mesh.GraphicsDevice = graphics_device
	mesh.Name = name
	vertex_name := ""
	index_name := ""
	if name != "" {
		vertex_name = fmt.aprintf("%s-Vertices", name)
		index_name = fmt.aprintf("%s-Indices", name)
	}
	vertex_buffer_init_with_format(&mesh.VertexData, graphics_device, vertex_format, vertex_name)
	index_buffer_init(&mesh.IndexData, graphics_device, index_format, index_name)
	mesh.HasInstanceBuffer = false
}

mesh_init :: proc(mesh: ^Mesh, graphics_device: ^GraphicsDevice, vertex_stride: int, index_format: IndexFormat, name: string = "") {
	mesh_init_with_format(mesh, graphics_device, vertex_format_make(nil, vertex_stride), index_format, name)
}

mesh_init_instanced_with_format :: proc(mesh: ^Mesh, graphics_device: ^GraphicsDevice, vertex_format, instance_format: VertexFormat, index_format: IndexFormat, name: string = "") {
	mesh_init_with_format(mesh, graphics_device, vertex_format, index_format, name)
	instance_name := ""
	if name != "" {
		instance_name = fmt.aprintf("%s-Instances", name)
	}
	vertex_buffer_init_with_format(&mesh.InstanceData, graphics_device, instance_format, instance_name)
	mesh.HasInstanceBuffer = true
}

mesh_init_instanced :: proc(mesh: ^Mesh, graphics_device: ^GraphicsDevice, vertex_stride, instance_stride: int, index_format: IndexFormat, name: string = "") {
	mesh_init_instanced_with_format(mesh, graphics_device, vertex_format_make(nil, vertex_stride), vertex_format_make(nil, instance_stride), index_format, name)
}

mesh_clear :: proc(mesh: ^Mesh) {
	vertex_buffer_clear(&mesh.VertexData)
	index_buffer_clear(&mesh.IndexData)
	if mesh.HasInstanceBuffer {
		vertex_buffer_clear(&mesh.InstanceData)
	}
}

mesh_set_index_count :: proc(mesh: ^Mesh, count: int) {
	index_buffer_clear(&mesh.IndexData)
	IndexBufferReserve(&mesh.IndexData, count)
}

mesh_set_vertex_count :: proc(mesh: ^Mesh, count: int) {
	vertex_buffer_clear(&mesh.VertexData)
	VertexBufferReserve(&mesh.VertexData, count)
}

mesh_set_instance_count :: proc(mesh: ^Mesh, count: int) {
	if !mesh.HasInstanceBuffer {
		panic("Mesh does not contain an instance buffer")
	}
	vertex_buffer_clear(&mesh.InstanceData)
	VertexBufferReserve(&mesh.InstanceData, count)
}

mesh_set_indices :: proc(mesh: ^Mesh, data: rawptr, count: int, offset: int = 0) {
	index_buffer_upload(&mesh.IndexData, data, count, offset)
}

mesh_set_vertices :: proc(mesh: ^Mesh, data: rawptr, count: int, offset: int = 0) {
	vertex_buffer_upload(&mesh.VertexData, data, count, offset)
}

mesh_set_instances :: proc(mesh: ^Mesh, data: rawptr, count: int, offset: int = 0) {
	if !mesh.HasInstanceBuffer {
		panic("Mesh does not contain an instance buffer")
	}
	vertex_buffer_upload(&mesh.InstanceData, data, count, offset)
}

mesh_dispose :: proc(mesh: ^Mesh) {
	vertex_buffer_dispose(&mesh.VertexData)
	index_buffer_dispose(&mesh.IndexData)
	if mesh.HasInstanceBuffer {
		vertex_buffer_dispose(&mesh.InstanceData)
	}
}

MeshInit :: proc{mesh_init, mesh_init_with_format}
MeshInitInstanced :: proc{mesh_init_instanced, mesh_init_instanced_with_format}
MeshClear :: mesh_clear
MeshSetIndexCount :: mesh_set_index_count
MeshSetVertexCount :: mesh_set_vertex_count
MeshSetInstanceCount :: mesh_set_instance_count
MeshSetIndices :: mesh_set_indices
MeshSetVertices :: mesh_set_vertices
MeshSetInstances :: mesh_set_instances
MeshDispose :: mesh_dispose
MeshVertexCount :: proc(mesh:^Mesh)->int{if mesh==nil{return 0};return mesh.VertexData.Base.Count}
MeshIndexCount :: proc(mesh:^Mesh)->int{if mesh==nil{return 0};return mesh.IndexData.Base.Count}
MeshInstanceCount :: proc(mesh:^Mesh)->int{if mesh==nil||!mesh.HasInstanceBuffer{return 0};return mesh.InstanceData.Base.Count}
MeshIsDisposed :: proc(mesh:^Mesh)->bool{return mesh==nil||mesh.VertexData.Base.Disposed}
MeshName :: proc(mesh:^Mesh)->string{if mesh==nil{return ""};return mesh.Name}

VertexBufferBinding :: struct {
	Buffer: ^VertexBuffer,
	InstanceInputRate: bool,
}

DrawCommand :: struct {
	Target: DrawableTarget,
	Material: ^Material,
	VertexBuffers: [dynamic]VertexBufferBinding,
	VertexStorageBuffers: [dynamic]^StorageBuffer,
	FragmentStorageBuffers: [dynamic]^StorageBuffer,
	IndexBuffer: ^IndexBuffer,
	IndexOffset: int,
	IndexCount: int,
	VertexOffset: int,
	VertexCount: int,
	InstanceCount: int,
	BlendMode: BlendMode,
	CullMode: CullMode,
	DepthCompare: DepthCompare,
	FillMode: FillMode,
	BackStencilState: StencilState,
	FrontStencilState: StencilState,
	StencilCompareMask: u8,
	StencilWriteMask: u8,
	StencilReferenceValue: u8,
	StencilTestEnabled: bool,
	DepthTestEnabled: bool,
	DepthWriteEnabled: bool,
	Viewport: RectInt,
	HasViewport: bool,
	Scissor: RectInt,
	HasScissor: bool,
}

draw_command_init :: proc(command: ^DrawCommand) {
	command.Target = DrawableTarget{}
	command.Material = nil
	command.VertexBuffers = nil
	command.VertexStorageBuffers = nil
	command.FragmentStorageBuffers = nil
	command.IndexBuffer = nil
	command.IndexOffset = 0
	command.IndexCount = 0
	command.VertexOffset = 0
	command.VertexCount = 0
	command.InstanceCount = 1
	command.BlendMode = BlendModePremultiply
	command.CullMode = .None
	command.DepthCompare = .Less
	command.FillMode = .Fill
	command.BackStencilState = StencilStateMake(.Keep, .Always)
	command.FrontStencilState = StencilStateMake(.Keep, .Always)
	command.StencilCompareMask = 0xff
	command.StencilWriteMask = 0xff
	command.StencilReferenceValue = 0
	command.StencilTestEnabled = false
	command.DepthTestEnabled = false
	command.DepthWriteEnabled = false
	command.HasViewport = false
	command.HasScissor = false
}

draw_command_from_mesh :: proc(command: ^DrawCommand, target: DrawableTarget, mesh: ^Mesh, material: ^Material) {
	draw_command_init(command)
	command.Target = target
	command.Material = material
	append(&command.VertexBuffers, VertexBufferBinding{Buffer = &mesh.VertexData, InstanceInputRate = false})

	if mesh.HasInstanceBuffer {
		append(&command.VertexBuffers, VertexBufferBinding{Buffer = &mesh.InstanceData, InstanceInputRate = true})
		command.InstanceCount = mesh.InstanceData.Base.Count
	}

	if mesh.IndexData.Base.Count > 0 {
		command.IndexBuffer = &mesh.IndexData
		command.IndexCount = mesh.IndexData.Base.Count
	} else {
		command.VertexCount = mesh.VertexData.Base.Count
	}
}

draw_command_from_vertex_buffer :: proc(command: ^DrawCommand, target: DrawableTarget, vertex_buffer: ^VertexBuffer, material: ^Material) {
	draw_command_init(command)
	command.Target = target
	command.Material = material
	append(&command.VertexBuffers, VertexBufferBinding{Buffer = vertex_buffer, InstanceInputRate = false})
	command.VertexCount = vertex_buffer.Base.Count
}

draw_command_dispose :: proc(command: ^DrawCommand) {
	delete(command.VertexBuffers)
	delete(command.VertexStorageBuffers)
	delete(command.FragmentStorageBuffers)
	command.VertexBuffers = nil
	command.VertexStorageBuffers = nil
	command.FragmentStorageBuffers = nil
}

DrawCommandInit :: draw_command_init
DrawCommandFromMesh :: draw_command_from_mesh
DrawCommandFromVertexBuffer :: draw_command_from_vertex_buffer
DrawCommandDispose :: draw_command_dispose

drawable_target_matches :: proc(a, b: DrawableTarget) -> bool {
	if a.GraphicsDevice != b.GraphicsDevice || a.IsWindow != b.IsWindow {
		return false
	}
	if a.IsWindow {
		return a.GraphicsDevice != nil
	}
	return a.Surface == b.Surface
}

resolve_drawable_target :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget) -> DrawableTarget {
	if graphics_device == nil {
		return target
	}
	if target.GraphicsDevice == nil {
		size := graphics_device.BackbufferSize
		if size.X <= 0 || size.Y <= 0 {
			size = Point2{int(graphics_device.SwapchainWidth), int(graphics_device.SwapchainHeight)}
		}
		return DrawableTarget{
			GraphicsDevice = graphics_device,
			Surface = graphics_device.Window,
			WidthInPixels = size.X,
			HeightInPixels = size.Y,
			IsWindow = true,
		}
	}
	if target.IsWindow && (target.WidthInPixels <= 0 || target.HeightInPixels <= 0) {
		resolved := target
		size := graphics_device.BackbufferSize
		if size.X <= 0 || size.Y <= 0 {
			size = Point2{int(graphics_device.SwapchainWidth), int(graphics_device.SwapchainHeight)}
		}
		resolved.WidthInPixels = size.X
		resolved.HeightInPixels = size.Y
		return resolved
	}
	return target
}

drawable_target_backing_target :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget) -> (^Target, Point2) {
	resolved := resolve_drawable_target(graphics_device, target)
	if resolved.IsWindow {
		if graphics_device != nil && graphics_device.HasWindowRenderTarget {
			return &graphics_device.WindowRenderTarget, Point2{int(graphics_device.SwapchainWidth), int(graphics_device.SwapchainHeight)}
		}
		if graphics_device == nil || !graphics_device.HasBackbufferTarget {
			return nil, {}
		}
		return &graphics_device.BackbufferTarget, graphics_device.BackbufferSize
	}
	target_ptr := cast(^Target)resolved.Surface
	if target_ptr == nil {
		return nil, {}
	}
	return target_ptr, Point2{target_ptr.Width, target_ptr.Height}
}

end_render_pass :: proc(graphics_device: ^GraphicsDevice) {
	if graphics_device == nil {
		return
	}
	if graphics_device.RenderPass != nil {
		SDL.EndGPURenderPass(graphics_device.RenderPass)
	}
	graphics_device.RenderPass = nil
	graphics_device.RenderPassTarget = {}
	graphics_device.RenderPassTargetSize = {}
	graphics_device.RenderPassPipeline = nil
	graphics_device.RenderPassIndexBuffer = nil
	graphics_device.HasRenderPassViewport = false
	graphics_device.HasRenderPassScissor = false
}

begin_render_pass_ex :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget, clear_colors: []Color, clear_depth: bool, depth: f32, clear_stencil: bool, stencil: int) -> bool {
	if graphics_device == nil || !graphics_device.InFrame || graphics_device.CommandBuffer == nil {
		return false
	}

	resolved_target := resolve_drawable_target(graphics_device, target)
	if resolved_target.GraphicsDevice != nil && resolved_target.GraphicsDevice != graphics_device {
		return false
	}
	if graphics_device.RenderPass != nil && drawable_target_matches(graphics_device.RenderPassTarget, resolved_target) && len(clear_colors) == 0 && !clear_depth && !clear_stencil {
		return true
	}

	end_render_pass(graphics_device)

	target_ptr, target_size := drawable_target_backing_target(graphics_device, resolved_target)
	if target_ptr == nil || len(target_ptr.Attachments) <= 0 {
		return false
	}

	color_targets := make([]SDL.GPUColorTargetInfo, len(target_ptr.Attachments), context.temp_allocator)
	color_count := 0
	depth_target_value := SDL.GPUDepthStencilTargetInfo{}
	depth_target_ptr: ^SDL.GPUDepthStencilTargetInfo = nil

	for i := 0; i < len(target_ptr.Attachments); i += 1 {
		attachment := target_ptr.Attachments[i]
		if attachment.Resource == nil {
			continue
		}

		if texture_format_is_color_format(attachment.Format) {
			color_target := SDL.GPUColorTargetInfo{
				texture = attachment.Resource,
				mip_level = 0,
				layer_or_depth_plane = 0,
				load_op = .LOAD,
				store_op = .STORE,
				cycle = len(clear_colors) > 0,
			}
			if attachment.ResolveResource != nil {
				color_target.store_op = .RESOLVE
				color_target.resolve_texture = attachment.ResolveResource
				color_target.resolve_mip_level = 0
				color_target.resolve_layer = 0
				color_target.cycle_resolve_texture = false
			}
			if len(clear_colors) > 0 {
				clear_color := Transparent
				if color_count < len(clear_colors) {
					clear_color = clear_colors[color_count]
				}
				color_target.clear_color = ColorToSDL(clear_color)
				color_target.load_op = .CLEAR
			}
			color_targets[color_count] = color_target
			color_count += 1
		} else {
			depth_target_value = SDL.GPUDepthStencilTargetInfo{
				texture = attachment.Resource,
				clear_depth = depth,
				load_op = .LOAD,
				store_op = .STORE,
				stencil_load_op = .LOAD,
				stencil_store_op = .STORE,
				cycle = clear_depth || clear_stencil,
				clear_stencil = u8(stencil),
			}
			if clear_depth {
				depth_target_value.load_op = .CLEAR
			}
			if clear_stencil {
				depth_target_value.stencil_load_op = .CLEAR
			}
			depth_target_ptr = &depth_target_value
		}
	}

	color_target_ptr: ^SDL.GPUColorTargetInfo = nil
	if color_count > 0 {
		color_target_ptr = &color_targets[0]
	}

	graphics_device.RenderPass = SDL.BeginGPURenderPass(graphics_device.CommandBuffer, color_target_ptr, u32(color_count), depth_target_ptr)
	graphics_device.RenderPassTargetSize = target_size

	if graphics_device.RenderPass == nil {
		return false
	}

	graphics_device.RenderPassTarget = resolved_target
	graphics_device.RenderPassPipeline = nil
	graphics_device.RenderPassIndexBuffer = nil
	graphics_device.HasRenderPassViewport = false
	graphics_device.HasRenderPassScissor = false
	return true
}

begin_render_pass :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget) -> bool {
	return begin_render_pass_ex(graphics_device, target, nil, false, 0, false, 0)
}

blend_factor_to_sdl :: proc(factor: BlendFactor) -> SDL.GPUBlendFactor {
	#partial switch factor {
	case .Zero:
		return .ZERO
	case .One:
		return .ONE
	case .SrcColor:
		return .SRC_COLOR
	case .OneMinusSrcColor:
		return .ONE_MINUS_SRC_COLOR
	case .DstColor:
		return .DST_COLOR
	case .OneMinusDstColor:
		return .ONE_MINUS_DST_COLOR
	case .SrcAlpha:
		return .SRC_ALPHA
	case .OneMinusSrcAlpha:
		return .ONE_MINUS_SRC_ALPHA
	case .DstAlpha:
		return .DST_ALPHA
	case .OneMinusDstAlpha:
		return .ONE_MINUS_DST_ALPHA
	case .ConstantColor:
		return .CONSTANT_COLOR
	case .OneMinusConstantColor:
		return .ONE_MINUS_CONSTANT_COLOR
	case .SrcAlphaSaturate:
		return .SRC_ALPHA_SATURATE
	}
	return .ONE
}

blend_op_to_sdl :: proc(op: BlendOp) -> SDL.GPUBlendOp {
	#partial switch op {
	case .Add:
		return .ADD
	case .Subtract:
		return .SUBTRACT
	case .ReverseSubtract:
		return .REVERSE_SUBTRACT
	case .Min:
		return .MIN
	case .Max:
		return .MAX
	}
	return .ADD
}

blend_mask_to_sdl :: proc(mask: BlendMask) -> SDL.GPUColorComponentFlags {
	flags: SDL.GPUColorComponentFlags = {}
	mask_bits := u8(mask)
	if (mask_bits & u8(BlendMask.Red)) != 0 do flags += {.R}
	if (mask_bits & u8(BlendMask.Green)) != 0 do flags += {.G}
	if (mask_bits & u8(BlendMask.Blue)) != 0 do flags += {.B}
	if (mask_bits & u8(BlendMask.Alpha)) != 0 do flags += {.A}
	return flags
}

cull_mode_to_sdl :: proc(mode: CullMode) -> SDL.GPUCullMode {
	#partial switch mode {
	case .None:
		return .NONE
	case .Front:
		return .FRONT
	case .Back:
		return .BACK
	}
	return .NONE
}

fill_mode_to_sdl :: proc(mode: FillMode) -> SDL.GPUFillMode {
	#partial switch mode {
	case .Fill:
		return .FILL
	case .Line:
		return .LINE
	}
	return .FILL
}

stencil_op_to_sdl :: proc(op: StencilOp) -> SDL.GPUStencilOp {
	#partial switch op {
	case .Keep:
		return .KEEP
	case .Zero:
		return .ZERO
	case .Replace:
		return .REPLACE
	case .IncrementAndClamp:
		return .INCREMENT_AND_CLAMP
	case .DecrementAndClamp:
		return .DECREMENT_AND_CLAMP
	case .Invert:
		return .INVERT
	case .IncrementAndWrap:
		return .INCREMENT_AND_WRAP
	case .DecrementAndWrap:
		return .DECREMENT_AND_WRAP
	case .Invalid:
		return .INVALID
	}
	return .KEEP
}

stencil_state_to_sdl :: proc(state: StencilState) -> SDL.GPUStencilOpState {
	return SDL.GPUStencilOpState{
		fail_op = stencil_op_to_sdl(state.FailOp),
		pass_op = stencil_op_to_sdl(state.PassOp),
		depth_fail_op = stencil_op_to_sdl(state.DepthFailOp),
		compare_op = depth_compare_to_sdl(state.CompareOp),
	}
}

depth_compare_to_sdl :: proc(compare: DepthCompare) -> SDL.GPUCompareOp {
	#partial switch compare {
	case .Always:
		return .ALWAYS
	case .Never:
		return .NEVER
	case .Less:
		return .LESS
	case .Equal:
		return .EQUAL
	case .LessOrEqual:
		return .LESS_OR_EQUAL
	case .Greater:
		return .GREATER
	case .NotEqual:
		return .NOT_EQUAL
	case .GreatorOrEqual:
		return .GREATER_OR_EQUAL
	}
	return .ALWAYS
}

texture_filter_to_sdl :: proc(filter: TextureFilter) -> SDL.GPUFilter {
	#partial switch filter {
	case .Nearest:
		return .NEAREST
	case .Linear:
		return .LINEAR
	}
	return .LINEAR
}

texture_wrap_to_sdl :: proc(wrap: TextureWrap) -> SDL.GPUSamplerAddressMode {
	#partial switch wrap {
	case .Repeat:
		return .REPEAT
	case .MirroredRepeat:
		return .MIRRORED_REPEAT
	case .Clamp:
		return .CLAMP_TO_EDGE
	}
	return .CLAMP_TO_EDGE
}

create_sampler_from_texture_sampler :: proc(graphics_device: ^GraphicsDevice, sampler: TextureSampler) -> ^SDL.GPUSampler {
	if graphics_device == nil || graphics_device.Device == nil {
		return nil
	}
	if graphics_device.SamplerCache == nil {
		graphics_device.SamplerCache = make(map[TextureSampler]^SDL.GPUSampler)
	}
	if cached, ok := graphics_device.SamplerCache[sampler]; ok && cached != nil {
		return cached
	}
	info := SDL.GPUSamplerCreateInfo{
		min_filter = texture_filter_to_sdl(sampler.Filter),
		mag_filter = texture_filter_to_sdl(sampler.Filter),
		mipmap_mode = .LINEAR,
		address_mode_u = texture_wrap_to_sdl(sampler.WrapX),
		address_mode_v = texture_wrap_to_sdl(sampler.WrapY),
		address_mode_w = .CLAMP_TO_EDGE,
		mip_lod_bias = 0,
		max_anisotropy = 1,
		compare_op = .ALWAYS,
		min_lod = 0,
		max_lod = 0,
		enable_anisotropy = false,
		enable_compare = false,
		props = 0,
	}
	created := SDL.CreateGPUSampler(graphics_device.Device, info)
	if created != nil {
		graphics_device.SamplerCache[sampler] = created
	}
	return created
}

hash_mix_u64 :: proc(h, v: u64) -> u64 {
	x := h ~ v
	x *= 1099511628211
	return x
}

hash_color_u32 :: proc(c: Color) -> u32 {
	return u32(c.R) | (u32(c.G) << 8) | (u32(c.B) << 16) | (u32(c.A) << 24)
}

hash_blend_mode :: proc(seed: u64, bm: BlendMode) -> u64 {
	h := seed
	h = hash_mix_u64(h, u64(bm.ColorOperation))
	h = hash_mix_u64(h, u64(bm.ColorSource))
	h = hash_mix_u64(h, u64(bm.ColorDestination))
	h = hash_mix_u64(h, u64(bm.AlphaOperation))
	h = hash_mix_u64(h, u64(bm.AlphaSource))
	h = hash_mix_u64(h, u64(bm.AlphaDestination))
	h = hash_mix_u64(h, u64(bm.Mask))
	h = hash_mix_u64(h, u64(hash_color_u32(bm.Color)))
	return h
}

shader_register_pipeline_hash :: proc(shader: ^Shader, hash: u64) {
	if shader == nil {
		return
	}
	for h in shader.PipelineHashes {
		if h == hash {
			return
		}
	}
	append(&shader.PipelineHashes, hash)
}

graphics_device_release_pipeline_hashes :: proc(graphics_device: ^GraphicsDevice, hashes: ^[dynamic]u64) {
	if graphics_device == nil || graphics_device.Device == nil || hashes == nil {
		return
	}
	if graphics_device.PipelineCache != nil {
		for i := 0; i < len(hashes^); i += 1 {
			h := (hashes^)[i]
			if pipeline, ok := graphics_device.PipelineCache[h]; ok {
				if pipeline != nil {
					SDL.ReleaseGPUGraphicsPipeline(graphics_device.Device, pipeline)
				}
				graphics_device.PipelineCache[h] = nil
			}
		}
	}
	delete(hashes^)
	hashes^ = nil
}

graphics_device_dispose_caches :: proc(graphics_device: ^GraphicsDevice) {
	if graphics_device == nil || graphics_device.Device == nil {
		return
	}
	if graphics_device.PipelineCache != nil {
		for _, pipeline in graphics_device.PipelineCache {
			if pipeline != nil {
				SDL.ReleaseGPUGraphicsPipeline(graphics_device.Device, pipeline)
			}
		}
		delete(graphics_device.PipelineCache)
		graphics_device.PipelineCache = nil
	}
	if graphics_device.SamplerCache != nil {
		for _, sampler in graphics_device.SamplerCache {
			if sampler != nil {
				SDL.ReleaseGPUSampler(graphics_device.Device, sampler)
			}
		}
		delete(graphics_device.SamplerCache)
		graphics_device.SamplerCache = nil
	}
}

create_pipeline_for_draw_command :: proc(graphics_device: ^GraphicsDevice, command: ^DrawCommand) -> ^SDL.GPUGraphicsPipeline {
	if graphics_device == nil || graphics_device.Device == nil || command == nil || command.Material == nil || command.Material.Vertex.Shader == nil || command.Material.Fragment.Shader == nil {
		return nil
	}
	target := resolve_drawable_target(graphics_device, command.Target)
	if graphics_device.PipelineCache == nil {
		graphics_device.PipelineCache = make(map[u64]^SDL.GPUGraphicsPipeline)
	}
	if len(command.VertexBuffers) <= 0 {
		return nil
	}
	vertex_buffer_count := len(command.VertexBuffers)
	total_attributes := 0
	for i := 0; i < vertex_buffer_count; i += 1 {
		vb := command.VertexBuffers[i].Buffer
		if vb == nil || vb.Stride <= 0 {
			return nil
		}
		total_attributes += len(vb.Format.Elements)
	}
	if total_attributes <= 0 {
		return nil
	}
	vb_desc := make([]SDL.GPUVertexBufferDescription, vertex_buffer_count, context.temp_allocator)
	attrs := make([]SDL.GPUVertexAttribute, total_attributes, context.temp_allocator)
	attr_index := 0
	for i := 0; i < vertex_buffer_count; i += 1 {
		vb := command.VertexBuffers[i].Buffer
		vb_desc[i] = SDL.GPUVertexBufferDescription{
			slot = u32(i),
			pitch = u32(vb.Stride),
			input_rate = .VERTEX,
			instance_step_rate = 0,
		}
		if command.VertexBuffers[i].InstanceInputRate {
			vb_desc[i].input_rate = .INSTANCE
		}
		offset := 0
		for element in vb.Format.Elements {
			attrs[attr_index] = SDL.GPUVertexAttribute{
				location = u32(element.Index),
				buffer_slot = u32(i),
				format = vertex_type_to_sdl(element.Type, element.Normalized),
				offset = u32(offset),
			}
			offset += vertex_type_size_in_bytes(element.Type)
			attr_index += 1
		}
	}
	vertex_input := SDL.GPUVertexInputState{
		vertex_buffer_descriptions = &vb_desc[0],
		num_vertex_buffers = u32(len(vb_desc)),
		vertex_attributes = &attrs[0],
		num_vertex_attributes = u32(len(attrs)),
	}

	blend_state := SDL.GPUColorTargetBlendState{
		src_color_blendfactor = blend_factor_to_sdl(command.BlendMode.ColorSource),
		dst_color_blendfactor = blend_factor_to_sdl(command.BlendMode.ColorDestination),
		color_blend_op = blend_op_to_sdl(command.BlendMode.ColorOperation),
		src_alpha_blendfactor = blend_factor_to_sdl(command.BlendMode.AlphaSource),
		dst_alpha_blendfactor = blend_factor_to_sdl(command.BlendMode.AlphaDestination),
		alpha_blend_op = blend_op_to_sdl(command.BlendMode.AlphaOperation),
		color_write_mask = blend_mask_to_sdl(command.BlendMode.Mask),
		enable_blend = true,
		enable_color_write_mask = true,
	}
	color_target_desc := [8]SDL.GPUColorTargetDescription{}
	color_target_count := 0
	depth_stencil_format := SDL.GPUTextureFormat.INVALID
	sample_count := SDL.GPUSampleCount._1
	target_ptr, _ := drawable_target_backing_target(graphics_device, target)
	if target_ptr == nil {
		return nil
	}
	for i := 0; i < len(target_ptr.Attachments); i += 1 {
		attachment := target_ptr.Attachments[i]
		attachment_format := texture_format_to_sdl(attachment.Format)
		attachment_sample_count := sample_count_to_sdl(attachment.SampleCount)
		if attachment_sample_count > sample_count {
			sample_count = attachment_sample_count
		}
		if texture_format_is_color_format(attachment.Format) {
			color_target_desc[color_target_count] = SDL.GPUColorTargetDescription{
				format = attachment_format,
				blend_state = blend_state,
			}
			color_target_count += 1
		} else {
			depth_stencil_format = attachment_format
		}
	}
	if color_target_count <= 0 {
		return nil
	}

	hash: u64 = 1469598103934665603
	hash = hash_mix_u64(hash, u64(uintptr(command.Material.Vertex.Shader.Resource)))
	hash = hash_mix_u64(hash, u64(uintptr(command.Material.Fragment.Shader.Resource)))
	hash = hash_blend_mode(hash, command.BlendMode)
	hash = hash_mix_u64(hash, u64(command.CullMode))
	hash = hash_mix_u64(hash, u64(command.FillMode))
	hash = hash_mix_u64(hash, u64(command.BackStencilState.FailOp))
	hash = hash_mix_u64(hash, u64(command.BackStencilState.PassOp))
	hash = hash_mix_u64(hash, u64(command.BackStencilState.DepthFailOp))
	hash = hash_mix_u64(hash, u64(command.BackStencilState.CompareOp))
	hash = hash_mix_u64(hash, u64(command.FrontStencilState.FailOp))
	hash = hash_mix_u64(hash, u64(command.FrontStencilState.PassOp))
	hash = hash_mix_u64(hash, u64(command.FrontStencilState.DepthFailOp))
	hash = hash_mix_u64(hash, u64(command.FrontStencilState.CompareOp))
	hash = hash_mix_u64(hash, u64(command.StencilCompareMask))
	hash = hash_mix_u64(hash, u64(command.StencilWriteMask))
	if command.StencilTestEnabled { hash = hash_mix_u64(hash, 1) } else { hash = hash_mix_u64(hash, 0) }
	hash = hash_mix_u64(hash, u64(command.DepthCompare))
	if command.DepthTestEnabled {
		hash = hash_mix_u64(hash, 1)
	} else {
		hash = hash_mix_u64(hash, 0)
	}
	if command.DepthWriteEnabled {
		hash = hash_mix_u64(hash, 1)
	} else {
		hash = hash_mix_u64(hash, 0)
	}
	hash = hash_mix_u64(hash, u64(color_target_count))
	for i := 0; i < color_target_count; i += 1 {
		hash = hash_mix_u64(hash, u64(color_target_desc[i].format))
	}
	hash = hash_mix_u64(hash, u64(depth_stencil_format))
	hash = hash_mix_u64(hash, u64(sample_count))
	if command.IndexBuffer != nil {
		hash = hash_mix_u64(hash, u64(command.IndexBuffer.Format))
	} else {
		hash = hash_mix_u64(hash, 0)
	}
	for i := 0; i < len(command.VertexBuffers); i += 1 {
		vb := command.VertexBuffers[i].Buffer
		hash = hash_mix_u64(hash, u64(vb.Stride))
		if command.VertexBuffers[i].InstanceInputRate {
			hash = hash_mix_u64(hash, 1)
		} else {
			hash = hash_mix_u64(hash, 0)
		}
		for element in vb.Format.Elements {
			hash = hash_mix_u64(hash, u64(element.Index))
			hash = hash_mix_u64(hash, u64(element.Type))
			if element.Normalized {
				hash = hash_mix_u64(hash, 1)
			} else {
				hash = hash_mix_u64(hash, 0)
			}
		}
	}

	if cached, ok := graphics_device.PipelineCache[hash]; ok && cached != nil {
		return cached
	}
	target_info := SDL.GPUGraphicsPipelineTargetInfo{
		color_target_descriptions = &color_target_desc[0],
		num_color_targets = u32(color_target_count),
		depth_stencil_format = depth_stencil_format,
		has_depth_stencil_target = depth_stencil_format != .INVALID,
	}

	depth_stencil := SDL.GPUDepthStencilState{
		compare_op = depth_compare_to_sdl(command.DepthCompare),
		back_stencil_state = stencil_state_to_sdl(command.BackStencilState),
		front_stencil_state = stencil_state_to_sdl(command.FrontStencilState),
		compare_mask = command.StencilCompareMask,
		write_mask = command.StencilWriteMask,
		enable_depth_test = command.DepthTestEnabled,
		enable_depth_write = command.DepthWriteEnabled,
		enable_stencil_test = command.StencilTestEnabled,
	}
	rasterizer := SDL.GPURasterizerState{
		fill_mode = fill_mode_to_sdl(command.FillMode),
		cull_mode = cull_mode_to_sdl(command.CullMode),
		front_face = .COUNTER_CLOCKWISE,
		depth_bias_constant_factor = 0,
		depth_bias_clamp = 0,
		depth_bias_slope_factor = 0,
		enable_depth_bias = false,
		enable_depth_clip = true,
	}
	multisample := SDL.GPUMultisampleState{
		sample_count = sample_count,
		sample_mask = 0,
		enable_mask = false,
		enable_alpha_to_coverage = false,
	}

	pipeline_info := SDL.GPUGraphicsPipelineCreateInfo{
		vertex_shader = command.Material.Vertex.Shader.Resource,
		fragment_shader = command.Material.Fragment.Shader.Resource,
		vertex_input_state = vertex_input,
		primitive_type = .TRIANGLELIST,
		rasterizer_state = rasterizer,
		multisample_state = multisample,
		depth_stencil_state = depth_stencil,
		target_info = target_info,
		props = 0,
	}
	pipeline := SDL.CreateGPUGraphicsPipeline(graphics_device.Device, pipeline_info)
	if pipeline != nil {
		graphics_device.PipelineCache[hash] = pipeline
		shader_register_pipeline_hash(command.Material.Vertex.Shader, hash)
		shader_register_pipeline_hash(command.Material.Fragment.Shader, hash)
	}
	return pipeline
}

graphics_device_draw :: proc(graphics_device: ^GraphicsDevice, command: ^DrawCommand) {
	if graphics_device == nil || command == nil || command.Material == nil {
		return
	}
	if !graphics_device.InFrame || graphics_device.CommandBuffer == nil {
		return
	}
	target := resolve_drawable_target(graphics_device, command.Target)
	if target.GraphicsDevice != nil && target.GraphicsDevice != graphics_device {
		return
	}
	if len(command.VertexBuffers) <= 0 || command.VertexBuffers[0].Buffer == nil || command.VertexBuffers[0].Buffer.Base.Resource == nil {
		return
	}
	if command.Material.Vertex.Shader == nil || command.Material.Fragment.Shader == nil {
		return
	}
	if !begin_render_pass(graphics_device, target) || graphics_device.RenderPass == nil {
		return
	}

	pipeline := create_pipeline_for_draw_command(graphics_device, command)
	if pipeline == nil {
		return
	}
	if graphics_device.RenderPassPipeline != pipeline {
		SDL.BindGPUGraphicsPipeline(graphics_device.RenderPass, pipeline)
		graphics_device.RenderPassPipeline = pipeline
	}
	SDL.SetGPUStencilReference(graphics_device.RenderPass, command.StencilReferenceValue)

	viewport := RectInt{0, 0, graphics_device.RenderPassTargetSize.X, graphics_device.RenderPassTargetSize.Y}
	if command.HasViewport {
		viewport = command.Viewport
	}
	if !graphics_device.HasRenderPassViewport || graphics_device.RenderPassViewport != viewport {
		SDL.SetGPUViewport(graphics_device.RenderPass, SDL.GPUViewport{
			x = f32(viewport.X),
			y = f32(viewport.Y),
			w = f32(viewport.Width),
			h = f32(viewport.Height),
			min_depth = 0,
			max_depth = 1,
		})
		graphics_device.RenderPassViewport = viewport
		graphics_device.HasRenderPassViewport = true
	}

	scissor := viewport
	if command.HasScissor {
		scissor = command.Scissor
	}
	if !graphics_device.HasRenderPassScissor || graphics_device.RenderPassScissor != scissor {
		SDL.SetGPUScissor(graphics_device.RenderPass, SDL.Rect{
			x = i32(scissor.X),
			y = i32(scissor.Y),
			w = i32(scissor.Width),
			h = i32(scissor.Height),
		})
		graphics_device.RenderPassScissor = scissor
		graphics_device.HasRenderPassScissor = true
	}

	vertex_info := command.Material.Vertex.Shader.CreateInfo
	fragment_info := command.Material.Fragment.Shader.CreateInfo

	if vertex_info.SamplerCount > 0 {
		vb := make([]SDL.GPUTextureSamplerBinding, vertex_info.SamplerCount, context.temp_allocator)
		for i := 0; i < len(vb); i += 1 {
			texture := graphics_device.DebugTexture
			sampler := graphics_device.DebugSampler
			if command.Material.Vertex.Samplers[i].Texture != nil {
				texture = texture_sample_resource(command.Material.Vertex.Samplers[i].Texture)
				cached := create_sampler_from_texture_sampler(graphics_device, command.Material.Vertex.Samplers[i].Sampler)
				if cached != nil {
					sampler = cached
				}
			}
			vb[i] = SDL.GPUTextureSamplerBinding{texture = texture, sampler = sampler}
		}
		SDL.BindGPUVertexSamplers(graphics_device.RenderPass, 0, &vb[0], u32(len(vb)))
	}

	if fragment_info.SamplerCount > 0 {
		fb := make([]SDL.GPUTextureSamplerBinding, fragment_info.SamplerCount, context.temp_allocator)
		for i := 0; i < len(fb); i += 1 {
			texture := graphics_device.DebugTexture
			sampler := graphics_device.DebugSampler
			if command.Material.Fragment.Samplers[i].Texture != nil {
				texture = texture_sample_resource(command.Material.Fragment.Samplers[i].Texture)
				cached := create_sampler_from_texture_sampler(graphics_device, command.Material.Fragment.Samplers[i].Sampler)
				if cached != nil {
					sampler = cached
				}
			}
			fb[i] = SDL.GPUTextureSamplerBinding{texture = texture, sampler = sampler}
		}
		SDL.BindGPUFragmentSamplers(graphics_device.RenderPass, 0, &fb[0], u32(len(fb)))
	}

	for i := 0; i < vertex_info.UniformBufferCount; i += 1 {
		uniform := material_stage_get_uniform_buffer(&command.Material.Vertex, i)
		if len(uniform) > 0 {
			SDL.PushGPUVertexUniformData(graphics_device.CommandBuffer, u32(i), raw_data(uniform), u32(len(uniform)))
		} else if i == 0 {
			SDL.PushGPUVertexUniformData(graphics_device.CommandBuffer, u32(i), raw_data(identity_matrix_4x4[:]), 64)
		}
	}

	for i := 0; i < fragment_info.UniformBufferCount; i += 1 {
		uniform := material_stage_get_uniform_buffer(&command.Material.Fragment, i)
		if len(uniform) > 0 {
			SDL.PushGPUFragmentUniformData(graphics_device.CommandBuffer, u32(i), raw_data(uniform), u32(len(uniform)))
		}
	}

	buffer_bindings := make([]SDL.GPUBufferBinding, len(command.VertexBuffers), context.temp_allocator)
	for i := 0; i < len(command.VertexBuffers); i += 1 {
		buffer_bindings[i] = SDL.GPUBufferBinding{
			buffer = command.VertexBuffers[i].Buffer.Base.Resource,
			offset = 0,
		}
	}
	SDL.BindGPUVertexBuffers(graphics_device.RenderPass, 0, raw_data(buffer_bindings), u32(len(buffer_bindings)))

	if vertex_info.StorageBufferCount > 0 && len(command.VertexStorageBuffers) > 0 {
		storage_count := Min(len(command.VertexStorageBuffers), vertex_info.StorageBufferCount)
		buffers := make([]^SDL.GPUBuffer, storage_count, context.temp_allocator)
		for i := 0; i < storage_count; i += 1 {
			sb := command.VertexStorageBuffers[i]
			if sb == nil || sb.Base.Resource == nil {
				return
			}
			buffers[i] = sb.Base.Resource
		}
		SDL.BindGPUVertexStorageBuffers(graphics_device.RenderPass, 0, raw_data(buffers), u32(len(buffers)))
	}

	if fragment_info.StorageBufferCount > 0 && len(command.FragmentStorageBuffers) > 0 {
		storage_count := Min(len(command.FragmentStorageBuffers), fragment_info.StorageBufferCount)
		buffers := make([]^SDL.GPUBuffer, storage_count, context.temp_allocator)
		for i := 0; i < storage_count; i += 1 {
			sb := command.FragmentStorageBuffers[i]
			if sb == nil || sb.Base.Resource == nil {
				return
			}
			buffers[i] = sb.Base.Resource
		}
		SDL.BindGPUFragmentStorageBuffers(graphics_device.RenderPass, 0, raw_data(buffers), u32(len(buffers)))
	}

	if command.IndexBuffer != nil && command.IndexBuffer.Base.Resource != nil && command.IndexCount > 0 {
		index_binding := SDL.GPUBufferBinding{
			buffer = command.IndexBuffer.Base.Resource,
			offset = u32(command.IndexOffset * command.IndexBuffer.Base.ElementSizeInBytes),
		}
		SDL.BindGPUIndexBuffer(graphics_device.RenderPass, index_binding, index_format_to_sdl(command.IndexBuffer.Format))
		graphics_device.RenderPassIndexBuffer = command.IndexBuffer.Base.Resource
		SDL.DrawGPUIndexedPrimitives(graphics_device.RenderPass, u32(command.IndexCount), u32(Max(command.InstanceCount, 1)), 0, i32(command.VertexOffset), 0)
	} else if command.VertexCount > 0 {
		SDL.DrawGPUPrimitives(graphics_device.RenderPass, u32(command.VertexCount), u32(Max(command.InstanceCount, 1)), u32(command.VertexOffset), 0)
	}
}

GraphicsDeviceDraw :: graphics_device_draw

graphics_device_is_texture_format_supported :: proc(device:^GraphicsDevice, format:TextureFormat)->bool { return device != nil && device.Device != nil && SDL.GPUTextureSupportsSampleCount(device.Device, texture_format_to_sdl(format), ._1) }
graphics_device_is_texture_multisample_supported :: proc(device:^GraphicsDevice, format:TextureFormat, samples:SampleCount)->bool { return device != nil && device.Device != nil && SDL.GPUTextureSupportsSampleCount(device.Device, texture_format_to_sdl(format), sample_count_to_sdl(samples)) }
graphics_device_resource_handle :: proc(device:^GraphicsDevice)->rawptr { if device==nil{return nil};return rawptr(device.Device) }
graphics_device_origin_bottom_left :: proc(device:^GraphicsDevice)->bool { _=device; return false }
GraphicsDeviceIsTextureFormatSupported :: graphics_device_is_texture_format_supported
GraphicsDeviceIsTextureMultiSampleSupported :: graphics_device_is_texture_multisample_supported
GraphicsDeviceResourceHandle :: graphics_device_resource_handle
GraphicsDeviceOriginBottomLeft :: graphics_device_origin_bottom_left

graphics_device_clear_mask :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget, colors: []Color, depth: f32, stencil: int, mask: ClearMask) {
	if graphics_device == nil || !graphics_device.InFrame {
		return
	}
	mask_bits := u8(mask)
	if mask_bits == 0 {
		return
	}
	clear_colors: []Color = nil
	if (mask_bits & u8(ClearMask.Color)) != 0 {
		clear_colors = colors
	}
	clear_depth := (mask_bits & u8(ClearMask.Depth)) != 0
	clear_stencil := (mask_bits & u8(ClearMask.Stencil)) != 0
	_ = begin_render_pass_ex(graphics_device, target, clear_colors, clear_depth, depth, clear_stencil, stencil)
}

graphics_device_clear_color :: proc(graphics_device: ^GraphicsDevice, target: DrawableTarget, color: Color) {
	colors := [1]Color{color}
	graphics_device_clear_mask(graphics_device, target, colors[:], 0, 0, .Color)
}

GraphicsDeviceClear :: proc{graphics_device_clear_color, graphics_device_clear_mask}

init_default_batch_material :: proc(material: ^Material, vertex_shader: ^Shader, fragment_shader: ^Shader, graphics_device: ^GraphicsDevice) {
	vertex_code: []u8 = nil
	fragment_code: []u8 = nil
	#partial switch graphics_device.Driver {
	case .Private, .Vulkan:
		vertex_code = batcher_vertex_spv
		fragment_code = batcher_fragment_spv
	case .D3D12:
		vertex_code = batcher_vertex_dxil
		fragment_code = batcher_fragment_dxil
	case .Metal:
		vertex_code = batcher_vertex_msl
		fragment_code = batcher_fragment_msl
	case .None:
	}

	vertex_info := ShaderCreateInfo{
		Stage = .Vertex,
		Code = vertex_code,
		SamplerCount = 0,
		UniformBufferCount = 1,
		StorageBufferCount = 0,
		EntryPoint = "vertex_main",
	}
	fragment_info := ShaderCreateInfo{
		Stage = .Fragment,
		Code = fragment_code,
		SamplerCount = 1,
		UniformBufferCount = 0,
		StorageBufferCount = 0,
		EntryPoint = "fragment_main",
	}

	shader_init(vertex_shader, graphics_device, vertex_info, "BatcherVertex")
	shader_init(fragment_shader, graphics_device, fragment_info, "BatcherFragment")
	material_init_with_shaders(material, vertex_shader, fragment_shader)
}

InitDefaultBatchMaterial :: init_default_batch_material

init_default_textured_material :: proc(material: ^Material, vertex_shader: ^Shader, fragment_shader: ^Shader, graphics_device: ^GraphicsDevice) {
	vertex_code: []u8 = nil
	fragment_code: []u8 = nil
	#partial switch graphics_device.Driver {
	case .Private, .Vulkan: vertex_code = textured_vertex_spv; fragment_code = textured_fragment_spv
	case .D3D12: vertex_code = textured_vertex_dxil; fragment_code = textured_fragment_dxil
	case .Metal: vertex_code = textured_vertex_msl; fragment_code = textured_fragment_msl
	case .None:
	}
	shader_init(vertex_shader, graphics_device, ShaderCreateInfo{Stage=.Vertex, Code=vertex_code, SamplerCount=0, UniformBufferCount=1, StorageBufferCount=0, EntryPoint="vertex_main"}, "TexturedVertex")
	shader_init(fragment_shader, graphics_device, ShaderCreateInfo{Stage=.Fragment, Code=fragment_code, SamplerCount=1, UniformBufferCount=0, StorageBufferCount=0, EntryPoint="fragment_main"}, "TexturedFragment")
	material_init_with_shaders(material, vertex_shader, fragment_shader)
}

init_default_msdf_material :: proc(material: ^Material, vertex_shader: ^Shader, fragment_shader: ^Shader, graphics_device: ^GraphicsDevice) {
	vertex_code: []u8 = nil
	fragment_code: []u8 = nil
	#partial switch graphics_device.Driver {
	case .Private, .Vulkan: vertex_code = msdf_vertex_spv; fragment_code = msdf_fragment_spv
	case .D3D12: vertex_code = msdf_vertex_dxil; fragment_code = msdf_fragment_dxil
	case .Metal: vertex_code = msdf_vertex_msl; fragment_code = msdf_fragment_msl
	case .None:
	}
	shader_init(vertex_shader, graphics_device, ShaderCreateInfo{Stage=.Vertex, Code=vertex_code, SamplerCount=0, UniformBufferCount=1, StorageBufferCount=0, EntryPoint="vertex_main"}, "MsdfVertex")
	shader_init(fragment_shader, graphics_device, ShaderCreateInfo{Stage=.Fragment, Code=fragment_code, SamplerCount=1, UniformBufferCount=1, StorageBufferCount=0, EntryPoint="fragment_main"}, "MsdfFragment")
	material_init_with_shaders(material, vertex_shader, fragment_shader)
}

InitDefaultTexturedMaterial :: init_default_textured_material
InitDefaultMsdfMaterial :: init_default_msdf_material
