package foster_framework

import "core:math"
import "core:mem"

// ===== merged from Graphics/Batcher.odin =====


BatcherMode :: enum { Normal, Wash, Fill }
BatcherModeState :: struct { Mode: BatcherMode, Color: Color }
BatcherBatch :: struct {
	IndexStart: int,
	IndexCount: int,
	Material: ^Material,
	Texture: ^Texture,
	Sampler: TextureSampler,
	Blend: BlendMode,
	Layer: int,
	Scissor: RectInt,
	HasScissor: bool,
}
Batcher :: struct {
	Vertices: [dynamic]BatcherVertex,
	Indices: [dynamic]int,
	Matrix: [16]f32,
	Mode: BatcherMode,
	ModeColor: Color,
	Texture: ^Texture,
	Sampler: TextureSampler,
	Blend: BlendMode,
	Layer: int,
	Scissor: RectInt,
	HasScissor: bool,
	MatrixStack: [dynamic][16]f32,
	SamplerStack: [dynamic]TextureSampler,
	BlendStack: [dynamic]BlendMode,
	LayerStack: [dynamic]int,
	ScissorStack: [dynamic]RectInt,
	ScissorEnabledStack: [dynamic]bool,
	MaterialStack: [dynamic]^Material,
	ModeStack: [dynamic]BatcherModeState,
	VertexStorageBuffers: [dynamic]^StorageBuffer,
	FragmentStorageBuffers: [dynamic]^StorageBuffer,
	Batches: [dynamic]BatcherBatch,
	GraphicsDevice: ^GraphicsDevice,
	Mesh: Mesh,
	VertexShader: Shader,
	FragmentShader: Shader,
	Material: Material,
	HasGPU: bool,
	HasMaterial: bool,
}

batcher_identity :: proc() -> [16]f32 { return [16]f32{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1} }
BatcherMake :: proc() -> Batcher { return Batcher{Matrix=batcher_identity(), Mode=.Normal, ModeColor=Color{255,0,0,0}, Sampler=TextureSamplerMake(TextureFilter.Nearest,TextureWrap.Clamp), Blend=BlendModePremultiply} }
batcher_transform :: proc(b:^Batcher, p:Vec2) -> Vec2 { m:=b.Matrix; return Vec2{p[0]*m[0]+p[1]*m[4]+m[12],p[0]*m[1]+p[1]*m[5]+m[13]} }
batcher_mode_color :: proc(mode:BatcherMode) -> Color { switch mode { case .Normal:return Color{255,0,0,0}; case .Wash:return Color{0,255,0,0}; case .Fill:return Color{0,0,255,0} }; return Color{255,0,0,0} }
batcher_clone_material :: proc(source:^Material) -> ^Material { if source == nil do return nil; result:=new(Material); MaterialInit(result); MaterialCopyTo(source,result); return result }
batcher_free_material :: proc(material:^Material) { if material == nil do return; for i in 0..<len(material.Vertex.UniformBuffers) { delete(material.Vertex.UniformBuffers[i]); delete(material.Fragment.UniformBuffers[i]); UniformBufferDispose(&material.Vertex.UniformBufferObjects[i]); UniformBufferDispose(&material.Fragment.UniformBufferObjects[i]) }; free(material) }
batcher_free_batches :: proc(b:^Batcher) { for batch in b.Batches { batcher_free_material(batch.Material) } }
batcher_ensure_batch :: proc(b:^Batcher) {
	start := len(b.Indices)
	if len(b.Batches) > 0 {
		last := &b.Batches[len(b.Batches)-1]
		if last.Texture == b.Texture && last.Sampler == b.Sampler && last.Blend == b.Blend && last.Layer == b.Layer && last.HasScissor == b.HasScissor && (!b.HasScissor || last.Scissor == b.Scissor) && last.Material != nil do return
		last.IndexCount = start - last.IndexStart
	}
	append(&b.Batches, BatcherBatch{IndexStart=start, IndexCount=0, Material=batcher_clone_material(&b.Material), Texture=b.Texture, Sampler=b.Sampler, Blend=b.Blend, Layer=b.Layer, Scissor=b.Scissor, HasScissor=b.HasScissor})
}
batcher_push_vertex :: proc(b:^Batcher,p:Vec2,uv:[2]f32,color:Color) { batcher_ensure_batch(b); append(&b.Vertices,BatcherVertex{Pos=batcher_transform(b,p),Tex=uv,Col=color,Mode=b.ModeColor}) }
batcher_push_tri :: proc(b:^Batcher,a,bp,c:Vec2,color:Color,uv0,uv1,uv2:[2]f32) { base:=len(b.Vertices); batcher_push_vertex(b,a,uv0,color); batcher_push_vertex(b,bp,uv1,color); batcher_push_vertex(b,c,uv2,color); append(&b.Indices,base,base+1,base+2) }
BatcherTriangleCount :: proc(b:^Batcher)->int{return len(b.Indices)/3}
BatcherVertexCount :: proc(b:^Batcher)->int{return len(b.Vertices)}
BatcherIndexCount :: proc(b:^Batcher)->int{return len(b.Indices)}
BatcherBatchCount :: proc(b:^Batcher)->int { if b == nil { return 0 }; return len(b.Batches) }
BatcherClear :: proc(b:^Batcher){clear(&b.Vertices);clear(&b.Indices);batcher_free_batches(b);clear(&b.Batches);clear(&b.VertexStorageBuffers);clear(&b.FragmentStorageBuffers);for material in b.MaterialStack { batcher_free_material(material) };clear(&b.MaterialStack);clear(&b.ModeStack);b.Matrix=batcher_identity();b.Mode=.Normal;b.ModeColor=batcher_mode_color(.Normal);b.Texture=nil;b.Layer=0;b.HasScissor=false;clear(&b.MatrixStack);clear(&b.SamplerStack);clear(&b.BlendStack);clear(&b.LayerStack);clear(&b.ScissorStack);clear(&b.ScissorEnabledStack)}

