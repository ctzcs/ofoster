package foster_framework

import SDL "vendor:sdl3"

VertexType :: enum {
	None,
	Float,
	Float2,
	Float3,
	Float4,
	Byte4,
	UByte4,
	Short2,
	UShort2,
	Short4,
	UShort4,
}

vertex_type_size_in_bytes :: proc(t: VertexType) -> int {
	#partial switch t {
	case .Float:
		return 4
	case .Float2:
		return 8
	case .Float3:
		return 12
	case .Float4:
		return 16
	case .Byte4, .UByte4:
		return 4
	case .Short2, .UShort2:
		return 4
	case .Short4, .UShort4:
		return 8
	case .None:
	}
	return 0
}

vertex_type_to_sdl :: proc(t: VertexType, normalized: bool) -> SDL.GPUVertexElementFormat {
	#partial switch t {
	case .Float:
		return .FLOAT
	case .Float2:
		return .FLOAT2
	case .Float3:
		return .FLOAT3
	case .Float4:
		return .FLOAT4
	case .Byte4:
		if normalized {
			return .BYTE4_NORM
		}
		return .BYTE4
	case .UByte4:
		if normalized {
			return .UBYTE4_NORM
		}
		return .UBYTE4
	case .Short2:
		if normalized {
			return .SHORT2_NORM
		}
		return .SHORT2
	case .UShort2:
		if normalized {
			return .USHORT2_NORM
		}
		return .USHORT2
	case .Short4:
		if normalized {
			return .SHORT4_NORM
		}
		return .SHORT4
	case .UShort4:
		if normalized {
			return .USHORT4_NORM
		}
		return .USHORT4
	case .None:
	}
	return .FLOAT
}

VertexElement :: struct {
	Index: int,
	Type: VertexType,
	Normalized: bool,
}

VertexFormat :: struct {
	Elements: [dynamic]VertexElement,
	Stride: int,
}

vertex_format_init :: proc(format: ^VertexFormat, elements: []VertexElement, stride: int = 0) {
	format.Elements = nil
	format.Stride = 0
	for element in elements {
		append(&format.Elements, element)
		format.Stride += vertex_type_size_in_bytes(element.Type)
	}
	if stride != 0 {
		format.Stride = stride
	}
}

vertex_format_make :: proc(elements: []VertexElement, stride: int = 0) -> VertexFormat {
	format: VertexFormat
	vertex_format_init(&format, elements, stride)
	return format
}

vertex_format_clone :: proc(format: VertexFormat) -> VertexFormat {
	clone: VertexFormat
	clone.Stride = format.Stride
	append(&clone.Elements, ..format.Elements[:])
	return clone
}

vertex_format_dispose :: proc(format: ^VertexFormat) {
	if format == nil {
		return
	}
	delete(format.Elements)
	format.Elements = nil
	format.Stride = 0
}

vertex_format_equals :: proc(a, b: VertexFormat) -> bool {
	if a.Stride != b.Stride || len(a.Elements) != len(b.Elements) {
		return false
	}
	for i := 0; i < len(a.Elements); i += 1 {
		ae := a.Elements[i]
		be := b.Elements[i]
		if ae.Index != be.Index || ae.Type != be.Type || ae.Normalized != be.Normalized {
			return false
		}
	}
	return true
}

default_batcher_vertex_format :: proc() -> VertexFormat {
	elements := [4]VertexElement{
		{Index = 0, Type = .Float2, Normalized = false},
		{Index = 1, Type = .Float2, Normalized = false},
		{Index = 2, Type = .UByte4, Normalized = true},
		{Index = 3, Type = .UByte4, Normalized = true},
	}
	return vertex_format_make(elements[:], size_of(BatcherVertex))
}

default_pos_tex_col_vertex_format :: proc() -> VertexFormat {
	elements := [3]VertexElement{
		{Index = 0, Type = .Float2, Normalized = false},
		{Index = 1, Type = .Float2, Normalized = false},
		{Index = 2, Type = .UByte4, Normalized = true},
	}
	return vertex_format_make(elements[:])
}

VertexTypeSizeInBytes :: vertex_type_size_in_bytes
VertexTypeToSDL :: vertex_type_to_sdl
VertexFormatInit :: proc{vertex_format_init, vertex_format_make}
VertexFormatClone :: vertex_format_clone
VertexFormatDispose :: vertex_format_dispose
VertexFormatEquals :: vertex_format_equals
BatcherVertexFormat :: default_batcher_vertex_format
PosTexColVertexFormat :: default_pos_tex_col_vertex_format
