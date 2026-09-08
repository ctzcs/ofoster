package foster_framework

import "core:mem"
import SDL "vendor:sdl3"

GraphicResource :: enum {
	None,
	Texture,
	Shader,
	Buffer,
	Sampler,
	Pipeline,
}

graphics_device_destroy_resource :: proc(graphics_device: ^GraphicsDevice, kind: GraphicResource, resource: rawptr) {
	if graphics_device == nil || graphics_device.Device == nil || resource == nil {
		return
	}

	device := graphics_device.Device

	#partial switch kind {
	case .Texture:
		SDL.ReleaseGPUTexture(device, cast(^SDL.GPUTexture)resource)
	case .Shader:
		SDL.ReleaseGPUShader(device, cast(^SDL.GPUShader)resource)
	case .Buffer:
		SDL.ReleaseGPUBuffer(device, cast(^SDL.GPUBuffer)resource)
	case .Sampler:
		SDL.ReleaseGPUSampler(device, cast(^SDL.GPUSampler)resource)
	case .Pipeline:
		SDL.ReleaseGPUGraphicsPipeline(device, cast(^SDL.GPUGraphicsPipeline)resource)
	case .None:
	}
}

GraphicsDeviceDestroyResource :: graphics_device_destroy_resource

graphics_device_upload_to_buffer :: proc(graphics_device: ^GraphicsDevice, buffer: ^SDL.GPUBuffer, data: rawptr, data_size: u32, dest_offset: u32) {
	if graphics_device == nil || graphics_device.Device == nil || buffer == nil || data == nil || data_size == 0 {
		return
	}

	device := graphics_device.Device

	// 帧内快速路径: 把上传记录进本帧命令缓冲的暂存缓冲分区 (免每帧创建/销毁与 GPU 空等)
	if graphics_device.CommandBuffer != nil && graphics_device.RenderPass == nil {
		cursor := graphics_device.UploadStagingCursor
		required := data_size
		need_total := cursor + required
		if graphics_device.UploadStaging == nil || graphics_device.UploadStagingSize < need_total {
			if graphics_device.UploadStaging != nil {
				SDL.ReleaseGPUTransferBuffer(device, graphics_device.UploadStaging)
				graphics_device.UploadStaging = nil
			}
			next := graphics_device.UploadStagingSize
			if next <= 0 do next = 1 << 20
			for next < need_total do next *= 2
			transfer_info := SDL.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = next, props = 0}
			transfer := SDL.CreateGPUTransferBuffer(device, transfer_info)
			if transfer == nil {
				panic(create_error_from_sdl("SDL_CreateGPUTransferBuffer"))
			}
			graphics_device.UploadStaging = transfer
			graphics_device.UploadStagingSize = next
		}
		transfer := graphics_device.UploadStaging
		mapped := SDL.MapGPUTransferBuffer(device, transfer, false)
		if mapped == nil {
			panic(create_error_from_sdl("SDL_MapGPUTransferBuffer"))
		}
		dst := ([^]byte)(mapped)
		mem.copy(raw_data(dst[cursor:int(cursor)+int(required)]), data, int(data_size))
		SDL.UnmapGPUTransferBuffer(device, transfer)
		copy_pass := SDL.BeginGPUCopyPass(graphics_device.CommandBuffer)
		if copy_pass == nil {
			return
		}
		upload_src := SDL.GPUTransferBufferLocation{transfer_buffer = transfer, offset = cursor}
		upload_dst := SDL.GPUBufferRegion{buffer = buffer, offset = dest_offset, size = data_size}
		SDL.UploadToGPUBuffer(copy_pass, upload_src, upload_dst, false)
		SDL.EndGPUCopyPass(copy_pass)
		graphics_device.UploadStagingCursor = cursor + required
		return
	}

	// 帧外回退路径: 独立命令缓冲 + 上传后等待完成
	transfer_size := u32(256) + data_size
	transfer_info := SDL.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = transfer_size, props = 0}
	transfer := SDL.CreateGPUTransferBuffer(device, transfer_info)
	if transfer == nil {
		panic(create_error_from_sdl("SDL_CreateGPUTransferBuffer"))
	}
	defer SDL.ReleaseGPUTransferBuffer(device, transfer)

	mapped := SDL.MapGPUTransferBuffer(device, transfer, false)
	if mapped == nil {
		panic(create_error_from_sdl("SDL_MapGPUTransferBuffer"))
	}
	mem.copy(mapped, data, int(data_size))
	SDL.UnmapGPUTransferBuffer(device, transfer)

	command_buffer := SDL.AcquireGPUCommandBuffer(device)
	if command_buffer == nil {
		return
	}

	copy_pass := SDL.BeginGPUCopyPass(command_buffer)
	if copy_pass == nil {
		_ = SDL.CancelGPUCommandBuffer(command_buffer)
		return
	}

	upload_src := SDL.GPUTransferBufferLocation{transfer_buffer = transfer, offset = 0}
	upload_dst := SDL.GPUBufferRegion{buffer = buffer, offset = dest_offset, size = data_size}
	SDL.UploadToGPUBuffer(copy_pass, upload_src, upload_dst, false)

	SDL.EndGPUCopyPass(copy_pass)
	if !SDL.SubmitGPUCommandBuffer(command_buffer) {
		panic(create_error_from_sdl("SDL_SubmitGPUCommandBuffer"))
	}
	_ = SDL.WaitForGPUIdle(device)
}

