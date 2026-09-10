package foster_framework

import SDL "vendor:sdl3"

TextureFormat :: enum {
	R8G8B8A8,
	R8,
	R8G8,
	Depth24Stencil8,
	Depth32Stencil8,
	Depth16,
	Depth24,
	Depth32,
	R16G16B16A16_FLOAT,
	R32G32B32A32_FLOAT,
	R11G11B10_UFLOAT,
	Color = R8G8B8A8,
}

texture_format_size :: proc(format: TextureFormat) -> int {
	switch format {
	case .R8G8B8A8:
		return 4
	case .R8:
		return 1
	case .R8G8:
		return 2
	case .R16G16B16A16_FLOAT:
		return 8
	case .R32G32B32A32_FLOAT:
		return 16
	case .R11G11B10_UFLOAT:
		return 4
	case .Depth24Stencil8:
		return 4
	case .Depth32Stencil8:
		return 5
	case .Depth16:
		return 2
	case .Depth24:
		return 3
	case .Depth32:
		return 4
	}
	panic("Invalid TextureFormat")
}

texture_format_is_color_format :: proc(format: TextureFormat) -> bool {
	switch format {
	case .R8G8B8A8, .R8, .R8G8, .R16G16B16A16_FLOAT, .R32G32B32A32_FLOAT, .R11G11B10_UFLOAT:
		return true
	case .Depth24Stencil8, .Depth32Stencil8, .Depth16, .Depth24, .Depth32:
		return false
	}
	panic("Invalid TextureFormat")
}

texture_format_to_sdl :: proc(format: TextureFormat) -> SDL.GPUTextureFormat {
	switch format {
	case .R8G8B8A8:
		return .R8G8B8A8_UNORM
	case .R8:
		return .R8_UNORM
	case .R8G8:
		return .R8G8_UNORM
	case .R16G16B16A16_FLOAT:
		return .R16G16B16A16_FLOAT
	case .R32G32B32A32_FLOAT:
		return .R32G32B32A32_FLOAT
	case .R11G11B10_UFLOAT:
		return .R11G11B10_UFLOAT
	case .Depth24Stencil8:
		return .D24_UNORM_S8_UINT
	case .Depth32Stencil8:
		return .D32_FLOAT_S8_UINT
	case .Depth16:
		return .D16_UNORM
	case .Depth24:
		return .D24_UNORM
	case .Depth32:
		return .D32_FLOAT
	}
	panic("Invalid TextureFormat")
}

SampleCount :: enum {
	One,
	Two,
	Four,
	Eight,
}

sample_count_to_sdl :: proc(samples: SampleCount) -> SDL.GPUSampleCount {
	#partial switch samples {
	case .One:
		return ._1
	case .Two:
		return ._2
	case .Four:
		return ._4
	case .Eight:
		return ._8
	}
	return ._1
}

IndexFormat :: enum {
	Sixteen,
	ThirtyTwo,
}

index_format_size_in_bytes :: proc(format: IndexFormat) -> int {
	#partial switch format {
	case .Sixteen:
		return 2
	case .ThirtyTwo:
		return 4
	}
	return 0
}

index_format_to_sdl :: proc(format: IndexFormat) -> SDL.GPUIndexElementSize {
	#partial switch format {
	case .Sixteen:
		return ._16BIT
	case .ThirtyTwo:
		return ._32BIT
	}
	return ._16BIT
}

ShaderStage :: enum {
	Vertex,
	Fragment,
	Compute,
}

shader_stage_to_sdl :: proc(stage: ShaderStage) -> SDL.GPUShaderStage {
	#partial switch stage {
	case .Vertex:
		return .VERTEX
	case .Fragment:
		return .FRAGMENT
	case .Compute:
		// The bundled SDL3 bindings currently expose graphics shader stages
		// only; compute dispatch remains a backend extension.
		return .VERTEX
	}
	return .VERTEX
}

ShaderCreateInfo :: struct {
	Stage: ShaderStage,
	Code: []u8,
	SamplerCount: int,
	UniformBufferCount: int,
	StorageBufferCount: int,
	EntryPoint: string,
	ThreadCountX, ThreadCountY, ThreadCountZ: int,
}

default_shader_create_info :: proc(stage: ShaderStage, code: []u8) -> ShaderCreateInfo {
	return ShaderCreateInfo{
		Stage = stage,
		Code = code,
		SamplerCount = 0,
		UniformBufferCount = 0,
		StorageBufferCount = 0,
		EntryPoint = "main",
		ThreadCountX = 1,
		ThreadCountY = 1,
		ThreadCountZ = 1,
	}
}

TextureFormatSize :: texture_format_size
TextureFormatIsColorFormat :: texture_format_is_color_format
TextureFormatToSDL :: texture_format_to_sdl
SampleCountToSDL :: sample_count_to_sdl
IndexFormatSizeInBytes :: index_format_size_in_bytes
IndexFormatToSDL :: index_format_to_sdl
ShaderStageToSDL :: shader_stage_to_sdl
DefaultShaderCreateInfo :: default_shader_create_info

