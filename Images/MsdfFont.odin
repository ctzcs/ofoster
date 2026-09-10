package foster_images

import spatial "../Spatial"
import json "core:encoding/json"
import runtime ".."
// core:os 经根包 storage_os_* 平台层使用(js 目标无 core:os)

MsdfAtlasProperties :: struct { Type:string, DistanceRange,DistanceRangeMiddle,Size,Width,Height:f32, YOrigin:string }
MsdfMetricsProperties :: struct { EmSize,LineHeight,Ascender,Descender,UnderlineY,UnderlineThickness:f32 }
MsdfBounds :: struct { Left,Top,Right,Bottom:f32 }
MsdfGlyph :: struct { Unicode:int, Advance:f32, PlaneBounds,AtlasBounds:MsdfBounds }
MsdfCharacter :: struct { Codepoint:int, SourceRect:spatial.Rect, Advance:f32, Offset:spatial.Vec2 }
MsdfKerning :: struct { First, Second:int, Advance:f32 }
MsdfFont :: struct { Image:Image, Size,Ascent,Descent,LineGap,Height,LineHeight,DistanceRange:f32, Characters:[dynamic]MsdfCharacter, Kerning:[dynamic]MsdfKerning }

msdf_num :: proc(v:json.Value)->f32 { #partial switch x in v { case json.Float:return f32(x); case json.Integer:return f32(x) }; return 0 }
msdf_obj :: proc(v:json.Value)->json.Object { #partial switch x in v { case json.Object:return x }; return nil }
msdf_array :: proc(v:json.Value)->json.Array { #partial switch x in v { case json.Array:return x }; return nil }
msdf_string :: proc(v:json.Value)->string { #partial switch x in v { case json.String:return string(x) }; return "" }
msdf_bounds :: proc(v:json.Value)->MsdfBounds { o:=msdf_obj(v);return MsdfBounds{msdf_num(o["left"]),msdf_num(o["top"]),msdf_num(o["right"]),msdf_num(o["bottom"])} }

MsdfFontMake :: proc(atlas:Image,data:[]u8)->MsdfFont {
	f:=MsdfFont{Image=atlas};value,err:=json.parse_bytes(data,json.Specification.JSON,false);if err!=.None{return f};root:=msdf_obj(value);a:=msdf_obj(root["atlas"]);m:=msdf_obj(root["metrics"])
	f.Size=msdf_num(a["size"]);f.DistanceRange=msdf_num(a["distanceRange"]);f.Ascent=math_abs(msdf_num(m["ascender"]))*f.Size;f.Descent=-math_abs(msdf_num(m["descender"]))*f.Size;f.Height=f.Ascent-f.Descent;f.LineHeight=msdf_num(m["lineHeight"])*f.Size;f.LineGap=f.LineHeight-f.Height
	for glyph in msdf_array(root["glyphs"]){o:=msdf_obj(glyph);unicode:=int(msdf_num(o["unicode"]));advance:=msdf_num(o["advance"])*f.Size;plane:=msdf_bounds(o["planeBounds"]);atlas_bounds:=msdf_bounds(o["atlasBounds"]);source:=spatial.Rect{atlas_bounds.Left,atlas_bounds.Top,atlas_bounds.Right-atlas_bounds.Left,atlas_bounds.Bottom-atlas_bounds.Top};offset:=spatial.Vec2{plane.Left*f.Size,plane.Top*f.Size};append(&f.Characters,MsdfCharacter{unicode,source,advance,offset})}
	for pair in msdf_array(root["kerning"]){o:=msdf_obj(pair);first:=int(msdf_num(o["unicode1"]));second:=int(msdf_num(o["unicode2"]));advance:=msdf_num(o["advance"])*f.Size;append(&f.Kerning,MsdfKerning{first,second,advance})}
	json.destroy_value(value);return f
}
math_abs :: proc(v:f32)->f32{if v<0{return -v};return v}
MsdfFontLoadFiles :: proc(image_path,data_path:string)->MsdfFont{image:=ImageLoadFile(image_path);data:=runtime.storage_os_read_file(data_path,context.temp_allocator);if data==nil{return MsdfFont{Image=image}};return MsdfFontMake(image,data)}
MsdfFontGetKerning :: proc(f:^MsdfFont,a,b:int,size:f32=0)->f32{if f==nil{return 0};s:=size;if s==0{s=f.Size};for k in f.Kerning{if k.First==a&&k.Second==b{if f.Size>0{return k.Advance*(s/f.Size)};return k.Advance}};return 0}
MsdfFontFindCharacter :: proc(f:^MsdfFont,codepoint:int)->(MsdfCharacter,bool){if f==nil{return {},false};for c in f.Characters{if c.Codepoint==codepoint{return c,true}};return {},false}
