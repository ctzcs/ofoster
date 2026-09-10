package foster_images

import spatial "../Spatial"
import stb "../Internal/ThirdParty"
import runtime ".."
// core:os 经根包 storage_os_* 平台层使用(js 目标无 core:os)

FontCharacter :: struct { GlyphIndex:int, Width,Height:int, Advance:f32, Offset:spatial.Vec2, Scale:f32, Visible:bool }
Font :: struct { Data:[dynamic]u8, Backend:stb.StbFont, Ascent,Descent,LineGap:int, Disposed:bool }
FontMake :: proc(data:[]u8)->Font{f:=Font{};for b in data{append(&f.Data,b)};f.Backend=stb.StbFontInit(f.Data[:]);f.Ascent,f.Descent,f.LineGap=stb.StbFontMetrics(&f.Backend);if f.LineGap<=0&&f.Descent<0{f.LineGap=-f.Descent;f.Descent=0};return f}
FontLoadFile :: proc(path:string)->Font{data:=runtime.storage_os_read_file(path,context.temp_allocator);if data==nil{return {}};return FontMake(data)}
FontHeight :: proc(f:^Font)->int{return f.Ascent-f.Descent}
FontLineHeight :: proc(f:^Font)->int{return f.Ascent-f.Descent+f.LineGap}
FontGetGlyphIndex :: proc(f:^Font,codepoint:int)->int{return stb.StbFontGlyph(&f.Backend,codepoint)}
FontGetScale :: proc(f:^Font,size:f32)->f32{return stb.StbFontScale(&f.Backend,size)}
FontGetKerning :: proc(f:^Font,a,b:int,scale:f32)->f32{return stb.StbFontKerning(&f.Backend,a,b,scale)}
FontGetCharacter :: proc(f:^Font,codepoint:int,scale:f32)->FontCharacter{glyph:=FontGetGlyphIndex(f,codepoint);w,h,adv,ox,oy,visible:=stb.StbFontCharacter(&f.Backend,glyph,scale);return FontCharacter{GlyphIndex=glyph,Width=w,Height=h,Advance=adv,Offset=spatial.Vec2{ox,oy},Scale=scale,Visible=visible}}
FontGetCharacterOfGlyph :: proc(f:^Font,glyph:int,scale:f32)->FontCharacter{w,h,adv,ox,oy,visible:=stb.StbFontCharacter(&f.Backend,glyph,scale);return FontCharacter{GlyphIndex=glyph,Width=w,Height=h,Advance=adv,Offset=spatial.Vec2{ox,oy},Scale=scale,Visible=visible}}
FontGetKerningBetweenGlyphs :: proc(f:^Font,a,b:int,scale:f32)->f32{return stb.StbFontKerning(&f.Backend,a,b,scale)}
FontRasterize :: proc(f:^Font,codepoint:int,size:f32)->[dynamic]u8{glyph:=FontGetGlyphIndex(f,codepoint);ch:=FontGetCharacter(f,codepoint,size);return stb.StbFontRasterize(&f.Backend,glyph,ch.Width,ch.Height,size)}
FontGetPixels :: proc(f:^Font,ch:FontCharacter,destination:[]runtime.Color)->bool{if !ch.Visible||len(destination)<ch.Width*ch.Height{return false};pixels:=stb.StbFontRasterize(&f.Backend,ch.GlyphIndex,ch.Width,ch.Height,ch.Scale);for i in 0..<ch.Width*ch.Height{destination[i]=runtime.Color{255,255,255,pixels[i]}};return true}
FontGetImage :: proc(f:^Font,ch:FontCharacter)->Image{if !ch.Visible{return {}};img:=ImageMake(ch.Width,ch.Height);_ = FontGetPixels(f,ch,img.Pixels[:]);return img}
FontGetImageForCodepoint :: proc(f:^Font,codepoint:int,scale:f32)->Image{ch:=FontGetCharacter(f,codepoint,scale);return FontGetImage(f,ch)}
FontDispose :: proc(f:^Font){if f==nil{return};delete(f.Data);f.Backend=stb.StbFont{};f.Disposed=true}
