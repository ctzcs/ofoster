package foster_framework

import "core:fmt"
import "core:math"
import "core:strconv"
import SDL "vendor:sdl3"

PI :: f32(math.PI)
HalfPI :: PI / 2
TAU :: f32(math.TAU)
DegToRad :: TAU / 360
RadToDeg :: 360 / TAU

RightAngle :: f32(0)
LeftAngle :: PI
UpAngle :: PI + HalfPI
DownAngle :: HalfPI
UpRightAngle :: TAU - PI * 0.25
DownRightAngle :: PI * 0.25
UpLeftAngle :: TAU - PI * 0.75
DownLeftAngle :: PI * 0.75

Clamp :: proc(value, min_value, max_value: $T) -> T {
	if value < min_value do return min_value
	if value > max_value do return max_value
	return value
}

Clamp01 :: proc(value: f32) -> f32 {
	return Clamp(value, 0, 1)
}

Round :: proc(v: f32) -> int { return int(math.round(v)) }
Floor :: proc(v: f32) -> int { return int(math.floor(v)) }
Ceil  :: proc(v: f32) -> int { return int(math.ceil(v)) }

Min :: proc(a, b: $T) -> T {
	if a < b do return a
	return b
}

Min3 :: proc(a, b, c: $T) -> T {
	return Min(Min(a, b), c)
}

Min4 :: proc(a, b, c, d: $T) -> T {
	return Min(Min(Min(a, b), c), d)
}

Max :: proc(a, b: $T) -> T {
	if a > b do return a
	return b
}

Max3 :: proc(a, b, c: $T) -> T {
	return Max(Max(a, b), c)
}

Max4 :: proc(a, b, c, d: $T) -> T {
	return Max(Max(Max(a, b), c), d)
}

ApproachScalar :: proc(from, target, amount: f32) -> f32 {
	if from > target {
		return Max(from-amount, target)
	}
	return Min(from+amount, target)
}

map_range :: proc(val, min_value, max_value, new_min, new_max: f32) -> f32 {
	return ((val - min_value) / (max_value - min_value)) * (new_max - new_min) + new_min
}

Map :: proc(val, min_value, max_value: f32) -> f32 {
	return map_range(val, min_value, max_value, 0, 1)
}

MapTo :: map_range

clamped_map_range :: proc(val, min_value, max_value, new_min, new_max: f32) -> f32 {
	return Clamp01((val - min_value) / (max_value - min_value)) * (new_max - new_min) + new_min
}

ClampedMap :: proc(val, min_value, max_value: f32) -> f32 {
	return clamped_map_range(val, min_value, max_value, 0, 1)
}

ClampedMapTo :: clamped_map_range

YoYo :: proc(value: f32) -> f32 {
	if value <= 0.5 {
		return value * 2
	}
	return 1 - ((value - 0.5) * 2)
}

OnIntervalCalc :: proc(time, delta, interval, offset: f64) -> bool {
	return math.floor((time - offset - delta) / interval) < math.floor((time - offset) / interval)
}

OnInterval :: proc(time, delta, interval: f64) -> bool {
	return OnIntervalCalc(time, delta, interval, 0)
}

BetweenIntervalCalc :: proc(time, interval, offset: f64) -> bool {
	return math.mod(time-offset, interval*2) >= interval
}

BetweenInterval :: proc(time, interval: f64) -> bool {
	return BetweenIntervalCalc(time, interval, 0)
}

Point2UnitX :: Point2{1, 0}
Point2UnitY :: Point2{0, 1}
Point2Right :: Point2{1, 0}
Point2Left  :: Point2{-1, 0}
Point2Up    :: Point2{0, -1}
Point2Down  :: Point2{0, 1}

point2_length_squared :: proc(p: Point2) -> f32 {
	return f32(p.X*p.X + p.Y*p.Y)
}

point2_length :: proc(p: Point2) -> f32 {
	return math.sqrt(point2_length_squared(p))
}

point2_vector2 :: proc(p: Point2) -> [2]f32 {
	return [2]f32{f32(p.X), f32(p.Y)}
}

