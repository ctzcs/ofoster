package foster_framework

import SDL "vendor:sdl3"

// ComputeCommand describes a compute dispatch independently of draw commands.
ComputeCommand :: struct {
	Shader: ^Shader,
	StorageBuffers: [dynamic]^StorageBuffer,
	StorageTextures: [dynamic]^Texture,
	UniformBuffers: [dynamic]UniformBuffer,
	GroupCountX, GroupCountY, GroupCountZ: int,
}

compute_command_init :: proc(command: ^ComputeCommand) {
	if command == nil { return }
	command.Shader = nil
	delete(command.StorageBuffers)
	delete(command.StorageTextures)
	delete(command.UniformBuffers)
	command.GroupCountX = 1
	command.GroupCountY = 1
	command.GroupCountZ = 1
}

compute_command_dispose :: proc(command: ^ComputeCommand) {
	if command == nil { return }
	delete(command.StorageBuffers)
	delete(command.StorageTextures)
	delete(command.UniformBuffers)
}

compute_command_set_groups :: proc(command: ^ComputeCommand, x, y, z: int) {
	if command == nil { return }
	command.GroupCountX = x
	command.GroupCountY = y
	command.GroupCountZ = z
}

graphics_device_dispatch :: proc(device: ^GraphicsDevice, command: ^ComputeCommand) -> bool {
	if device == nil || device.Disposed || device.Device == nil || command == nil || command.Shader == nil { return false }
	if command.GroupCountX <= 0 || command.GroupCountY <= 0 || command.GroupCountZ <= 0 { return false }
	if command.Shader.ComputeResource == nil { return false }
	command_buffer := device.CommandBuffer
	own_command_buffer := false
	if command_buffer == nil {
		command_buffer = SDL.AcquireGPUCommandBuffer(device.Device)
		own_command_buffer = true
	}
	if command_buffer == nil { return false }
	buffer_bindings := make([]SDL.GPUStorageBufferReadWriteBinding, len(command.StorageBuffers), context.temp_allocator)
	for buffer, i in command.StorageBuffers {
		if buffer == nil || buffer.Base.Resource == nil {
			if own_command_buffer { _ = SDL.CancelGPUCommandBuffer(command_buffer) }
			return false
		}
		buffer_bindings[i] = SDL.GPUStorageBufferReadWriteBinding{buffer = buffer.Base.Resource, cycle = false}
	}
	texture_bindings := make([]SDL.GPUStorageTextureReadWriteBinding, len(command.StorageTextures), context.temp_allocator)
	for texture, i in command.StorageTextures {
		if texture == nil || texture.Resource == nil {
			if own_command_buffer { _ = SDL.CancelGPUCommandBuffer(command_buffer) }
			return false
		}
		texture_bindings[i] = SDL.GPUStorageTextureReadWriteBinding{texture = texture.Resource, mip_level = 0, layer = 0, cycle = false}
	}
	pass := SDL.BeginGPUComputePass(command_buffer, raw_data(texture_bindings), u32(len(texture_bindings)), raw_data(buffer_bindings), u32(len(buffer_bindings)))
	if pass == nil {
		if own_command_buffer { _ = SDL.CancelGPUCommandBuffer(command_buffer) }
		return false
	}
	defer SDL.EndGPUComputePass(pass)
	SDL.BindGPUComputePipeline(pass, command.Shader.ComputeResource)
	for uniform, i in command.UniformBuffers {
		if len(uniform.Data) > 0 { SDL.PushGPUComputeUniformData(command_buffer, u32(i), raw_data(uniform.Data[:]), u32(len(uniform.Data))) }
	}
	SDL.DispatchGPUCompute(pass, u32(command.GroupCountX), u32(command.GroupCountY), u32(command.GroupCountZ))
	if own_command_buffer { return SDL.SubmitGPUCommandBuffer(command_buffer) }
	return true
}

ComputeCommandInit :: compute_command_init
ComputeCommandDispose :: compute_command_dispose
ComputeCommandSetGroups :: compute_command_set_groups
GraphicsDeviceDispatch :: graphics_device_dispatch