BatcherInit :: proc(b:^Batcher,device:^GraphicsDevice,name:string=""){b^=BatcherMake();b.GraphicsDevice=device;if device!=nil{MeshInitTyped(BatcherVertex,&b.Mesh,device,IndexFormat.ThirtyTwo,name);InitDefaultBatchMaterial(&b.Material,&b.VertexShader,&b.FragmentShader,device);b.HasGPU=true;b.HasMaterial=true}}
BatcherDispose :: proc(b:^Batcher){if b.HasGPU{MeshDispose(&b.Mesh)};batcher_free_batches(b);for material in b.MaterialStack { batcher_free_material(material) };b.HasGPU=false;b.HasMaterial=false;clear(&b.Vertices);clear(&b.Indices);clear(&b.Batches);clear(&b.MaterialStack);clear(&b.ModeStack)}
BatcherUpload :: proc(b:^Batcher){if !b.HasGPU||len(b.Vertices)==0||len(b.Indices)==0{return};MeshClear(&b.Mesh);MeshSetVerticesTyped(BatcherVertex,&b.Mesh,b.Vertices[:]);indices:[dynamic]i32 = {};for v in b.Indices{append(&indices,i32(v))};MeshSetIndicesTyped(i32,&b.Mesh,indices[:]);delete(indices)}
batcher_sort_batches :: proc(b:^Batcher) { for i:=1; i<len(b.Batches); i+=1 { current:=b.Batches[i]; j:=i-1; for j>=0 && b.Batches[j].Layer < current.Layer { b.Batches[j+1]=b.Batches[j]; j-=1 }; b.Batches[j+1]=current } }
batcher_render_with_matrix :: proc(b:^Batcher,target:DrawableTarget,matrix_arg:[16]f32){if !b.HasGPU||b.GraphicsDevice==nil||len(b.Indices)==0{return};BatcherUpload(b);m:=matrix_arg;uniform:[size_of([16]f32)]u8;mem.copy(raw_data(uniform[:]),&m,size_of(m));if len(b.Batches)==0{batcher_ensure_batch(b)};if len(b.Batches)>0{b.Batches[len(b.Batches)-1].IndexCount=len(b.Indices)-b.Batches[len(b.Batches)-1].IndexStart};batcher_sort_batches(b);for i:=0;i<len(b.Batches);i+=1{batch:=b.Batches[i];count:=batch.IndexCount;if count<=0{continue};mat:=batch.Material;if mat==nil{mat=&b.Material};MaterialStageSetUniformBuffer(&mat.Vertex,uniform[:],0);mat.Fragment.Samplers[0]=BoundSampler{Texture=batch.Texture,Sampler=batch.Sampler};cmd:DrawCommand;DrawCommandFromMesh(&cmd,target,&b.Mesh,mat);cmd.IndexOffset=batch.IndexStart;cmd.IndexCount=count;cmd.VertexCount=0;cmd.BlendMode=batch.Blend;cmd.HasScissor=batch.HasScissor;cmd.Scissor=batch.Scissor;append(&cmd.VertexStorageBuffers,..b.VertexStorageBuffers[:]);append(&cmd.FragmentStorageBuffers,..b.FragmentStorageBuffers[:]);GraphicsDeviceDraw(b.GraphicsDevice,&cmd);DrawCommandDispose(&cmd)}}
batcher_render_default :: proc(b:^Batcher,target:DrawableTarget){w:=f32(target.WidthInPixels);h:=f32(target.HeightInPixels);if w<=0||h<=0{return};m:=[16]f32{2/w,0,0,0,0,-2/h,0,0,0,0,1,0,-1,1,0,1};batcher_render_with_matrix(b,target,m)}
batcher_render_options :: proc(b:^Batcher,target:DrawableTarget,viewport,scissor:RectInt){if !b.HasGPU||b.GraphicsDevice==nil||len(b.Indices)==0{return};BatcherUpload(b);w:=f32(target.WidthInPixels);h:=f32(target.HeightInPixels);if w<=0||h<=0{return};m:=[16]f32{2/w,0,0,0,0,-2/h,0,0,0,0,1,0,-1,1,0,1};uniform:[size_of([16]f32)]u8;mem.copy(raw_data(uniform[:]),&m,size_of(m));if len(b.Batches)==0{batcher_ensure_batch(b)};if len(b.Batches)>0{b.Batches[len(b.Batches)-1].IndexCount=len(b.Indices)-b.Batches[len(b.Batches)-1].IndexStart};batcher_sort_batches(b);for i:=0;i<len(b.Batches);i+=1{batch:=b.Batches[i];count:=batch.IndexCount;if count<=0{continue};mat:=batch.Material;if mat==nil{mat=&b.Material};MaterialStageSetUniformBuffer(&mat.Vertex,uniform[:],0);mat.Fragment.Samplers[0]=BoundSampler{Texture=batch.Texture,Sampler=batch.Sampler};cmd:DrawCommand;DrawCommandFromMesh(&cmd,target,&b.Mesh,mat);cmd.IndexOffset=batch.IndexStart;cmd.IndexCount=count;cmd.HasViewport=true;cmd.Viewport=viewport;cmd.HasScissor=true;cmd.Scissor=scissor;cmd.BlendMode=batch.Blend;append(&cmd.VertexStorageBuffers,..b.VertexStorageBuffers[:]);append(&cmd.FragmentStorageBuffers,..b.FragmentStorageBuffers[:]);GraphicsDeviceDraw(b.GraphicsDevice,&cmd);DrawCommandDispose(&cmd)}}
BatcherRender :: proc{batcher_render_default,batcher_render_with_matrix,batcher_render_options}

