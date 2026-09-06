package foster_graphics

import images "../Images"
import spatial "../Spatial"
import structs "./Structs"
import runtime ".."
import "core:mem"
import "core:unicode/utf8"

SpriteFontCharacter :: struct {
	Codepoint: int,
	Subtexture: structs.Subtexture,
	Advance: f32,
	Offset: spatial.Vec2,
	Exists: bool,
}
SpriteFontKerning :: struct { First, Second: int, Advance: f32 }
SpriteFont :: struct {
	GraphicsDevice: ^runtime.GraphicsDevice,
	Name: string,
	Image: ^images.Image,
	Texture: ^runtime.Texture,
	GeneratedTextures: [dynamic]^runtime.Texture,
	OwnsImage: bool,
	Characters: [dynamic]SpriteFontCharacter,
	Kerning: [dynamic]SpriteFontKerning,
	LineHeight: f32,
	Ascent: f32,
	Descent: f32,
	LineGap: f32,
	Size: f32,
	KerningFont: ^images.Font,
	Material: runtime.Material,
	Sampler: runtime.TextureSampler,
	HasMaterial: bool,
	NewlineCharacters: [dynamic]rune,
	WordbreakCharacters: [dynamic]rune,
}
SpriteFontAscii :: proc() -> [96]int { result:[96]int = {}; for i in 0..<len(result) { result[i]=i+32 }; return result }

SpriteFontMake :: proc(font:^images.Font,size:f32=16,codepoints:[]int=nil)->SpriteFont {
	result:=SpriteFont{Size=size,KerningFont=font};append(&result.NewlineCharacters,'\n');append(&result.WordbreakCharacters,'\n',' ')
	if font==nil{return result}
	scale:=images.FontGetScale(font,size)
	result.Ascent=f32(font.Ascent)*scale; result.Descent=f32(font.Descent)*scale; result.LineGap=f32(font.LineGap)*scale; result.LineHeight=result.Ascent-result.Descent+result.LineGap
	result.Image=new(images.Image); result.Image^=images.ImageMake(2048,2048); result.OwnsImage=true
	points:=codepoints;if len(points)==0 { ascii:=SpriteFontAscii(); points=ascii[:] }
	x,y,row:=0,0,0
	for cp in points {
		ch:=images.FontGetCharacter(font,cp,scale); c:=SpriteFontCharacter{Codepoint=cp,Advance=ch.Advance,Offset=ch.Offset,Exists=true}
		if ch.Visible && ch.Width>0 && ch.Height>0 {
			if x+ch.Width+1>=result.Image.Width { x=0; y+=row+1; row=0 }
			// CPU 图集装不下时跳过该字形的位图(但保留字符注册): SpriteFontMakeGPU 会
			// 用 Packer 重新栅格化, 不依赖这张图; 旧行为是 break, 会静默丢弃后续全部码点
			if y+ch.Height<result.Image.Height {
				bmp:=images.FontRasterize(font,cp,scale)
				for py in 0..<ch.Height {
					for px in 0..<ch.Width {
						images.ImageSetPixel(result.Image,x+px,y+py,images.Color{255,255,255,bmp[py*ch.Width+px]})
					}
				}
				c.Subtexture=structs.Subtexture{Source=spatial.Rect{f32(x),f32(y),f32(ch.Width),f32(ch.Height)},Frame=spatial.Rect{-ch.Offset[0],-ch.Offset[1],f32(ch.Width),f32(ch.Height)}}
				x+=ch.Width+1; if ch.Height>row {row=ch.Height}
			}
		}
		append(&result.Characters,c)
	}
	return result
}