GraphicsDeviceUploadToBuffer :: graphics_device_upload_to_buffer

Texture :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Name: string,
	Width: int,
	Height: int,
	Format: TextureFormat,
	SampleCount: SampleCount,
	IsTargetAttachment: bool,
	Resource: ^SDL.GPUTexture,
	ResolveResource: ^SDL.GPUTexture,
	Pixels: [dynamic]u8,
	Flags: TextureFlags,
	Disposed: bool,
}

texture_memory_size :: proc(tex: ^Texture) -> int {
	if tex == nil {
		return 0
	}
	return tex.Width * tex.Height * texture_format_size(tex.Format)
}

TextureMemorySize :: texture_memory_size

texture_init_ex :: proc(tex: ^Texture, graphics_device: ^GraphicsDevice, width, height: int, format: TextureFormat, sample_count: SampleCount, usage: SDL.GPUTextureUsageFlags, is_target_attachment: bool, name: string = "") {
	if width <= 0 || height <= 0 {
		panic("Texture must have a size larger than 0")
	}
	if graphics_device == nil || graphics_device.Device == nil {
		panic("GraphicsDevice is nil")
	}

	sdl_format := texture_format_to_sdl(format)
	info := SDL.GPUTextureCreateInfo{
		type = .D2,
		format = sdl_format,
		usage = usage,
		width = u32(width),
		height = u32(height),
		layer_count_or_depth = 1,
		num_levels = 1,
		sample_count = sample_count_to_sdl(sample_count),
		props = 0,
	}

	resource := SDL.CreateGPUTexture(graphics_device.Device, info)
	if resource == nil {
		panic(create_error_from_sdl("SDL_CreateGPUTexture"))
	}

	resolve_resource: ^SDL.GPUTexture = nil
	if is_target_attachment && sample_count != .One && texture_format_is_color_format(format) {
		resolve_info := SDL.GPUTextureCreateInfo{
			type = .D2,
			format = sdl_format,
			usage = SDL.GPUTextureUsageFlags{.SAMPLER, .COLOR_TARGET},
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			props = 0,
		}
		resolve_resource = SDL.CreateGPUTexture(graphics_device.Device, resolve_info)
		if resolve_resource == nil {
			SDL.ReleaseGPUTexture(graphics_device.Device, resource)
			panic(create_error_from_sdl("SDL_CreateGPUTexture", "resolve"))
		}
	}

	tex.GraphicsDevice = graphics_device
	tex.Name = name
	tex.Width = width
	tex.Height = height
	tex.Format = format
	tex.SampleCount = sample_count
	tex.IsTargetAttachment = is_target_attachment
	tex.Resource = resource
	tex.ResolveResource = resolve_resource
	tex.Flags = TextureFlags{}
	delete(tex.Pixels)
	tex.Pixels = nil
	resize(&tex.Pixels, width * height * texture_format_size(format))
	tex.Disposed = false
}

texture_init :: proc(tex: ^Texture, graphics_device: ^GraphicsDevice, width, height: int, format: TextureFormat = .Color, name: string = "") {
	texture_init_ex(tex, graphics_device, width, height, format, .One, SDL.GPUTextureUsageFlags{.SAMPLER}, false, name)
}

texture_init_flags :: proc(tex: ^Texture, graphics_device: ^GraphicsDevice, width, height: int, format: TextureFormat, flags: TextureFlags, name: string = "") {
	usage := SDL.GPUTextureUsageFlags{.SAMPLER}
	if .ComputeRead in flags { usage += {.COMPUTE_STORAGE_READ} }
	if .ComputeWrite in flags { usage += {.COMPUTE_STORAGE_WRITE} }
	texture_init_ex(tex, graphics_device, width, height, format, .One, usage, false, name)
	tex.Flags = flags
}