point2_normalized :: proc(p: Point2) -> [2]f32 {
	v := point2_vector2(p)
	length := math.sqrt(v[0]*v[0] + v[1]*v[1])
	if length == 0 do return [2]f32{}
	return [2]f32{v[0] / length, v[1] / length}
}

point2_get_length_and_normalize :: proc(p: Point2, fallback: [2]f32 = {}) -> (result: [2]f32, length: f32) {
	result = point2_vector2(p)
	length = math.sqrt(result[0]*result[0] + result[1]*result[1])
	if length == 0 {
		result = fallback
		return
	}
	result = [2]f32{result[0] / length, result[1] / length}
	return
}

point2_add :: proc(a, b: Point2) -> Point2 { return Point2{a.X+b.X, a.Y+b.Y} }
point2_sub :: proc(a, b: Point2) -> Point2 { return Point2{a.X-b.X, a.Y-b.Y} }
point2_negate :: proc(p: Point2) -> Point2 { return Point2{-p.X, -p.Y} }
point2_scale_int :: proc(p: Point2, scalar: int) -> Point2 { return Point2{p.X*scalar, p.Y*scalar} }
point2_div_int :: proc(p: Point2, scalar: int) -> Point2 { if scalar == 0 do return Point2{}; return Point2{p.X/scalar, p.Y/scalar} }
point2_mod_int :: proc(p: Point2, scalar: int) -> Point2 { if scalar == 0 do return Point2{}; return Point2{p.X%scalar, p.Y%scalar} }
point2_scale_float :: proc(p: Point2, scalar: f32) -> [2]f32 { return [2]f32{f32(p.X)*scalar, f32(p.Y)*scalar} }
point2_div_float :: proc(p: Point2, scalar: f32) -> [2]f32 { if scalar == 0 do return [2]f32{}; return [2]f32{f32(p.X)/scalar, f32(p.Y)/scalar} }

point2_floor_to :: proc(p: Point2, interval: int) -> Point2 {
	return Point2{
		(p.X / interval) * interval,
		(p.Y / interval) * interval,
	}
}

point2_floor_to_point :: proc(p, intervals: Point2) -> Point2 {
	return Point2{
		(p.X / intervals.X) * intervals.X,
		(p.Y / intervals.Y) * intervals.Y,
	}
}

point2_round_to :: proc(p: Point2, interval: int) -> Point2 {
	return Point2{Round(f32(p.X)/f32(interval)) * interval, Round(f32(p.Y)/f32(interval)) * interval}
}

point2_round_to_point :: proc(p, intervals: Point2) -> Point2 {
	return Point2{
		Round(f32(p.X)/f32(intervals.X)) * intervals.X,
		Round(f32(p.Y)/f32(intervals.Y)) * intervals.Y,
	}
}

point2_only_x :: proc(p: Point2) -> Point2 { return Point2{p.X, 0} }
point2_only_y :: proc(p: Point2) -> Point2 { return Point2{0, p.Y} }
point2_turn_right :: proc(p: Point2) -> Point2 { return Point2{-p.Y, p.X} }
point2_turn_left :: proc(p: Point2) -> Point2 { return Point2{p.Y, -p.X} }
point2_sign :: proc(p: Point2) -> Point2 { return Point2{int(math.sign(f32(p.X))), int(math.sign(f32(p.Y)))} }
point2_abs :: proc(p: Point2) -> Point2 { return Point2{math.abs(p.X), math.abs(p.Y)} }
point2_clamp :: proc(p, min_p, max_p: Point2) -> Point2 { return Point2{Clamp(p.X, min_p.X, max_p.X), Clamp(p.Y, min_p.Y, max_p.Y)} }
point2_clamp_rect :: proc(p: Point2, bounds: RectInt) -> Point2 { return point2_clamp(p, RectIntTopLeft(bounds), RectIntBottomRight(bounds)) }
point2_manhattan_dist :: proc(a, b: Point2) -> int { return math.abs(a.X-b.X) + math.abs(a.Y-b.Y) }
point2_min :: proc(a, b: Point2) -> Point2 { return Point2{Min(a.X, b.X), Min(a.Y, b.Y)} }
point2_min3 :: proc(a, b, c: Point2) -> Point2 { return Point2{Min3(a.X, b.X, c.X), Min3(a.Y, b.Y, c.Y)} }
point2_min4 :: proc(a, b, c, d: Point2) -> Point2 { return Point2{Min4(a.X, b.X, c.X, d.X), Min4(a.Y, b.Y, c.Y, d.Y)} }
point2_max :: proc(a, b: Point2) -> Point2 { return Point2{Max(a.X, b.X), Max(a.Y, b.Y)} }
point2_max3 :: proc(a, b, c: Point2) -> Point2 { return Point2{Max3(a.X, b.X, c.X), Max3(a.Y, b.Y, c.Y)} }
point2_max4 :: proc(a, b, c, d: Point2) -> Point2 { return Point2{Max4(a.X, b.X, c.X, d.X), Max4(a.Y, b.Y, c.Y, d.Y)} }
point2_from_bools :: proc(left, right, up, down: bool) -> Point2 {
	if right do return Point2Right
	if up do return Point2Up
	if left do return Point2Left
	if down do return Point2Down
	return Point2Zero
}

