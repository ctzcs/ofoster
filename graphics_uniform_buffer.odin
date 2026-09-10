package foster_framework

import "core:mem"

UniformBuffer :: struct {
	Data: [dynamic]u8,
}

uniform_buffer_init :: proc(buffer: ^UniformBuffer, size: int = 0) {
	if buffer == nil { return }
	delete(buffer.Data)
	buffer.Data = nil
	if size > 0 { resize(&buffer.Data, size) }
}

uniform_buffer_set :: proc(buffer: ^UniformBuffer, data: []u8, offset: int = 0) {
	if buffer == nil || offset < 0 { return }
	needed := offset + len(data)
	if needed > len(buffer.Data) { resize(&buffer.Data, needed) }
	if len(data) > 0 { mem.copy(raw_data(buffer.Data[offset:]), raw_data(data), len(data)) }
}

uniform_buffer_set_value :: proc(buffer: ^UniformBuffer, value: $T, offset: int = 0) {
	data := make([]u8, size_of(T), context.temp_allocator)
	copy_value := value
	mem.copy(raw_data(data), &copy_value, size_of(T))
	uniform_buffer_set(buffer, data, offset)
}

uniform_buffer_get :: proc(buffer: ^UniformBuffer) -> []u8 {
	if buffer == nil { return nil }
	return buffer.Data[:]
}

uniform_buffer_clear :: proc(buffer: ^UniformBuffer) {
	if buffer == nil { return }
	resize(&buffer.Data, 0)
}

uniform_buffer_dispose :: proc(buffer: ^UniformBuffer) {
	if buffer == nil { return }
	delete(buffer.Data)
	buffer.Data = nil
}

UniformBufferInit :: uniform_buffer_init
UniformBufferSet :: uniform_buffer_set
UniformBufferSetValue :: uniform_buffer_set_value
UniformBufferGet :: uniform_buffer_get
UniformBufferClear :: uniform_buffer_clear
UniformBufferDispose :: uniform_buffer_dispose