texture_dispose :: proc(tex: ^Texture) {
	if tex == nil || tex.Disposed {
		return
	}
	if tex.GraphicsDevice != nil && tex.GraphicsDevice.Device != nil && tex.Resource != nil && !tex.IsTargetAttachment {
		SDL.ReleaseGPUTexture(tex.GraphicsDevice.Device, tex.Resource)
	}
	if tex.GraphicsDevice != nil && tex.GraphicsDevice.Device != nil && tex.ResolveResource != nil {
		SDL.ReleaseGPUTexture(tex.GraphicsDevice.Device, tex.ResolveResource)
	}
	tex.Resource = nil
	tex.ResolveResource = nil
	delete(tex.Pixels)
	tex.Pixels = nil
	tex.Disposed = true
}

texture_sample_resource :: proc(tex: ^Texture) -> ^SDL.GPUTexture {
	if tex == nil {
		return nil
	}
	if tex.ResolveResource != nil {
		return tex.ResolveResource
	}
	return tex.Resource
}

// Data contains native texel bits, not converted RGBA8 colors: float formats
// use f16/f32 components, and R11G11B10_UFLOAT uses packed unsigned float bits.
texture_set_data :: proc(tex: ^Texture, data: rawptr, length: int) {
	if tex == nil || tex.Disposed || tex.GraphicsDevice == nil || tex.GraphicsDevice.Device == nil || tex.Resource == nil {
		panic("Resource is Disposed")
	}

	mem_size := texture_memory_size(tex)
	if length < mem_size {
		panic("Data Buffer is smaller than the Size of the Texture")
	}

	device := tex.GraphicsDevice.Device

	transfer_size := u32(256) + u32(mem_size)
	transfer_info := SDL.GPUTransferBufferCreateInfo{
		usage = .UPLOAD,
		size = transfer_size,
		props = 0,
	}
	transfer := SDL.CreateGPUTransferBuffer(device, transfer_info)
	if transfer == nil {
		panic(create_error_from_sdl("SDL_CreateGPUTransferBuffer"))
	}
	defer SDL.ReleaseGPUTransferBuffer(device, transfer)

	mapped := SDL.MapGPUTransferBuffer(device, transfer, false)
	if mapped == nil {
		panic(create_error_from_sdl("SDL_MapGPUTransferBuffer"))
	}
	mem.copy(mapped, data, mem_size)
	if mem_size > 0 { mem.copy(raw_data(tex.Pixels[:]), data, mem_size) }
	SDL.UnmapGPUTransferBuffer(device, transfer)

	command_buffer := SDL.AcquireGPUCommandBuffer(device)
	if command_buffer == nil {
		return
	}

	copy_pass := SDL.BeginGPUCopyPass(command_buffer)
	if copy_pass == nil {
		_ = SDL.CancelGPUCommandBuffer(command_buffer)
		return
	}

	src := SDL.GPUTextureTransferInfo{transfer_buffer = transfer, offset = 0, pixels_per_row = u32(tex.Width), rows_per_layer = u32(tex.Height)}
	dst := SDL.GPUTextureRegion{texture = tex.Resource, mip_level = 0, layer = 0, x = 0, y = 0, z = 0, w = u32(tex.Width), h = u32(tex.Height), d = 1}
	SDL.UploadToGPUTexture(copy_pass, src, dst, false)

	SDL.EndGPUCopyPass(copy_pass)
	if !SDL.SubmitGPUCommandBuffer(command_buffer) {
		panic(create_error_from_sdl("SDL_SubmitGPUCommandBuffer"))
	}
	_ = SDL.WaitForGPUIdle(device)
}

TextureInit :: texture_init
TextureInitEx :: texture_init_ex
TextureInitFlags :: texture_init_flags
TextureDispose :: texture_dispose
TextureSetData :: texture_set_data
TextureSampleResource :: texture_sample_resource

