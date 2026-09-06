package foster_images

import runtime ".."
import spatial "../Spatial"
import qoi "../Internal/ThirdParty"
import "core:c"
import "core:os"
import "core:strings"
import stbi "vendor:stb/image"

Image :: struct { Width, Height: int, Pixels: [dynamic]runtime.Color, IsDisposed: bool }
ImageMake :: proc(width, height: int, fill := runtime.Transparent) -> Image { i:=Image{Width=width,Height=height}; resize(&i.Pixels,width*height); for n in 0..<len(i.Pixels) { i.Pixels[n]=fill }; return i }
ImageFromPixels :: proc(width,height:int,pixels:[]runtime.Color)->Image{i:=Image{Width=width,Height=height}; for p in pixels { append(&i.Pixels,p) }; return i}
ImageFromQoi :: proc(data:[]u8)->Image{desc:qoi.QoiDesc={}; bytes:=qoi.QoiDecode(data,4,&desc); if len(bytes)==0{return {}}; pixels:[dynamic]runtime.Color = {}; resize(&pixels,int(desc.Width*desc.Height)); for n in 0..<len(pixels){pixels[n]=runtime.Color{bytes[n*4],bytes[n*4+1],bytes[n*4+2],bytes[n*4+3]}}; return ImageFromPixels(int(desc.Width),int(desc.Height),pixels[:])}
ImageToQoi :: proc(i:^Image)->[dynamic]u8 { bytes:[dynamic]u8={}; resize(&bytes,len(i.Pixels)*4); for n in 0..<len(i.Pixels) { c:=i.Pixels[n]; bytes[n*4]=c.R; bytes[n*4+1]=c.G; bytes[n*4+2]=c.B; bytes[n*4+3]=c.A }; return qoi.QoiEncode(bytes[:],u32(i.Width),u32(i.Height),4) }
ImageFromEncoded :: proc(data:[]u8)->Image {
	if qoi.QoiIsFormat(data) { return ImageFromQoi(data) }
	if len(data)==0 { return {} }
	w,h,components:c.int=0,0,0
	ptr:=stbi.load_from_memory(&data[0],c.int(len(data)),&w,&h,&components,4)
	if ptr==nil || w<=0 || h<=0 { return {} }
	result:=ImageMake(int(w),int(h)); total:=int(w*h*4)
	for n in 0..<total { byte_index:=n; pixel:=n/4; channel:=n%4; switch channel { case 0: result.Pixels[pixel].R=ptr[byte_index]; case 1: result.Pixels[pixel].G=ptr[byte_index]; case 2: result.Pixels[pixel].B=ptr[byte_index]; case 3: result.Pixels[pixel].A=ptr[byte_index] } }
	stbi.image_free(ptr)
	return result
}
ImageLoadFile :: proc(path:string)->Image { data,err:=os.read_entire_file_from_path(path,context.temp_allocator); if err != nil{return {}}; return ImageFromEncoded(data) }
ImageWritePng :: proc(i:^Image,path:string)->bool { if i.Width<=0||i.Height<=0||len(i.Pixels)==0{return false}; cstr,_:=strings.clone_to_cstring(path,context.temp_allocator); return stbi.write_png(cstr,c.int(i.Width),c.int(i.Height),4,raw_data(i.Pixels),c.int(i.Width*4)) != 0 }
ImageWriteQoi :: proc(i:^Image,path:string)->bool { data:=ImageToQoi(i); if len(data)==0{return false}; return os.write_entire_file_from_bytes(path,data[:]) == nil }
ImageLoad :: ImageLoadFile
ImageWritePNG :: ImageWritePng
ImagePixelCount :: proc(i:^Image)->int{return i.Width*i.Height}
ImageBounds :: proc(i:^Image)->spatial.RectInt{return spatial.RectInt{0,0,i.Width,i.Height}}
ImageWidth :: proc(i:^Image)->int{return i.Width}
ImageHeight :: proc(i:^Image)->int{return i.Height}
ImageGetPixel :: proc(i:^Image,x,y:int)->runtime.Color{if x<0||y<0||x>=i.Width||y>=i.Height{return runtime.Transparent};return i.Pixels[x+y*i.Width]}
ImageGetPixelIndex :: proc(i:^Image,index:int)->runtime.Color{if i==nil||index<0||index>=len(i.Pixels){return runtime.Transparent};return i.Pixels[index]}
ImageSetPixel :: proc(i:^Image,x,y:int,c:runtime.Color){if x>=0&&y>=0&&x<i.Width&&y<i.Height{i.Pixels[x+y*i.Width]=c}}
ImageSetPixelIndex :: proc(i:^Image,index:int,c:runtime.Color){if i!=nil&&index>=0&&index<len(i.Pixels){i.Pixels[index]=c}}
ImageData :: proc(i:^Image)->[]runtime.Color{return i.Pixels[:]}
ImageSize :: proc(i:^Image)->runtime.Point2{if i==nil{return {}};return runtime.Point2{i.Width,i.Height}}
ImageClear :: proc(i:^Image){clear(&i.Pixels);i.Width=0;i.Height=0;i.IsDisposed=true}
ImageCopyPixels :: proc(dst:^Image,src:^Image,source_rect:=spatial.RectInt{0,0,0,0},destination:=runtime.Point2{}) { r:=source_rect;if r.Width==0 {r=ImageBounds(src)};for y in 0..<r.Height {for x in 0..<r.Width {ImageSetPixel(dst,destination.X+x,destination.Y+y,ImageGetPixel(src,r.X+x,r.Y+y))}} }
ImageCopyPixelsBlend :: proc(dst:^Image,src:^Image,source_rect:spatial.RectInt,destination:runtime.Point2,blend:proc(a,b:runtime.Color)->runtime.Color=nil){r:=source_rect;if r.Width==0{r=ImageBounds(src)};for y in 0..<r.Height{for x in 0..<r.Width{c:=ImageGetPixel(src,r.X+x,r.Y+y);if blend!=nil{c=blend(ImageGetPixel(dst,destination.X+x,destination.Y+y),c)};ImageSetPixel(dst,destination.X+x,destination.Y+y,c)}}}
ImagePremultiply :: proc(i:^Image){if i==nil{return};for n in 0..<len(i.Pixels){i.Pixels[n]=runtime.Premultiply(i.Pixels[n])}}
