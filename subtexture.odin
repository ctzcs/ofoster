package foster_framework

import "core:math"

// ===== merged from Graphics/Structs/Subtexture.odin =====


CoordinateBuffer :: [4]Vec2

Subtexture :: struct {
	Texture:    ^Texture,
	Source:     Rect,
	Frame:      Rect,
	TexCoords:  CoordinateBuffer,
	DrawCoords: CoordinateBuffer,
}

SubtextureEmpty :: Subtexture{}

SubtextureMake :: proc(texture: ^Texture, source, frame: Rect) -> Subtexture {
	result := Subtexture{Texture = texture, Source = source, Frame = frame}
	result.DrawCoords = CoordinateBuffer{
		{-frame.X, -frame.Y}, {-frame.X+source.Width, -frame.Y},
		{-frame.X+source.Width, -frame.Y+source.Height}, {-frame.X, -frame.Y+source.Height},
	}
	if texture != nil && texture.Width > 0 && texture.Height > 0 {
		px := 1.0/f32(texture.Width); py := 1.0/f32(texture.Height)
		tx0 := source.X*px; ty0 := source.Y*py
		tx1 := RectRight(source)*px; ty1 := RectBottom(source)*py
		result.TexCoords = CoordinateBuffer{{tx0,ty0},{tx1,ty0},{tx1,ty1},{tx0,ty1}}
	}
	return result
}

SubtextureFromTexture :: proc(texture: ^Texture) -> Subtexture {
	if texture == nil do return Subtexture{}
	bounds := Rect{0, 0, f32(texture.Width), f32(texture.Height)}
	return SubtextureMake(texture, bounds, bounds)
}

SubtextureFromSource :: proc(texture: ^Texture, source: Rect) -> Subtexture {
	return SubtextureMake(texture, source, Rect{0, 0, source.Width, source.Height})
}

SubtextureWidth :: proc(subtexture: Subtexture) -> f32 { return subtexture.Frame.Width }
SubtextureHeight :: proc(subtexture: Subtexture) -> f32 { return subtexture.Frame.Height }
SubtextureSize :: proc(subtexture: Subtexture) -> Vec2 { return RectSize(subtexture.Frame) }
SubtextureIsEmpty :: proc(subtexture: Subtexture) -> bool { return subtexture.Texture == nil || subtexture.Source.Width == 0 || subtexture.Source.Height == 0 }

SubtextureGetClip :: proc(subtexture: Subtexture, clip: Rect) -> (source, frame: Rect) {
	source_position := RectPosition(subtexture.Source)
	frame_position := RectPosition(subtexture.Frame)
	offset := Vec2{source_position[0]+frame_position[0], source_position[1]+frame_position[1]}
	source = RectIntersection(RectTranslate(clip, offset), subtexture.Source)
	frame = Rect{math.min(f32(0), subtexture.Frame.X+clip.X), math.min(f32(0), subtexture.Frame.Y+clip.Y), clip.Width, clip.Height}
	return
}

SubtextureGetClipSubtexture :: proc(subtexture: Subtexture, clip: Rect) -> Subtexture {
	source, frame := SubtextureGetClip(subtexture, clip)
	return SubtextureMake(subtexture.Texture, source, frame)
}