// Returns native texel bits in the texture's format; the caller decodes them.
texture_download_data :: proc(tex: ^Texture, allocator := context.allocator) -> []byte {
	if tex == nil || tex.Disposed || tex.GraphicsDevice == nil || tex.GraphicsDevice.Device == nil || tex.Resource == nil { return nil }
	mem_size := texture_memory_size(tex)
	if mem_size <= 0 { return nil }
	transfer := SDL.CreateGPUTransferBuffer(tex.GraphicsDevice.Device, SDL.GPUTransferBufferCreateInfo{usage = .DOWNLOAD, size = u32(mem_size), props = 0})
	if transfer == nil { return nil }
	defer SDL.ReleaseGPUTransferBuffer(tex.GraphicsDevice.Device, transfer)
	command_buffer := SDL.AcquireGPUCommandBuffer(tex.GraphicsDevice.Device)
	if command_buffer == nil { return nil }
	copy_pass := SDL.BeginGPUCopyPass(command_buffer)
	if copy_pass == nil { _ = SDL.CancelGPUCommandBuffer(command_buffer); return nil }
	SDL.DownloadFromGPUTexture(copy_pass,
		SDL.GPUTextureRegion{texture = texture_sample_resource(tex), mip_level = 0, layer = 0, x = 0, y = 0, z = 0, w = u32(tex.Width), h = u32(tex.Height), d = 1},
		SDL.GPUTextureTransferInfo{transfer_buffer = transfer, offset = 0, pixels_per_row = u32(tex.Width), rows_per_layer = u32(tex.Height)})
	SDL.EndGPUCopyPass(copy_pass)
	if !SDL.SubmitGPUCommandBuffer(command_buffer) { return nil }
	if !SDL.WaitForGPUIdle(tex.GraphicsDevice.Device) { return nil }
	// Read the completed download, preserving the transfer buffer's contents.
	mapped := SDL.MapGPUTransferBuffer(tex.GraphicsDevice.Device, transfer, false)
	if mapped == nil { return nil }
	result := make([]byte, mem_size, allocator)
	mem.copy(raw_data(result), mapped, mem_size)
	SDL.UnmapGPUTransferBuffer(tex.GraphicsDevice.Device, transfer)
	return result
}

texture_get_data :: proc(tex: ^Texture, allocator := context.allocator) -> []byte {
	if tex == nil || tex.Disposed { return nil }
	if tex.GraphicsDevice != nil && tex.GraphicsDevice.Device != nil && tex.Resource != nil {
		if data := texture_download_data(tex, allocator); data != nil { return data }
	}
	result := make([]byte, len(tex.Pixels), allocator)
	copy(result, tex.Pixels[:])
	return result
}

texture_set_data_region :: proc(tex: ^Texture, data: []u8, x, y, width, height: int) {
	if tex == nil || tex.Disposed || x < 0 || y < 0 || width <= 0 || height <= 0 { return }
	if x + width > tex.Width || y + height > tex.Height { return }
	bpp := texture_format_size(tex.Format)
	if len(data) < width * height * bpp { return }
	for row := 0; row < height; row += 1 {
		src := row * width * bpp
		dst := ((y + row) * tex.Width + x) * bpp
		mem.copy(raw_data(tex.Pixels[dst:]), raw_data(data[src:]), width * bpp)
	}
	if len(tex.Pixels) > 0 { texture_set_data(tex, raw_data(tex.Pixels[:]), len(tex.Pixels)) }
}

texture_set_data_region_rect :: proc(tex: ^Texture, data: []u8, region: RectInt) {
	texture_set_data_region(tex, data, region.X, region.Y, region.Width, region.Height)
}

texture_clone :: proc(tex: ^Texture, name: string = "") -> Texture {
	result: Texture
	if tex == nil || tex.Disposed || tex.GraphicsDevice == nil { return result }
	usage := SDL.GPUTextureUsageFlags{.SAMPLER}
	if .ComputeRead in tex.Flags { usage += {.COMPUTE_STORAGE_READ} }
	if .ComputeWrite in tex.Flags { usage += {.COMPUTE_STORAGE_WRITE} }
	texture_init_ex(&result, tex.GraphicsDevice, tex.Width, tex.Height, tex.Format, tex.SampleCount,
		usage, false, name)
	result.Flags = tex.Flags
	if len(tex.Pixels) > 0 { texture_set_data(&result, raw_data(tex.Pixels[:]), len(tex.Pixels)) }
	return result
}