SpriteFontMakeGPU :: proc(device:^runtime.GraphicsDevice, font:^images.Font, size:f32=16, codepoints:[]int=nil, premultiply_alpha:bool=true)->SpriteFont {
	result := SpriteFontMake(font, size, codepoints)
	result.GraphicsDevice = device
	if device == nil || font == nil || len(result.Characters) == 0 do return result
	if result.Image != nil && result.OwnsImage { images.ImageClear(result.Image); free(result.Image); result.Image=nil; result.OwnsImage=false }
	packer := images.PackerMake()
	packer.MaxSize = 8192
	packer.Padding = 1
	packer.Trim = true
	packer_indices: [dynamic]int = {}
	for i := 0; i < len(result.Characters); i += 1 {
		ch := result.Characters[i]
		if !ch.Exists do continue
		glyph := images.FontGetImage(font, images.FontGetCharacter(font, ch.Codepoint, images.FontGetScale(font, size)))
		if glyph.Width <= 0 || glyph.Height <= 0 do continue
		idx := images.PackerAdd(&packer, "", glyph)
		append(&packer_indices, i)
		_ = idx
	}
	out := images.PackerPack(&packer)
	for page in out.Pages {
		page_value := page
		if premultiply_alpha do images.ImagePremultiply(&page_value)
		tex := new(runtime.Texture)
		tex^ = TextureFromImage(device, &page_value, "SpriteFont")
		append(&result.GeneratedTextures, tex)
	}
	for entry in out.Entries {
		if entry.Index < 0 || entry.Index >= len(packer_indices) || entry.Page < 0 || entry.Page >= len(result.GeneratedTextures) do continue
		character_index := packer_indices[entry.Index]
		old := result.Characters[character_index]
		source := spatial.Rect{f32(entry.Source.X), f32(entry.Source.Y), f32(entry.Source.Width), f32(entry.Source.Height)}
		frame := spatial.Rect{f32(entry.Frame.X), f32(entry.Frame.Y), f32(entry.Frame.Width), f32(entry.Frame.Height)}
		old.Subtexture = structs.SubtextureMake(result.GeneratedTextures[entry.Page], source, frame)
		result.Characters[character_index] = old
	}
	if len(result.GeneratedTextures) > 0 { result.Texture = result.GeneratedTextures[0] }
	return result
}
SpriteFontFromMsdf :: proc(device:^runtime.GraphicsDevice,msdf:^images.MsdfFont)->SpriteFont{result:=SpriteFont{GraphicsDevice=device};if msdf==nil{return result};result.Size=msdf.Size;result.Ascent=msdf.Ascent;result.Descent=msdf.Descent;result.LineGap=msdf.LineGap;result.LineHeight=msdf.LineHeight;result.Image=&msdf.Image;result.Sampler=runtime.TextureSamplerMake(runtime.TextureFilter.Linear,runtime.TextureWrap.Clamp);append(&result.NewlineCharacters,'\n');append(&result.WordbreakCharacters,'\n',' ');for k in msdf.Kerning{append(&result.Kerning,SpriteFontKerning{k.First,k.Second,k.Advance})};if device!=nil{tex:=TextureFromImage(device,&msdf.Image,"MsdfFont");result.Texture=new(runtime.Texture);result.Texture^=tex;append(&result.GeneratedTextures,result.Texture);if device.Defaults.Initialized{result.Material=runtime.MaterialClone(&device.Defaults.MsdfMaterial);distance:=[1]f32{msdf.DistanceRange};uniform:[]u8=make([]u8,size_of(distance));mem.copy(raw_data(uniform),raw_data(distance[:]),size_of(distance));runtime.MaterialStageSetUniformBuffer(&result.Material.Fragment,uniform,0);result.HasMaterial=true}};for ch in msdf.Characters{source:=ch.SourceRect;frame:=spatial.Rect{-ch.Offset[0],-ch.Offset[1],source.Width,source.Height};sub:=structs.SubtextureMake(result.Texture,source,frame);append(&result.Characters,SpriteFontCharacter{ch.Codepoint,sub,ch.Advance,ch.Offset,true})};return result}
SpriteFontFindCharacter :: proc(font:^SpriteFont,codepoint:int)->(SpriteFontCharacter,bool){if font==nil{return {},false};for c in font.Characters{if c.Codepoint==codepoint{return c,c.Exists}};return {},false}
SpriteFontGetCharacter :: proc(font:^SpriteFont,codepoint:int)->SpriteFontCharacter{c,_:=SpriteFontFindCharacter(font,codepoint);return c}
SpriteFontTryGetCharacter :: proc(font:^SpriteFont, codepoint:int) -> (SpriteFontCharacter, bool) { return SpriteFontFindCharacter(font, codepoint) }
SpriteFontTryGetCharacterRune :: proc(font:^SpriteFont, r:rune) -> (SpriteFontCharacter, bool) { return SpriteFontFindCharacter(font, int(r)) }
sprite_font_is_newline :: proc(font:^SpriteFont, r:rune) -> bool { if font == nil { return r == '\n' }; for c in font.NewlineCharacters { if c == r { return true } }; return false }
sprite_font_is_wordbreak :: proc(font:^SpriteFont, r:rune) -> bool { if font == nil { return r == '\n' || r == ' ' }; for c in font.WordbreakCharacters { if c == r { return true } }; return false }
SpriteFontAddCharacter :: proc(font:^SpriteFont,character:SpriteFontCharacter){if font==nil{return};for i:=0;i<len(font.Characters);i+=1{if font.Characters[i].Codepoint==character.Codepoint{font.Characters[i]=character;return}};append(&font.Characters,character)}
SpriteFontBindTexture :: proc(font:^SpriteFont,texture:^runtime.Texture){if font==nil{return};for i:=0;i<len(font.Characters);i+=1{c:=font.Characters[i];if c.Subtexture.Source.Width>0&&c.Subtexture.Source.Height>0{c.Subtexture=structs.SubtextureMake(texture,c.Subtexture.Source,c.Subtexture.Frame);font.Characters[i]=c}}}
SpriteFontSetKerning :: proc(font:^SpriteFont, a,b:int, advance:f32) { if font == nil do return; for i:=0; i<len(font.Kerning); i+=1 { if font.Kerning[i].First==a && font.Kerning[i].Second==b { font.Kerning[i].Advance=advance; return } }; append(&font.Kerning, SpriteFontKerning{a,b,advance}) }
SpriteFontDispose :: proc(font:^SpriteFont){if font==nil{return};for tex in font.GeneratedTextures{if tex!=nil{runtime.TextureDispose(tex);free(tex)}};clear(&font.GeneratedTextures);font.Texture=nil;if font.Image!=nil&&font.OwnsImage{images.ImageClear(font.Image);free(font.Image)};font.Image=nil;clear(&font.Characters);clear(&font.Kerning);clear(&font.NewlineCharacters);clear(&font.WordbreakCharacters);font.HasMaterial=false}
SpriteFontGetKerning :: proc(font:^SpriteFont,a,b:int,size:f32=0)->f32{if font==nil{return 0};s:=size;if s==0{s=font.Size};for k in font.Kerning{if k.First==a&&k.Second==b{if font.Size>0{return k.Advance*(s/font.Size)};return k.Advance}};if font.KerningFont==nil{return 0};scale:=images.FontGetScale(font.KerningFont,s);return images.FontGetKerning(font.KerningFont,a,b,scale)}
SpriteFontWidthOfLine :: proc(font:^SpriteFont,text:string,size:f32=0)->f32{if font==nil{return 0};s:=size;if s==0{s=font.Size};factor:=f32(1);if font.Size>0{factor=s/font.Size};width:f32=0;last:=0;for r in text{if sprite_font_is_newline(font,r){break};cp:=int(r);if c,ok:=SpriteFontFindCharacter(font,cp);ok{if last!=0{width+=SpriteFontGetKerning(font,last,cp,s)};width+=c.Advance};last=cp};return width*factor}
SpriteFontWidthOf :: proc(font:^SpriteFont,text:string,size:f32=0)->f32{if font==nil{return 0};s:=size;if s==0{s=font.Size};maxw,cur:f32=0,0;last:=0;for r in text{if sprite_font_is_newline(font,r){if cur>maxw{maxw=cur};cur=0;last=0;continue};cp:=int(r);if c,ok:=SpriteFontFindCharacter(font,cp);ok{if last!=0{cur+=SpriteFontGetKerning(font,last,cp,s)};cur+=c.Advance};last=cp};if cur>maxw{maxw=cur};if font.Size>0{return maxw*(s/font.Size)};return maxw}
SpriteFontHeightOf :: proc(font:^SpriteFont,text:string,size:f32=0)->f32{if font==nil||len(text)==0{return 0};s:=size;if s==0{s=font.Size};lines:=1;for r in text{if sprite_font_is_newline(font,r){lines+=1}};if font.Size>0{return (font.LineHeight-font.LineGap+f32(lines-1)*font.LineHeight)*(s/font.Size)};return font.LineHeight*f32(lines)}
SpriteFontSizeOf :: proc(font:^SpriteFont,text:string,size:f32=0)->spatial.Vec2{return spatial.Vec2{SpriteFontWidthOf(font,text,size),SpriteFontHeightOf(font,text,size)}}
SpriteFontHeight :: proc(font:^SpriteFont)->f32{if font==nil{return 0};return font.Ascent-font.Descent}
SpriteFontMeasure :: SpriteFontSizeOf
sprite_font_draw_impl :: proc(batch:^Batcher,font:^SpriteFont,text:string,position,justify:spatial.Vec2,size:f32,color:runtime.Color){if batch==nil||font==nil{return};scale:=f32(1);if font.Size>0{scale=size/font.Size};BatcherPushMatrix2D(batch,position,spatial.Vec2{scale,scale},0,true);if font.HasMaterial{BatcherPushMaterial(batch,&font.Material)};BatcherPushSampler(batch,font.Sampler);prev_texture:=batch.Texture;at:=spatial.Vec2{0,font.Ascent};just_scale:=f32(1);if font.Size>0&&size>0{just_scale=font.Size/size};if justify[0]!=0{at[0]-=justify[0]*SpriteFontWidthOfLine(font,text,size)*just_scale};if justify[1]!=0{at[1]-=justify[1]*SpriteFontHeightOf(font,text,size)*just_scale};last:=0;for r in text{if sprite_font_is_newline(font,r){at[0]=0;at[1]+=font.LineHeight;last=0;continue};cp:=int(r);if c,ok:=SpriteFontFindCharacter(font,cp);ok{if last!=0{at[0]+=SpriteFontGetKerning(font,last,cp,size)};if c.Subtexture.Texture!=nil{BatcherImage(batch,c.Subtexture,spatial.Vec2{at[0]+c.Offset[0],at[1]+c.Offset[1]},color)};at[0]+=c.Advance};last=cp};batch.Texture=prev_texture;BatcherPopSampler(batch);if font.HasMaterial{BatcherPopMaterial(batch)};BatcherPopMatrixStack(batch)}
sprite_font_draw_simple :: proc(batch:^Batcher,font:^SpriteFont,text:string,position:spatial.Vec2,color:runtime.Color){sprite_font_draw_impl(batch,font,text,position,{},font.Size,color)}
sprite_font_draw_sized :: proc(batch:^Batcher,font:^SpriteFont,text:string,position:spatial.Vec2,size:f32,color:runtime.Color){sprite_font_draw_impl(batch,font,text,position,{},size,color)}
sprite_font_draw_justified :: proc(batch:^Batcher,font:^SpriteFont,text:string,position,justify:spatial.Vec2,color:runtime.Color){sprite_font_draw_impl(batch,font,text,position,justify,font.Size,color)}
sprite_font_draw_justified_sized :: proc(batch:^Batcher,font:^SpriteFont,text:string,position,justify:spatial.Vec2,size:f32,color:runtime.Color){sprite_font_draw_impl(batch,font,text,position,justify,size,color)}
SpriteFontDraw :: proc{sprite_font_draw_simple, sprite_font_draw_sized, sprite_font_draw_justified, sprite_font_draw_justified_sized}