Point2Length :: point2_length
Point2LengthSquared :: point2_length_squared
Point2Vector2 :: point2_vector2
Point2Normalized :: point2_normalized
Point2GetLengthAndNormalize :: point2_get_length_and_normalize
Point2Add :: point2_add
Point2Sub :: point2_sub
Point2Negate :: point2_negate
Point2Scale :: proc{point2_scale_int, point2_scale_float}
Point2Div :: proc{point2_div_int, point2_div_float}
Point2Mod :: proc{point2_mod_int}
Point2FloorTo :: proc{point2_floor_to, point2_floor_to_point}
Point2RoundTo :: proc{point2_round_to, point2_round_to_point}
Point2OnlyX :: point2_only_x
Point2OnlyY :: point2_only_y
Point2TurnRight :: point2_turn_right
Point2TurnLeft :: point2_turn_left
Point2Sign :: point2_sign
Point2Abs :: point2_abs
Point2Clamp :: proc{point2_clamp, point2_clamp_rect}
Point2ManhattanDist :: point2_manhattan_dist
Point2Min :: proc{point2_min, point2_min3, point2_min4}
Point2Max :: proc{point2_max, point2_max3, point2_max4}
Point2FromBools :: point2_from_bools

Color :: struct {
	R: u8,
	G: u8,
	B: u8,
	A: u8,
}

color_rgb :: proc(rgb: int, alpha: u8 = 255) -> Color {
	return Color{u8(rgb >> 16), u8(rgb >> 8), u8(rgb), alpha}
}

color_rgba_u32 :: proc(rgba: u32) -> Color {
	return Color{u8(rgba >> 24), u8(rgba >> 16), u8(rgba >> 8), u8(rgba)}
}

color_f32 :: proc(r, g, b, a: f32) -> Color {
	return Color{u8(Clamp01(r) * 255), u8(Clamp01(g) * 255), u8(Clamp01(b) * 255), u8(Clamp01(a) * 255)}
}

RGBA :: proc(c: Color) -> u32 { return (u32(c.R) << 24) | (u32(c.G) << 16) | (u32(c.B) << 8) | u32(c.A) }
ABGR :: proc(c: Color) -> u32 { return (u32(c.A) << 24) | (u32(c.B) << 16) | (u32(c.G) << 8) | u32(c.R) }
Premultiply :: proc(c: Color) -> Color {
	a := c.A
	return Color{u8(u16(c.R) * u16(a) / 255), u8(u16(c.G) * u16(a) / 255), u8(u16(c.B) * u16(a) / 255), a}
}

ColorToVector4 :: proc(c: Color) -> [4]f32 {
	return [4]f32{f32(c.R) / 255, f32(c.G) / 255, f32(c.B) / 255, f32(c.A) / 255}
}