texture_blit :: proc(source, destination: ^Texture, source_rect, destination_rect: RectInt) {
	if source == nil || destination == nil || source.Disposed || destination.Disposed { return }
	bpp := texture_format_size(source.Format)
	if bpp != texture_format_size(destination.Format) || source_rect.Width <= 0 || source_rect.Height <= 0 { return }
	if source_rect.X < 0 || source_rect.Y < 0 || source_rect.X + source_rect.Width > source.Width || source_rect.Y + source_rect.Height > source.Height { return }
	if destination_rect.X < 0 || destination_rect.Y < 0 || destination_rect.Width != source_rect.Width || destination_rect.Height != source_rect.Height || destination_rect.X + destination_rect.Width > destination.Width || destination_rect.Y + destination_rect.Height > destination.Height { return }
	for row := 0; row < source_rect.Height; row += 1 {
		src := ((source_rect.Y + row) * source.Width + source_rect.X) * bpp
		dst := ((destination_rect.Y + row) * destination.Width + destination_rect.X) * bpp
		mem.copy(raw_data(destination.Pixels[dst:]), raw_data(source.Pixels[src:]), source_rect.Width * bpp)
	}
	if source.GraphicsDevice != nil && source.GraphicsDevice.Device != nil && source.Resource != nil && destination.Resource != nil {
		command_buffer := SDL.AcquireGPUCommandBuffer(source.GraphicsDevice.Device)
		if command_buffer != nil {
			SDL.BlitGPUTexture(command_buffer, SDL.GPUBlitInfo{
				source = SDL.GPUBlitRegion{texture = texture_sample_resource(source), x = u32(source_rect.X), y = u32(source_rect.Y), w = u32(source_rect.Width), h = u32(source_rect.Height)},
				destination = SDL.GPUBlitRegion{texture = texture_sample_resource(destination), x = u32(destination_rect.X), y = u32(destination_rect.Y), w = u32(destination_rect.Width), h = u32(destination_rect.Height)},
				load_op = .LOAD,
				flip_mode = .NONE,
				filter = .NEAREST,
				cycle = false,
			})
			_ = SDL.SubmitGPUCommandBuffer(command_buffer)
			_ = SDL.WaitForGPUIdle(source.GraphicsDevice.Device)
		}
	}
}

TextureGetData :: texture_get_data
TextureDownloadData :: texture_download_data
TextureSetDataRegion :: texture_set_data_region
TextureSetDataRegionRect :: texture_set_data_region_rect
TextureClone :: texture_clone
TextureBlit :: texture_blit

Shader :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Stage: ShaderStage,
	Name: string,
	CreateInfo: ShaderCreateInfo,
	Resource: ^SDL.GPUShader,
	ComputeResource: ^SDL.GPUComputePipeline,
	PipelineHashes: [dynamic]u64,
	Disposed: bool,
}

shader_init :: proc(shader: ^Shader, graphics_device: ^GraphicsDevice, create_info: ShaderCreateInfo, name: string = "") {
	if graphics_device == nil || graphics_device.Device == nil {
		panic("GraphicsDevice is nil")
	}
	if len(create_info.Code) == 0 {
		panic("Shader code is empty")
	}
	entrypoint := create_info.EntryPoint
	if entrypoint == "" {
		entrypoint = "main"
	}

	sdl_stage := shader_stage_to_sdl(create_info.Stage)

	format := SDL.GPU_SHADERFORMAT_INVALID
	#partial switch graphics_device.Driver {
	case .Private:
		format = {.PRIVATE}
	case .Vulkan:
		format = {.SPIRV}
	case .D3D12:
		format = {.DXIL}
	case .Metal:
		format = {.MSL}
	case .None:
	}

	info := SDL.GPUShaderCreateInfo{
		code_size = uint(len(create_info.Code)),
		code = &create_info.Code[0],
		entrypoint = to_cstring(entrypoint),
		format = format,
		stage = sdl_stage,
		num_samplers = u32(create_info.SamplerCount),
		num_storage_textures = 0,
		num_storage_buffers = u32(create_info.StorageBufferCount),
		num_uniform_buffers = u32(create_info.UniformBufferCount),
		props = 0,
	}
	if create_info.Stage == .Compute {
		compute_info := SDL.GPUComputePipelineCreateInfo{
			code_size = uint(len(create_info.Code)),
			code = &create_info.Code[0],
			entrypoint = to_cstring(entrypoint),
			format = format,
			num_samplers = u32(create_info.SamplerCount),
			num_readonly_storage_textures = 0,
			num_readonly_storage_buffers = u32(create_info.StorageBufferCount),
			num_readwrite_storage_textures = 0,
			num_readwrite_storage_buffers = 0,
			num_uniform_buffers = u32(create_info.UniformBufferCount),
			threadcount_x = u32(max(1, create_info.ThreadCountX)),
			threadcount_y = u32(max(1, create_info.ThreadCountY)),
			threadcount_z = u32(max(1, create_info.ThreadCountZ)),
			props = 0,
		}
		compute_resource := SDL.CreateGPUComputePipeline(graphics_device.Device, compute_info)
		if compute_resource == nil { panic(create_error_from_sdl("SDL_CreateGPUComputePipeline")) }
		shader.GraphicsDevice = graphics_device
		shader.Stage = create_info.Stage
		shader.Name = name
		shader.CreateInfo = create_info
		shader.Resource = nil
		shader.ComputeResource = compute_resource
		delete(shader.PipelineHashes)
		shader.PipelineHashes = nil
		shader.Disposed = false
		return
	}

	res := SDL.CreateGPUShader(graphics_device.Device, info)
	if res == nil {
		panic(create_error_from_sdl("SDL_CreateGPUShader"))
	}

	shader.GraphicsDevice = graphics_device
	shader.Stage = create_info.Stage
	shader.Name = name
	shader.CreateInfo = create_info
	shader.Resource = res
	shader.ComputeResource = nil
	delete(shader.PipelineHashes)
	shader.PipelineHashes = nil
	shader.Disposed = false
}