BlendFactor :: enum {
	Zero,
	One,
	SrcColor,
	OneMinusSrcColor,
	DstColor,
	OneMinusDstColor,
	SrcAlpha,
	OneMinusSrcAlpha,
	DstAlpha,
	OneMinusDstAlpha,
	ConstantColor,
	OneMinusConstantColor,
	SrcAlphaSaturate,
}

BlendOp :: enum {
	Add,
	Subtract,
	ReverseSubtract,
	Min,
	Max,
}

BlendMask :: enum u8 {
	None = 0,
	Red = 1,
	Green = 2,
	Blue = 4,
	Alpha = 8,
	RGB = 7,
	RGBA = 15,
}

BlendMode :: struct {
	ColorOperation: BlendOp,
	ColorSource: BlendFactor,
	ColorDestination: BlendFactor,
	AlphaOperation: BlendOp,
	AlphaSource: BlendFactor,
	AlphaDestination: BlendFactor,
	Mask: BlendMask,
	Color: Color,
}

blend_mode_make :: proc(operation: BlendOp, source, destination: BlendFactor) -> BlendMode {
	return BlendMode{
		ColorOperation = operation,
		ColorSource = source,
		ColorDestination = destination,
		AlphaOperation = operation,
		AlphaSource = source,
		AlphaDestination = destination,
		Mask = .RGBA,
		Color = White,
	}
}

blend_mode_make_full :: proc(color_operation: BlendOp, color_source, color_destination: BlendFactor, alpha_operation: BlendOp, alpha_source, alpha_destination: BlendFactor, mask: BlendMask, color: Color) -> BlendMode {
	return BlendMode{
		ColorOperation = color_operation,
		ColorSource = color_source,
		ColorDestination = color_destination,
		AlphaOperation = alpha_operation,
		AlphaSource = alpha_source,
		AlphaDestination = alpha_destination,
		Mask = mask,
		Color = color,
	}
}

// Full replacement. This exact value disables hardware blending; it is also
// equal to BlendModeMake(.Add, .One, .Zero).
BlendModeDisabled :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .One,
	ColorDestination = .Zero,
	AlphaOperation = .Add,
	AlphaSource = .One,
	AlphaDestination = .Zero,
	Mask = .RGBA,
	Color = White,
}

BlendModePremultiply :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .One,
	ColorDestination = .OneMinusSrcAlpha,
	AlphaOperation = .Add,
	AlphaSource = .One,
	AlphaDestination = .OneMinusSrcAlpha,
	Mask = .RGBA,
	Color = White,
}
BlendModeNonPremultiplied :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .SrcAlpha,
	ColorDestination = .OneMinusSrcAlpha,
	AlphaOperation = .Add,
	AlphaSource = .SrcAlpha,
	AlphaDestination = .OneMinusSrcAlpha,
	Mask = .RGBA,
	Color = White,
}
BlendModeAdd :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .One,
	ColorDestination = .DstAlpha,
	AlphaOperation = .Add,
	AlphaSource = .One,
	AlphaDestination = .DstAlpha,
	Mask = .RGBA,
	Color = White,
}
BlendModeSubtract :: BlendMode{
	ColorOperation = .ReverseSubtract,
	ColorSource = .One,
	ColorDestination = .One,
	AlphaOperation = .Add,
	AlphaSource = .One,
	AlphaDestination = .One,
	Mask = .RGBA,
	Color = White,
}
BlendModeMultiply :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .DstColor,
	ColorDestination = .OneMinusSrcAlpha,
	AlphaOperation = .Add,
	AlphaSource = .DstColor,
	AlphaDestination = .OneMinusSrcAlpha,
	Mask = .RGBA,
	Color = White,
}
BlendModeScreen :: BlendMode{
	ColorOperation = .Add,
	ColorSource = .One,
	ColorDestination = .OneMinusSrcColor,
	AlphaOperation = .Add,
	AlphaSource = .One,
	AlphaDestination = .OneMinusSrcColor,
	Mask = .RGBA,
	Color = White,
}

CullMode :: enum {
	None,
	Front,
	Back,
}

DepthCompare :: enum {
	Always,
	Never,
	Less,
	Equal,
	LessOrEqual,
	Greater,
	NotEqual,
	GreatorOrEqual,
}

FillMode :: enum {
	Fill,
	Line,
}

StencilOp :: enum {
	Invalid,
	Keep,
	Zero,
	Replace,
	IncrementAndClamp,
	DecrementAndClamp,
	Invert,
	IncrementAndWrap,
	DecrementAndWrap,
}

StencilState :: struct {
	FailOp: StencilOp,
	PassOp: StencilOp,
	DepthFailOp: StencilOp,
	CompareOp: DepthCompare,
}

StencilStateMake :: proc(op: StencilOp, compare: DepthCompare) -> StencilState {
	return StencilState{FailOp = op, PassOp = op, DepthFailOp = op, CompareOp = compare}
}

TextureFlag :: enum u8 {
	ComputeRead,
	ComputeWrite,
}

TextureFlags :: distinct bit_set[TextureFlag; u8]
TextureFlagsNone :: TextureFlags{}

ClearMask :: enum u8 {
	None = 0,
	Color = 1,
	Depth = 2,
	Stencil = 4,
	All = 7,
}

BlendModeMake :: proc{blend_mode_make, blend_mode_make_full}