batcher_triangle_solid :: proc(b:^Batcher,a,bp,c:Vec2,color:Color){batcher_push_tri(b,a,bp,c,color,{},{},{})}
batcher_triangle_gradient :: proc(b:^Batcher,a,bp,c:Vec2,c0,c1,c2:Color){base:=len(b.Vertices);batcher_push_vertex(b,a,{},c0);batcher_push_vertex(b,bp,{},c1);batcher_push_vertex(b,c,{},c2);append(&b.Indices,base,base+1,base+2)}
BatcherTriangle :: proc{batcher_triangle_solid, batcher_triangle_gradient}
batcher_triangle_texture_solid :: proc(b:^Batcher,texture:^Texture,a,bp,c:Vec2,uv0,uv1,uv2:[2]f32,color:Color){b.Texture=texture;batcher_push_tri(b,a,bp,c,color,uv0,uv1,uv2)}
batcher_triangle_texture_gradient :: proc(b:^Batcher,texture:^Texture,a,bp,c:Vec2,uv0,uv1,uv2:[2]f32,c0,c1,c2:Color){b.Texture=texture;base:=len(b.Vertices);batcher_push_vertex(b,a,uv0,c0);batcher_push_vertex(b,bp,uv1,c1);batcher_push_vertex(b,c,uv2,c2);append(&b.Indices,base,base+1,base+2)}
BatcherTriangleTexture :: proc{batcher_triangle_texture_solid, batcher_triangle_texture_gradient}
batcher_quad_points_solid :: proc(b:^Batcher,a,bp,c,d:Vec2,color:Color){base:=len(b.Vertices);batcher_push_vertex(b,a,{},color);batcher_push_vertex(b,bp,{},color);batcher_push_vertex(b,c,{},color);batcher_push_vertex(b,d,{},color);append(&b.Indices,base,base+1,base+2,base,base+2,base+3)}
batcher_quad_points_gradient :: proc(b:^Batcher,a,bp,c,d:Vec2,c0,c1,c2,c3:Color){base:=len(b.Vertices);batcher_push_vertex(b,a,{},c0);batcher_push_vertex(b,bp,{},c1);batcher_push_vertex(b,c,{},c2);batcher_push_vertex(b,d,{},c3);append(&b.Indices,base,base+1,base+2,base,base+2,base+3)}
BatcherQuadPoints :: proc{batcher_quad_points_solid, batcher_quad_points_gradient}
batcher_quad_rect_solid :: proc(b:^Batcher,rect:Rect,color:Color){batcher_quad_points_solid(b,RectTopLeft(rect),RectTopRight(rect),RectBottomRight(rect),RectBottomLeft(rect),color)}
batcher_quad_shape_solid :: proc(b:^Batcher,quad:Quad,color:Color){batcher_quad_points_solid(b,quad.A,quad.B,quad.C,quad.D,color)}
batcher_quad_rect_gradient :: proc(b:^Batcher,rect:Rect,c0,c1,c2,c3:Color){batcher_quad_points_gradient(b,RectTopLeft(rect),RectTopRight(rect),RectBottomRight(rect),RectBottomLeft(rect),c0,c1,c2,c3)}
batcher_quad_shape_gradient :: proc(b:^Batcher,quad:Quad,c0,c1,c2,c3:Color){batcher_quad_points_gradient(b,quad.A,quad.B,quad.C,quad.D,c0,c1,c2,c3)}
BatcherQuad :: proc{batcher_quad_rect_solid, batcher_quad_shape_solid, batcher_quad_rect_gradient, batcher_quad_shape_gradient}
batcher_quad_texture_solid :: proc(b:^Batcher,texture:^Texture,a,bp,c,d:Vec2,uv0,uv1,uv2,uv3:[2]f32,color:Color){b.Texture=texture;base:=len(b.Vertices);batcher_push_vertex(b,a,uv0,color);batcher_push_vertex(b,bp,uv1,color);batcher_push_vertex(b,c,uv2,color);batcher_push_vertex(b,d,uv3,color);append(&b.Indices,base,base+1,base+2,base,base+2,base+3)}
batcher_quad_texture_gradient :: proc(b:^Batcher,texture:^Texture,a,bp,c,d:Vec2,uv0,uv1,uv2,uv3:[2]f32,c0,c1,c2,c3:Color){b.Texture=texture;base:=len(b.Vertices);batcher_push_vertex(b,a,uv0,c0);batcher_push_vertex(b,bp,uv1,c1);batcher_push_vertex(b,c,uv2,c2);batcher_push_vertex(b,d,uv3,c3);append(&b.Indices,base,base+1,base+2,base,base+2,base+3)}
BatcherQuadTexture :: proc{batcher_quad_texture_solid, batcher_quad_texture_gradient}
batcher_line_solid :: proc(b:^Batcher,from,to:Vec2,thickness:f32,color:Color){d:=Vec2{to[0]-from[0],to[1]-from[1]};l:=math.sqrt(d[0]*d[0]+d[1]*d[1]);if l<=0{return};n:=Vec2{-d[1]/l*thickness*.5,d[0]/l*thickness*.5};batcher_quad_points_solid(b,Vec2{from[0]+n[0],from[1]+n[1]},Vec2{to[0]+n[0],to[1]+n[1]},Vec2{to[0]-n[0],to[1]-n[1]},Vec2{from[0]-n[0],from[1]-n[1]},color)}
batcher_line_gradient :: proc(b:^Batcher,from,to:Vec2,thickness:f32,from_color,to_color:Color){d:=Vec2{to[0]-from[0],to[1]-from[1]};l:=math.sqrt(d[0]*d[0]+d[1]*d[1]);if l<=0{return};n:=Vec2{-d[1]/l*thickness*.5,d[0]/l*thickness*.5};batcher_quad_points_gradient(b,Vec2{from[0]+n[0],from[1]+n[1]},Vec2{to[0]+n[0],to[1]+n[1]},Vec2{to[0]-n[0],to[1]-n[1]},Vec2{from[0]-n[0],from[1]-n[1]},from_color,to_color,to_color,from_color)}
BatcherLine :: proc{batcher_line_solid, batcher_line_gradient}
batcher_rect_solid :: proc(b:^Batcher,rect:Rect,color:Color){batcher_quad_rect_solid(b,rect,color)}
batcher_rect_gradient :: proc(b:^Batcher,rect:Rect,c0,c1,c2,c3:Color){batcher_quad_rect_gradient(b,rect,c0,c1,c2,c3)}
BatcherRect :: proc{batcher_rect_solid, batcher_rect_gradient}
BatcherRectLine :: proc(b:^Batcher,rect:Rect,thickness:f32,color:Color){BatcherLine(b,RectTopLeft(rect),RectTopRight(rect),thickness,color);BatcherLine(b,RectTopRight(rect),RectBottomRight(rect),thickness,color);BatcherLine(b,RectBottomRight(rect),RectBottomLeft(rect),thickness,color);BatcherLine(b,RectBottomLeft(rect),RectTopLeft(rect),thickness,color)}
batcher_circle_solid :: proc(b:^Batcher,center:Vec2,radius:f32,steps:int,color:Color){if steps<3{return};for i in 0..<steps{a0:=f32(i)/f32(steps)*f32(math.TAU);a1:=f32(i+1)/f32(steps)*f32(math.TAU);BatcherTriangle(b,center,Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius},Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius},color)}}
batcher_circle_gradient :: proc(b:^Batcher,center:Vec2,radius:f32,steps:int,center_color,edge_color:Color){if steps<3{return};for i in 0..<steps{a0:=f32(i)/f32(steps)*f32(math.TAU);a1:=f32(i+1)/f32(steps)*f32(math.TAU);BatcherTriangle(b,center,Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius},Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius},center_color,edge_color,edge_color)}}
BatcherCircle :: proc{batcher_circle_solid, batcher_circle_gradient}
BatcherCircleLine :: proc(b:^Batcher,center:Vec2,radius,thickness:f32,steps:int,color:Color){if steps<3{return};inner:=radius-thickness;if inner<=0{batcher_circle_solid(b,center,radius,steps,color);return};for i in 0..<steps{a0:=f32(i)/f32(steps)*f32(math.TAU);a1:=f32(i+1)/f32(steps)*f32(math.TAU);o0:=Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius};o1:=Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius};i0:=Vec2{center[0]+math.cos(a0)*inner,center[1]+math.sin(a0)*inner};i1:=Vec2{center[0]+math.cos(a1)*inner,center[1]+math.sin(a1)*inner};BatcherQuadPoints(b,i0,o0,o1,i1,color)}}