shader_recreate :: proc(shader: ^Shader, create_info: ShaderCreateInfo) {
	if shader == nil || shader.Disposed || shader.GraphicsDevice == nil || shader.GraphicsDevice.Disposed {
		panic("Cannot recreate a disposed Shader")
	}
	if create_info.Stage != shader.Stage {
		panic("Cannot recreate the Shader with a different stage")
	}

	if shader.Resource != nil {
		graphics_device_release_pipeline_hashes(shader.GraphicsDevice, &shader.PipelineHashes)
		SDL.ReleaseGPUShader(shader.GraphicsDevice.Device, shader.Resource)
		shader.Resource = nil
	}
	if shader.ComputeResource != nil {
		SDL.ReleaseGPUComputePipeline(shader.GraphicsDevice.Device, shader.ComputeResource)
		shader.ComputeResource = nil
	}
	shader_init(shader, shader.GraphicsDevice, create_info, shader.Name)
}

shader_dispose :: proc(shader: ^Shader) {
	if shader == nil || shader.Disposed {
		return
	}
	if shader.GraphicsDevice != nil && shader.GraphicsDevice.Device != nil && shader.Resource != nil {
		graphics_device_release_pipeline_hashes(shader.GraphicsDevice, &shader.PipelineHashes)
		SDL.ReleaseGPUShader(shader.GraphicsDevice.Device, shader.Resource)
	}
	if shader.GraphicsDevice != nil && shader.GraphicsDevice.Device != nil && shader.ComputeResource != nil {
		SDL.ReleaseGPUComputePipeline(shader.GraphicsDevice.Device, shader.ComputeResource)
	}
	shader.Resource = nil
	shader.ComputeResource = nil
	delete(shader.PipelineHashes)
	shader.PipelineHashes = nil
	shader.Disposed = true
}

ShaderInit :: shader_init
ShaderRecreate :: shader_recreate
ShaderDispose :: shader_dispose

BufferType :: enum {
	Vertex,
	Index,
	Storage,
}

GraphicsBuffer :: struct {
	GraphicsDevice: ^GraphicsDevice,
	Name: string,
	ElementSizeInBytes: int,
	Count: int,
	ByteSize: int,
	Type: BufferType,
	IndexFormat: IndexFormat,
	Resource: ^SDL.GPUBuffer,
	Disposed: bool,
}

graphics_buffer_init :: proc(buf: ^GraphicsBuffer, graphics_device: ^GraphicsDevice, element_size_in_bytes: int, buffer_type: BufferType, index_format: IndexFormat = .Sixteen, name: string = "") {
	if graphics_device == nil || graphics_device.Device == nil {
		panic("GraphicsDevice is nil")
	}
	if element_size_in_bytes <= 0 {
		panic("ElementSizeInBytes must be > 0")
	}

	usage: SDL.GPUBufferUsageFlags = {}
	#partial switch buffer_type {
	case .Vertex:
		usage = SDL.GPUBufferUsageFlags{.VERTEX}
	case .Index:
		usage = SDL.GPUBufferUsageFlags{.INDEX}
	case .Storage:
		usage = SDL.GPUBufferUsageFlags{.GRAPHICS_STORAGE_READ}
	}

	initial_size := element_size_in_bytes
	if initial_size < 256 {
		initial_size = 256
	}
	info := SDL.GPUBufferCreateInfo{
		usage = usage,
		size = u32(initial_size),
		props = 0,
	}

	res := SDL.CreateGPUBuffer(graphics_device.Device, info)
	if res == nil {
		panic(create_error_from_sdl("SDL_CreateGPUBuffer"))
	}

	buf.GraphicsDevice = graphics_device
	buf.Name = name
	buf.ElementSizeInBytes = element_size_in_bytes
	buf.Count = 0
	buf.ByteSize = initial_size
	buf.Type = buffer_type
	buf.IndexFormat = index_format
	buf.Resource = res
	buf.Disposed = false
}