ToHexStringRGB :: proc(c: Color) -> string {
	return fmt.aprintf("%02X%02X%02X", c.R, c.G, c.B)
}

ToHexStringRGBA :: proc(c: Color) -> string {
	return fmt.aprintf("%02X%02X%02X%02X", c.R, c.G, c.B, c.A)
}

FromHexStringRGB :: proc(value: string) -> Color {
	v := value
	if len(v) > 0 && v[0] == '#' do v = v[1:]
	if len(v) > 1 && v[0] == '0' && (v[1] == 'x' || v[1] == 'X') do v = v[2:]
	if parsed, ok := strconv.parse_u64(v, nil); ok {
		return color_rgb(int(parsed))
	}
	return Black
}

FromHexStringRGBA :: proc(value: string) -> Color {
	v := value
	if len(v) > 0 && v[0] == '#' do v = v[1:]
	if len(v) > 1 && v[0] == '0' && (v[1] == 'x' || v[1] == 'X') do v = v[2:]
	if parsed, ok := strconv.parse_u64(v, nil); ok {
		return color_rgba_u32(u32(parsed))
	}
	return Black
}

ColorFromHSV :: proc(h, s, v: f32) -> Color {
	hue_section := Clamp01(h) * 6
	hue_index := int(hue_section)
	hue_remainder := hue_section - f32(hue_index)
	a := v * (1 - s)
	b := v * (1 - (s * hue_remainder))
	c := v * (1 - (s * (1 - hue_remainder)))
	switch hue_index {
	case 0: return color_f32(v, c, a, 1)
	case 1: return color_f32(b, v, c, 1)
	case 2: return color_f32(a, v, c, 1)
	case 3: return color_f32(a, b, v, 1)
	case 4: return color_f32(c, a, v, 1)
	case: return color_f32(v, a, b, 1)
	}
}

ColorLerp :: proc(a, b: Color, amount: f32) -> Color {
	t := Clamp01(amount)
	return Color{
		u8(f32(a.R) + (f32(b.R)-f32(a.R))*t),
		u8(f32(a.G) + (f32(b.G)-f32(a.G))*t),
		u8(f32(a.B) + (f32(b.B)-f32(a.B))*t),
		u8(f32(a.A) + (f32(b.A)-f32(a.A))*t),
	}
}

ColorToSDL :: proc(c: Color) -> SDL.FColor {
	return SDL.FColor{f32(c.R) / 255, f32(c.G) / 255, f32(c.B) / 255, f32(c.A) / 255}
}

Transparent :: Color{0, 0, 0, 0}
White :: Color{255, 255, 255, 255}
Black :: Color{0, 0, 0, 255}
LightGray :: Color{0xC0, 0xC0, 0xC0, 255}
Gray :: Color{0x80, 0x80, 0x80, 255}
DarkGray :: Color{0x40, 0x40, 0x40, 255}
Red :: Color{255, 0, 0, 255}
Green :: Color{0, 255, 0, 255}
Blue :: Color{0, 0, 255, 255}
Yellow :: Color{255, 255, 0, 255}
Magenta :: Color{255, 0, 255, 255}
Cyan :: Color{0, 255, 255, 255}
CornflowerBlue :: Color{0x64, 0x95, 0xED, 255}
Orange :: Color{0xFF, 0xA5, 0x00, 255}


TextureFilter :: enum {
	Nearest,
	Linear,
}

TextureWrap :: enum {
	Repeat,
	MirroredRepeat,
	Clamp,
}

TextureSampler :: struct {
	Filter: TextureFilter,
	WrapX: TextureWrap,
	WrapY: TextureWrap,
}

texture_sampler_make :: proc(filter: TextureFilter, wrap_x, wrap_y: TextureWrap) -> TextureSampler {
	return TextureSampler{filter, wrap_x, wrap_y}
}

texture_sampler_make_uniform :: proc(filter: TextureFilter, wrap_xy: TextureWrap) -> TextureSampler {
	return TextureSampler{filter, wrap_xy, wrap_xy}
}

TextureSamplerMake :: proc{texture_sampler_make, texture_sampler_make_uniform}