SpriteFontTextRange :: struct { Start, Length: int }
SpriteFontWidthOfWord :: proc(font:^SpriteFont,text:string,size:f32=0)->(width:f32,length:int){if font==nil{return 0,0};s:=size;if s==0{s=font.Size};last:=0;for length<len(text){r,w:=utf8.decode_rune_in_string(text[length:]);if sprite_font_is_wordbreak(font,r){break};cp:=int(r);if c,ok:=SpriteFontFindCharacter(font,cp);ok{if last!=0{width+=SpriteFontGetKerning(font,last,cp,s)};width+=c.Advance};last=cp;length+=w;if w<=0{length+=1}};if font.Size>0{width*=s/font.Size};return}
SpriteFontWrapText :: proc(font:^SpriteFont,text:string,max_width:f32,size:f32=0)->[dynamic]SpriteFontTextRange{result:[dynamic]SpriteFontTextRange={};if font==nil||len(text)==0{return result};line_start:=0;line_width:f32=0;cursor:=0;for cursor<len(text){r,w:=utf8.decode_rune_in_string(text[cursor:]);if w<=0{w=1};if sprite_font_is_newline(font,r){append(&result,SpriteFontTextRange{line_start,cursor-line_start});line_start=cursor+w;cursor=line_start;line_width=0;continue};word_width,word_len:=SpriteFontWidthOfWord(font,text[cursor:],size);if line_width>0&&max_width>0&&line_width+word_width>max_width{append(&result,SpriteFontTextRange{line_start,cursor-line_start});line_start=cursor;line_width=0};line_width+=word_width;cursor+=word_len;if cursor<len(text){next,_:=utf8.decode_rune_in_string(text[cursor:]);if sprite_font_is_wordbreak(font,next){line_width+=SpriteFontWidthOfLine(font,text[cursor:cursor+1],size);cursor+=1}};if word_len==0{cursor+=w}};if line_start<len(text){append(&result,SpriteFontTextRange{line_start,len(text)-line_start})};return result}
sprite_font_draw_wrapped_simple :: proc(batch:^Batcher,font:^SpriteFont,text:string,position:spatial.Vec2,max_width:f32,color:runtime.Color){if font==nil{return};line:=0;for range in SpriteFontWrapText(font,text,max_width,font.Size){line_text:=text[range.Start:range.Start+range.Length];SpriteFontDraw(batch,font,line_text,spatial.Vec2{position[0],position[1]+f32(line)*font.LineHeight},color);line+=1}}
sprite_font_draw_wrapped_justified :: proc(batch:^Batcher,font:^SpriteFont,text:string,position,justify:spatial.Vec2,max_width:f32,color:runtime.Color){if font==nil{return};line:=0;for range in SpriteFontWrapText(font,text,max_width,font.Size){line_text:=text[range.Start:range.Start+range.Length];SpriteFontDraw(batch,font,line_text,spatial.Vec2{position[0],position[1]+f32(line)*font.LineHeight},justify,color);line+=1}}
sprite_font_draw_wrapped_sized :: proc(batch:^Batcher,font:^SpriteFont,text:string,position:spatial.Vec2,max_width,size:f32,color:runtime.Color){if font==nil{return};line:=0;for range in SpriteFontWrapText(font,text,max_width,size){line_text:=text[range.Start:range.Start+range.Length];SpriteFontDraw(batch,font,line_text,spatial.Vec2{position[0],position[1]+f32(line)*font.LineHeight},size,color);line+=1}}
sprite_font_draw_wrapped_justified_sized :: proc(batch:^Batcher,font:^SpriteFont,text:string,position,justify:spatial.Vec2,max_width,size:f32,color:runtime.Color){if font==nil{return};line:=0;for range in SpriteFontWrapText(font,text,max_width,size){line_text:=text[range.Start:range.Start+range.Length];SpriteFontDraw(batch,font,line_text,spatial.Vec2{position[0],position[1]+f32(line)*font.LineHeight},justify,size,color);line+=1}}
SpriteFontDrawWrapped :: proc{sprite_font_draw_wrapped_simple, sprite_font_draw_wrapped_justified, sprite_font_draw_wrapped_sized, sprite_font_draw_wrapped_justified_sized}