graphics_buffer_ensure_size :: proc(buf: ^GraphicsBuffer, required_bytes: int) {
	if buf == nil || buf.Disposed || buf.GraphicsDevice == nil || buf.GraphicsDevice.Device == nil {
		return
	}
	if required_bytes <= buf.ByteSize {
		return
	}

	next_size := buf.ByteSize
	if next_size <= 0 {
		next_size = 256
	}
	for next_size < required_bytes {
		next_size *= 2
	}

	usage: SDL.GPUBufferUsageFlags = {}
	#partial switch buf.Type {
	case .Vertex:
		usage = SDL.GPUBufferUsageFlags{.VERTEX}
	case .Index:
		usage = SDL.GPUBufferUsageFlags{.INDEX}
	case .Storage:
		usage = SDL.GPUBufferUsageFlags{.GRAPHICS_STORAGE_READ}
	}

	if buf.Resource != nil {
		SDL.ReleaseGPUBuffer(buf.GraphicsDevice.Device, buf.Resource)
		buf.Resource = nil
	}

	info := SDL.GPUBufferCreateInfo{
		usage = usage,
		size = u32(next_size),
		props = 0,
	}
	buf.Resource = SDL.CreateGPUBuffer(buf.GraphicsDevice.Device, info)
	if buf.Resource == nil {
		panic(create_error_from_sdl("SDL_CreateGPUBuffer"))
	}
	buf.ByteSize = next_size
}

graphics_buffer_upload :: proc(buf: ^GraphicsBuffer, data: rawptr, element_count: int, element_offset: int = 0) {
	if buf == nil || buf.Disposed || buf.GraphicsDevice == nil || buf.GraphicsDevice.Device == nil || buf.Resource == nil {
		panic("Trying to upload to a disposed DrawBuffer")
	}

	if element_count <= 0 {
		return
	}

	next_count := element_offset + element_count
	if next_count > buf.Count {
		buf.Count = next_count
	}

	data_size := u32(element_count * buf.ElementSizeInBytes)
	dest_offset := u32(element_offset * buf.ElementSizeInBytes)
	required := int(dest_offset + data_size)
	graphics_buffer_ensure_size(buf, required)
	graphics_device_upload_to_buffer(buf.GraphicsDevice, buf.Resource, data, data_size, dest_offset)
}

graphics_buffer_clear :: proc(buf: ^GraphicsBuffer) {
	if buf != nil {
		buf.Count = 0
	}
}

graphics_buffer_dispose :: proc(buf: ^GraphicsBuffer) {
	if buf == nil || buf.Disposed {
		return
	}
	if buf.GraphicsDevice != nil && buf.GraphicsDevice.Device != nil && buf.Resource != nil {
		SDL.ReleaseGPUBuffer(buf.GraphicsDevice.Device, buf.Resource)
	}
	buf.Resource = nil
	buf.Disposed = true
}

GraphicsBufferInit :: graphics_buffer_init

graphics_buffer_reserve :: proc(buf: ^GraphicsBuffer, count: int) {
	if buf == nil || buf.Disposed {
		return
	}
	count_value := count
	if count_value < 0 {
		count_value = 0
	}
	buf.Count = count_value
	graphics_buffer_ensure_size(buf, count_value * buf.ElementSizeInBytes)
}

GraphicsBufferReserve :: graphics_buffer_reserve
GraphicsBufferUpload :: graphics_buffer_upload
GraphicsBufferClear :: graphics_buffer_clear
GraphicsBufferDispose :: graphics_buffer_dispose
GraphicsBufferCount :: proc(buf:^GraphicsBuffer)->int{if buf==nil{return 0};return buf.Count}
GraphicsBufferFormat :: proc(buf:^GraphicsBuffer)->IndexFormat{if buf==nil{return .Sixteen};return buf.IndexFormat}
GraphicsBufferIsDisposed :: proc(buf:^GraphicsBuffer)->bool{return buf==nil||buf.Disposed}
GraphicsBufferName :: proc(buf:^GraphicsBuffer)->string{if buf==nil{return ""};return buf.Name}