batcher_push_matrix_raw :: proc(b:^Batcher,matrix_arg:[16]f32,relative:bool=true)->[16]f32{old:=b.Matrix;append(&b.MatrixStack,old);if !relative{b.Matrix=matrix_arg;return b.Matrix};a:=old;c:=matrix_arg;out:[16]f32 = {};for col in 0..<4{for row in 0..<4{out[col*4+row]=c[0*4+row]*a[col*4+0]+c[1*4+row]*a[col*4+1]+c[2*4+row]*a[col*4+2]+c[3*4+row]*a[col*4+3]}};b.Matrix=out;return b.Matrix}
batcher_matrix_from_3x2 :: proc(m: Matrix3x2) -> [16]f32 { return [16]f32{m.M11,m.M12,0,0,m.M21,m.M22,0,0,0,0,1,0,m.M31,m.M32,0,1} }
BatcherPushMatrixRaw :: proc(b:^Batcher,matrix_arg:[16]f32,relative:bool=true)->[16]f32{return batcher_push_matrix_raw(b,matrix_arg,relative)}
BatcherPushMatrixPosition :: proc(b:^Batcher,position:Vec2,relative:bool=true)->[16]f32{return batcher_push_matrix_raw(b,batcher_matrix_from_3x2(Matrix3x2{1,0,0,1,position[0],position[1]}),relative)}
BatcherPushMatrixTransform :: proc(b:^Batcher,transform:Transform,relative:bool=true)->[16]f32{t:=transform;return batcher_push_matrix_raw(b,batcher_matrix_from_3x2(TransformMatrix(&t)),relative)}
BatcherPushMatrixTRS :: proc(b:^Batcher,position,scale:Vec2,rotation:f32,relative:bool=true)->[16]f32{return batcher_push_matrix_raw(b,batcher_matrix_from_3x2(TransformCreateMatrix(position,{},scale,rotation)),relative)}
BatcherPushMatrixOrigin :: proc(b:^Batcher,position,origin,scale:Vec2,rotation:f32,relative:bool=true)->[16]f32{return batcher_push_matrix_raw(b,batcher_matrix_from_3x2(TransformCreateMatrix(position,origin,scale,rotation)),relative)}
BatcherPushMatrix :: proc{BatcherPushMatrixRaw, BatcherPushMatrixPosition, BatcherPushMatrixTransform, BatcherPushMatrixTRS, BatcherPushMatrixOrigin}
BatcherPopMatrix :: proc(b:^Batcher)->[16]f32{old:=b.Matrix;if len(b.MatrixStack)>0{b.Matrix=b.MatrixStack[len(b.MatrixStack)-1];resize(&b.MatrixStack,len(b.MatrixStack)-1)};return old}
BatcherPushMode :: proc(b:^Batcher,mode:BatcherMode){append(&b.ModeStack,BatcherModeState{b.Mode,b.ModeColor});b.Mode=mode;b.ModeColor=batcher_mode_color(mode)}
BatcherPushModeColor :: proc(b:^Batcher,mode:Color){append(&b.ModeStack,BatcherModeState{b.Mode,b.ModeColor});b.ModeColor=mode}
BatcherPopMode :: proc(b:^Batcher){if b==nil||len(b.ModeStack)==0{return};state:=b.ModeStack[len(b.ModeStack)-1];b.Mode=state.Mode;b.ModeColor=state.Color;resize(&b.ModeStack,len(b.ModeStack)-1)}
BatcherPushLayer :: proc(b:^Batcher,delta:int){append(&b.LayerStack,b.Layer);b.Layer+=delta}
BatcherPopLayer :: proc(b:^Batcher){if len(b.LayerStack)>0{b.Layer=b.LayerStack[len(b.LayerStack)-1];resize(&b.LayerStack,len(b.LayerStack)-1)}}
BatcherPushSampler :: proc(b:^Batcher,sampler:TextureSampler){append(&b.SamplerStack,b.Sampler);b.Sampler=sampler}
BatcherPopSampler :: proc(b:^Batcher){if len(b.SamplerStack)>0{b.Sampler=b.SamplerStack[len(b.SamplerStack)-1];resize(&b.SamplerStack,len(b.SamplerStack)-1)}}
BatcherPushBlend :: proc(b:^Batcher,blend:BlendMode){append(&b.BlendStack,b.Blend);b.Blend=blend}
BatcherPopBlend :: proc(b:^Batcher){if len(b.BlendStack)>0{b.Blend=b.BlendStack[len(b.BlendStack)-1];resize(&b.BlendStack,len(b.BlendStack)-1)}}
BatcherPushScissor :: proc(b:^Batcher,scissor:RectInt){append(&b.ScissorStack,b.Scissor);append(&b.ScissorEnabledStack,b.HasScissor);b.Scissor=scissor;b.HasScissor=true}
BatcherPopScissor :: proc(b:^Batcher){if len(b.ScissorStack)>0{b.Scissor=b.ScissorStack[len(b.ScissorStack)-1];resize(&b.ScissorStack,len(b.ScissorStack)-1);b.HasScissor=b.ScissorEnabledStack[len(b.ScissorEnabledStack)-1];resize(&b.ScissorEnabledStack,len(b.ScissorEnabledStack)-1)}}
BatcherPushMaterial :: proc(b:^Batcher,material:^Material){if material==nil{return};saved:=new(Material);MaterialInit(saved);MaterialCopyTo(&b.Material,saved);append(&b.MaterialStack,saved);MaterialCopyTo(material,&b.Material);b.HasMaterial=true}
BatcherPopMaterial :: proc(b:^Batcher){if b==nil||len(b.MaterialStack)==0{return};saved:=b.MaterialStack[len(b.MaterialStack)-1];resize(&b.MaterialStack,len(b.MaterialStack)-1);MaterialCopyTo(saved,&b.Material);batcher_free_material(saved)}
BatcherPushMatrix2D :: proc(b:^Batcher,position,scale:Vec2,rotation:f32,relative:bool=true)->[16]f32{return BatcherPushMatrixTRS(b,position,scale,rotation,relative)}
BatcherPushMatrix2DOrigin :: proc(b:^Batcher,position,origin,scale:Vec2,rotation:f32,relative:bool=true)->[16]f32{return BatcherPushMatrixOrigin(b,position,origin,scale,rotation,relative)}
BatcherPopMatrixStack :: proc(b:^Batcher)->[16]f32{return BatcherPopMatrix(b)}
batcher_image_sub_pos :: proc(b:^Batcher,sub:Subtexture,position:Vec2,color:Color=White){if sub.Texture==nil{return};d:=sub.DrawCoords;p:=position;BatcherQuadTexture(b,sub.Texture,Vec2{p[0]+d[0][0],p[1]+d[0][1]},Vec2{p[0]+d[1][0],p[1]+d[1][1]},Vec2{p[0]+d[2][0],p[1]+d[2][1]},Vec2{p[0]+d[3][0],p[1]+d[3][1]},sub.TexCoords[0],sub.TexCoords[1],sub.TexCoords[2],sub.TexCoords[3],color)}
batcher_image_sub_color :: proc(b:^Batcher,sub:Subtexture,color:Color){batcher_image_sub_pos(b,sub,{},color)}
batcher_image_texture_color :: proc(b:^Batcher,texture:^Texture,color:Color){if texture==nil{return};batcher_image_sub_color(b,SubtextureFromTexture(texture),color)}
batcher_image_texture_pos :: proc(b:^Batcher,texture:^Texture,position:Vec2,color:Color){if texture==nil{return};batcher_image_sub_pos(b,SubtextureFromTexture(texture),position,color)}
batcher_image_sub_transform :: proc(b:^Batcher,sub:Subtexture,position,origin,scale:Vec2,rotation:f32,color:Color){if sub.Texture==nil{return};BatcherPushMatrix2DOrigin(b,position,origin,scale,rotation,true);batcher_image_sub_color(b,sub,color);BatcherPopMatrixStack(b)}
batcher_image_sub_justified :: proc(b:^Batcher,sub:Subtexture,position,justify:Vec2,color:Color){batcher_image_sub_pos(b,sub,Vec2{position[0]-SubtextureWidth(sub)*justify[0],position[1]-SubtextureHeight(sub)*justify[1]},color)}
batcher_image_sub_justified_scale :: proc(b:^Batcher,sub:Subtexture,position,justify:Vec2,scale:f32,color:Color){batcher_image_sub_transform(b,sub,Vec2{position[0]-SubtextureWidth(sub)*scale*justify[0],position[1]-SubtextureHeight(sub)*scale*justify[1]},Vec2{},Vec2{scale,scale},0,color)}
batcher_image_stretch :: proc(b:^Batcher,sub:Subtexture,rect:Rect,color:Color){if sub.Texture==nil{return};BatcherQuadTexture(b,sub.Texture,RectTopLeft(rect),RectTopRight(rect),RectBottomRight(rect),RectBottomLeft(rect),sub.TexCoords[0],sub.TexCoords[1],sub.TexCoords[2],sub.TexCoords[3],color)}
batcher_image_fit :: proc(b:^Batcher,sub:Subtexture,rect:Rect,justify:Vec2,color:Color,flip_x,flip_y:bool){if sub.Texture==nil||SubtextureWidth(sub)<=0||SubtextureHeight(sub)<=0{return};bounds:=rect;if bounds.Width==0{bounds.Width=SubtextureWidth(sub)};if bounds.Height==0{bounds.Height=SubtextureHeight(sub)};scale:=math.min(bounds.Width/SubtextureWidth(sub),bounds.Height/SubtextureHeight(sub));at:=Vec2{bounds.X+bounds.Width*justify[0],bounds.Y+bounds.Height*justify[1]};orig:=Vec2{SubtextureWidth(sub)*justify[0],SubtextureHeight(sub)*justify[1]};sx:=scale;if flip_x{sx=-sx};sy:=scale;if flip_y{sy=-sy};batcher_image_sub_transform(b,sub,at,orig,Vec2{sx,sy},0,color)}
BatcherImage :: proc{batcher_image_sub_pos, batcher_image_sub_color, batcher_image_texture_color, batcher_image_texture_pos, batcher_image_sub_transform, batcher_image_sub_justified, batcher_image_sub_justified_scale, batcher_image_stretch, batcher_image_fit}
BatcherLineDashed :: proc(b:^Batcher,from,to:Vec2,weight,dash,offset:f32,color:Color){d:=Vec2{to[0]-from[0],to[1]-from[1]};length:=math.sqrt(d[0]*d[0]+d[1]*d[1]);if length<=0||dash<=0{return};axis:=Vec2{d[0]/length,d[1]/length};phase:=offset-math.floor(offset);start:=dash*phase*2;if start>dash{start-=dash*2};for at:=start;at<length;at+=dash*2{a:=math.max(at,0);z:=math.min(at+dash,length);BatcherLine(b,Vec2{from[0]+axis[0]*a,from[1]+axis[1]*a},Vec2{from[0]+axis[0]*z,from[1]+axis[1]*z},weight,color)}}
BatcherQuadLine :: proc(b:^Batcher,a,bp,c,d:Vec2,weight:f32,color:Color){BatcherLine(b,a,bp,weight,color);BatcherLine(b,bp,c,weight,color);BatcherLine(b,c,d,weight,color);BatcherLine(b,d,a,weight,color)}
BatcherTriangleLine :: proc(b:^Batcher,a,bp,c:Vec2,weight:f32,color:Color){BatcherLine(b,a,bp,weight,color);BatcherLine(b,bp,c,weight,color);BatcherLine(b,c,a,weight,color)}
BatcherRectDashed :: proc(b:^Batcher,r:Rect,weight,dash,offset:f32,color:Color){BatcherLineDashed(b,RectTopLeft(r),RectTopRight(r),weight,dash,offset,color);BatcherLineDashed(b,RectTopRight(r),RectBottomRight(r),weight,dash,offset,color);BatcherLineDashed(b,RectBottomRight(r),RectBottomLeft(r),weight,dash,offset,color);BatcherLineDashed(b,RectBottomLeft(r),RectTopLeft(r),weight,dash,offset,color)}
batcher_rounded_points :: proc(r:Rect, radius:f32, segments:int) -> [dynamic]Vec2 {
	points:[dynamic]Vec2 = {}; if segments < 1 { return points }
	rr := math.max(0, math.min(radius, math.min(math.abs(r.Width), math.abs(r.Height))*0.5))
	if rr <= 0 { append(&points, RectTopLeft(r), RectTopRight(r), RectBottomRight(r), RectBottomLeft(r)); return points }
	centers := [4]Vec2{Vec2{r.X+rr,r.Y+rr}, Vec2{RectRight(r)-rr,r.Y+rr}, Vec2{RectRight(r)-rr,RectBottom(r)-rr}, Vec2{r.X+rr,RectBottom(r)-rr}}
	starts := [4]f32{f32(math.PI), f32(math.PI*1.5), 0, f32(math.PI*0.5)}
	for corner in 0..<4 { for step in 0..=segments { a:=starts[corner]+f32(step)/f32(segments)*f32(math.PI*0.5); append(&points,Vec2{centers[corner][0]+math.cos(a)*rr,centers[corner][1]+math.sin(a)*rr}) } }
	return points
}
batcher_rect_rounded_uniform :: proc(b:^Batcher,r:Rect,radius:f32,color:Color){points:=batcher_rounded_points(r,radius,8);defer delete(points);if len(points)<3{return};center:=RectCenter(r);for i:=0;i<len(points);i+=1{BatcherTriangle(b,center,points[i],points[(i+1)%len(points)],color)}}
batcher_rect_rounded_corners :: proc(b:^Batcher,r:Rect,r0,r1,r2,r3:f32,color:Color){radii:=[4]f32{r0,r1,r2,r3};max_radius:=math.min(math.abs(r.Width),math.abs(r.Height))*0.5;for i:=0;i<4;i+=1{radii[i]=math.max(0,math.min(radii[i],max_radius))};points:[dynamic]Vec2={};defer delete(points);centers:=[4]Vec2{Vec2{r.X+radii[0],r.Y+radii[0]},Vec2{RectRight(r)-radii[1],r.Y+radii[1]},Vec2{RectRight(r)-radii[2],RectBottom(r)-radii[2]},Vec2{r.X+radii[3],RectBottom(r)-radii[3]}};starts:=[4]f32{f32(math.PI),f32(math.PI*1.5),0,f32(math.PI*0.5)};for corner in 0..<4{for step in 0..=8{a:=starts[corner]+f32(step)/8*f32(math.PI*0.5);append(&points,Vec2{centers[corner][0]+math.cos(a)*radii[corner],centers[corner][1]+math.sin(a)*radii[corner]})}};center:=RectCenter(r);for i:=0;i<len(points);i+=1{BatcherTriangle(b,center,points[i],points[(i+1)%len(points)],color)}}
BatcherRectRounded :: proc{batcher_rect_rounded_uniform, batcher_rect_rounded_corners}
batcher_rect_rounded_line_uniform :: proc(b:^Batcher,r:Rect,radius,weight:f32,color:Color){points:=batcher_rounded_points(r,radius,8);defer delete(points);if len(points)<2{return};for i:=0;i<len(points);i+=1{BatcherLine(b,points[i],points[(i+1)%len(points)],weight,color)}}
batcher_rect_rounded_line_corners :: proc(b:^Batcher,r:Rect,r0,r1,r2,r3,weight:f32,color:Color){radii:=[4]f32{r0,r1,r2,r3};max_radius:=math.min(math.abs(r.Width),math.abs(r.Height))*0.5;for i:=0;i<4;i+=1{radii[i]=math.max(0,math.min(radii[i],max_radius))};points:[dynamic]Vec2={};defer delete(points);centers:=[4]Vec2{Vec2{r.X+radii[0],r.Y+radii[0]},Vec2{RectRight(r)-radii[1],r.Y+radii[1]},Vec2{RectRight(r)-radii[2],RectBottom(r)-radii[2]},Vec2{r.X+radii[3],RectBottom(r)-radii[3]}};starts:=[4]f32{f32(math.PI),f32(math.PI*1.5),0,f32(math.PI*0.5)};for corner in 0..<4{for step in 0..=8{a:=starts[corner]+f32(step)/8*f32(math.PI*0.5);append(&points,Vec2{centers[corner][0]+math.cos(a)*radii[corner],centers[corner][1]+math.sin(a)*radii[corner]})}};for i:=0;i<len(points);i+=1{BatcherLine(b,points[i],points[(i+1)%len(points)],weight,color)}}
BatcherRectRoundedLine :: proc{batcher_rect_rounded_line_uniform, batcher_rect_rounded_line_corners}
batcher_semi_circle_solid :: proc(b:^Batcher,center:Vec2,start,end,radius:f32,steps:int,color:Color){if steps<1{return};for i in 0..<steps{a0:=start+(end-start)*f32(i)/f32(steps);a1:=start+(end-start)*f32(i+1)/f32(steps);BatcherTriangle(b,center,Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius},Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius},color)}}
batcher_semi_circle_gradient :: proc(b:^Batcher,center:Vec2,start,end,radius:f32,steps:int,center_color,edge_color:Color){if steps<1{return};for i in 0..<steps{a0:=start+(end-start)*f32(i)/f32(steps);a1:=start+(end-start)*f32(i+1)/f32(steps);BatcherTriangle(b,center,Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius},Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius},center_color,edge_color,edge_color)}}
BatcherSemiCircle :: proc{batcher_semi_circle_solid, batcher_semi_circle_gradient}
BatcherSemiCircleLine :: proc(b:^Batcher,center:Vec2,start,end,radius,weight:f32,steps:int,color:Color){if steps<1{return};for i in 0..<steps{a0:=start+(end-start)*f32(i)/f32(steps);a1:=start+(end-start)*f32(i+1)/f32(steps);BatcherLine(b,Vec2{center[0]+math.cos(a0)*radius,center[1]+math.sin(a0)*radius},Vec2{center[0]+math.cos(a1)*radius,center[1]+math.sin(a1)*radius},weight,color)}}
BatcherCircleDashed :: proc(b:^Batcher,center:Vec2,radius,weight,dash,offset:f32,steps:int,color:Color){if steps<3||dash<=0{return};last:=Vec2{center[0]+radius,center[1]};da:=f32(math.TAU)/f32(steps);dx:=radius-radius*math.cos(da);dy:=radius*math.sin(da);segment_length:=math.sqrt(dx*dx+dy*dy);phase:=offset;for i:=1;i<=steps;i+=1{a:=f32(i)/f32(steps)*f32(math.TAU);next:=Vec2{center[0]+math.cos(a)*radius,center[1]+math.sin(a)*radius};BatcherLineDashed(b,last,next,weight,dash,phase,color);phase+=segment_length;last=next}}
BatcherRadialBar :: proc(b:^Batcher,position:Vec2,percent,inner,outer:f32,color:Color){if percent<=0||outer<=inner{return};segments:=64;single:=f32(1)/f32(segments);bar_radius:=(outer-inner)*0.5;if percent<single{scale:=math.clamp(percent/single,0,1);BatcherCircle(b,position,bar_radius*scale,16,color);return};for i:=0;i<segments;i+=1{prev:=f32(i)/f32(segments);next:=math.min(percent,f32(i+1)/f32(segments));a0:=prev*f32(math.TAU);a1:=next*f32(math.TAU);p0:=Vec2{math.cos(a0),math.sin(a0)};p1:=Vec2{math.cos(a1),math.sin(a1)};if percent<0.99&&prev<=0{BatcherCircle(b,Vec2{position[0]+p0[0]*(inner+outer)*0.5,position[1]+p0[1]*(inner+outer)*0.5},bar_radius,16,color)};BatcherQuadPoints(b,Vec2{position[0]+p0[0]*inner,position[1]+p0[1]*inner},Vec2{position[0]+p0[0]*outer,position[1]+p0[1]*outer},Vec2{position[0]+p1[0]*outer,position[1]+p1[1]*outer},Vec2{position[0]+p1[0]*inner,position[1]+p1[1]*inner},color);if next>=percent{if percent<0.99{BatcherCircle(b,Vec2{position[0]+p1[0]*(inner+outer)*0.5,position[1]+p1[1]*(inner+outer)*0.5},bar_radius,16,color)};break}}}
BatcherCheckeredPattern :: proc(b:^Batcher,bounds:Rect,cell_w,cell_h:f32,a,bcolor:Color){if cell_w<=0||cell_h<=0{return};rows:=int(math.ceil(bounds.Height/cell_h));cols:=int(math.ceil(bounds.Width/cell_w));for y in 0..<rows{for x in 0..<cols{c:=a;if (x+y)%2!=0{c=bcolor};BatcherRect(b,Rect{bounds.X+f32(x)*cell_w,bounds.Y+f32(y)*cell_h,math.min(cell_w,bounds.Width-f32(x)*cell_w),math.min(cell_h,bounds.Height-f32(y)*cell_h)},c)}}}