VertexBuffer :: struct {
	Base: GraphicsBuffer,
	Stride: int,
	Format: VertexFormat,
}

vertex_buffer_init_with_format :: proc(vb: ^VertexBuffer, graphics_device: ^GraphicsDevice, format: VertexFormat, name: string = "") {
	vb.Stride = format.Stride
	vb.Format = vertex_format_clone(format)
	graphics_buffer_init(&vb.Base, graphics_device, format.Stride, .Vertex, .Sixteen, name)
}

vertex_buffer_init :: proc(vb: ^VertexBuffer, graphics_device: ^GraphicsDevice, stride: int, name: string = "") {
	format: VertexFormat
	if stride == size_of(BatcherVertex) {
		format = default_batcher_vertex_format()
	} else {
		format = vertex_format_make(nil, stride)
	}
	vertex_buffer_init_with_format(vb, graphics_device, format, name)
	vertex_format_dispose(&format)
}

vertex_buffer_upload :: proc(vb: ^VertexBuffer, data: rawptr, vertex_count: int, offset: int = 0) {
	graphics_buffer_upload(&vb.Base, data, vertex_count, offset)
}

vertex_buffer_clear :: proc(vb: ^VertexBuffer) { graphics_buffer_clear(&vb.Base) }
vertex_buffer_dispose :: proc(vb: ^VertexBuffer) {
	vertex_format_dispose(&vb.Format)
	graphics_buffer_dispose(&vb.Base)
}

VertexBufferInit :: proc{vertex_buffer_init, vertex_buffer_init_with_format}
VertexBufferReserve :: proc(vb: ^VertexBuffer, count: int) { graphics_buffer_reserve(&vb.Base, count) }
VertexBufferUpload :: vertex_buffer_upload
VertexBufferClear :: vertex_buffer_clear
VertexBufferDispose :: vertex_buffer_dispose

IndexBuffer :: struct {
	Base: GraphicsBuffer,
	Format: IndexFormat,
}

index_buffer_init :: proc(ib: ^IndexBuffer, graphics_device: ^GraphicsDevice, format: IndexFormat, name: string = "") {
	ib.Format = format
	graphics_buffer_init(&ib.Base, graphics_device, index_format_size_in_bytes(format), .Index, format, name)
}

index_buffer_upload :: proc(ib: ^IndexBuffer, data: rawptr, index_count: int, offset: int = 0) {
	graphics_buffer_upload(&ib.Base, data, index_count, offset)
}

index_buffer_clear :: proc(ib: ^IndexBuffer) { graphics_buffer_clear(&ib.Base) }
index_buffer_dispose :: proc(ib: ^IndexBuffer) { graphics_buffer_dispose(&ib.Base) }

IndexBufferInit :: index_buffer_init
IndexBufferReserve :: proc(ib: ^IndexBuffer, count: int) { graphics_buffer_reserve(&ib.Base, count) }
IndexBufferUpload :: index_buffer_upload
IndexBufferClear :: index_buffer_clear
IndexBufferDispose :: index_buffer_dispose

StorageBuffer :: struct {
	Base: GraphicsBuffer,
}

storage_buffer_init :: proc(sb: ^StorageBuffer, graphics_device: ^GraphicsDevice, element_size_in_bytes: int, name: string = "") {
	graphics_buffer_init(&sb.Base, graphics_device, element_size_in_bytes, .Storage, .Sixteen, name)
}

storage_buffer_upload :: proc(sb: ^StorageBuffer, data: rawptr, element_count: int, offset: int = 0) {
	graphics_buffer_upload(&sb.Base, data, element_count, offset)
}

storage_buffer_clear :: proc(sb: ^StorageBuffer) { graphics_buffer_clear(&sb.Base) }
storage_buffer_dispose :: proc(sb: ^StorageBuffer) { graphics_buffer_dispose(&sb.Base) }

StorageBufferInit :: storage_buffer_init
StorageBufferReserve :: proc(sb: ^StorageBuffer, count: int) { graphics_buffer_reserve(&sb.Base, count) }
StorageBufferUpload :: storage_buffer_upload
StorageBufferClear :: storage_buffer_clear
StorageBufferDispose :: storage_buffer_dispose
