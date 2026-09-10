package foster_framework

import "core:math"
import "core:strconv"
import "core:strings"
import "base:intrinsics"
import "core:fmt"

// ===== merged from Utility/Calc.odin =====


Right :: f32(0)
Left :: PI
Up :: PI + HalfPI
Down :: HalfPI
UpRight :: TAU - PI * 0.25
DownRight :: PI * 0.25
UpLeft :: TAU - PI * 0.75
DownLeft :: PI * 0.75

IsBitSet :: proc(value: $T, position: int) -> bool { return (value & (T(1) << T(position))) != 0 }
GiveMe :: proc(index: int, choices: []$T) -> T { if index < 0 || index >= len(choices) do return {}; return choices[index] }
SignsMatch :: proc(a, b: f32) -> bool { return math.sign(a) == math.sign(b) }
Squared :: proc(v: f32) -> f32 { return v*v }
AvgFloat :: proc(values: []f32) -> f32 { if len(values)==0{return 0};sum:f32=0;for v in values{sum+=v};return sum/f32(len(values)) }
AvgVec2 :: proc(values: []Vec2) -> Vec2 { if len(values)==0{return {}};sum:Vec2={};for v in values{sum[0]+=v[0];sum[1]+=v[1]};return Vec2{sum[0]/f32(len(values)),sum[1]/f32(len(values))} }
Avg :: proc{AvgFloat, AvgVec2}
OffsetPoint2Slice :: proc(points: []Point2, offset: Point2) -> []Point2 { for i := 0; i < len(points); i += 1 { points[i] = Point2{points[i].X + offset.X, points[i].Y + offset.Y} }; return points }
TriangleAreaVec2 :: proc(a,b,c:Vec2)->f32{return math.abs((a[0]*(b[1]-c[1])+b[0]*(c[1]-a[1])+c[0]*(a[1]-b[1]))*.5)}
Cross :: proc(a,b:Vec2)->f32{return a[0]*b[1]-a[1]*b[0]}
SignCross :: proc(a,b:Vec2)->int{return int(math.sign(Cross(a,b)))}
Orient :: proc(a,b,c:Vec2)->int{return SignCross(Vec2{b[0]-a[0],b[1]-a[1]},Vec2{c[0]-a[0],c[1]-a[1]})}
TriangleContainsPoint :: proc(a,b,c,p:Vec2)->bool{return math.abs(Orient(a,b,p)+Orient(b,c,p)+Orient(c,a,p))==3}
AbsDot :: proc(a,b:Vec2)->f32{return math.abs(spatial_vec2_dot(a,b))}
DotSq :: proc(a,b:Vec2)->f32{d:=spatial_vec2_dot(a,b);return math.sign(d)*d*d}
AbsDotSq :: proc(a,b:Vec2)->f32{d:=spatial_vec2_dot(a,b);return d*d}
spatial_vec2_dot :: proc(a,b:Vec2)->f32{return a[0]*b[0]+a[1]*b[1]}

ApproachVec2 :: proc(from,target:Vec2,amount:f32)->Vec2{if from==target{return target};d:=Vec2{target[0]-from[0],target[1]-from[1]};if d[0]*d[0]+d[1]*d[1]<=amount*amount{return target};l:=math.sqrt(d[0]*d[0]+d[1]*d[1]);return Vec2{from[0]+d[0]/l*amount,from[1]+d[1]/l*amount}}
Approach3 :: proc(from,target:Vec3,amount:f32)->Vec3{if from==target{return target};d:=Vec3{target[0]-from[0],target[1]-from[1],target[2]-from[2]};l2:=d[0]*d[0]+d[1]*d[1]+d[2]*d[2];if l2<=amount*amount{return target};l:=math.sqrt(l2);return Vec3{from[0]+d[0]/l*amount,from[1]+d[1]/l*amount,from[2]+d[2]/l*amount}}
ApproachRefScalar :: proc(from:^f32,target,amount:f32)->f32 { from^=ApproachScalar(from^,target,amount); return from^ }
ApproachRefVec2 :: proc(from:^Vec2,target:Vec2,amount:f32)->Vec2 { from^=ApproachVec2(from^,target,amount); return from^ }
Approach :: proc{ApproachScalar, ApproachVec2, Approach3}
ApproachIfLower :: proc(from, target, amount: f32) -> f32 { if SignsMatch(from, target) && math.abs(from) >= math.abs(target) { return from }; return ApproachScalar(from, target, amount) }
RotateToward :: proc(dir,target:Vec2,max_angle_delta,max_magnitude_delta:f32)->Vec2{angle:=Angle(dir);length:=spatial_vec2_length(dir);if max_angle_delta>0{angle=AngleApproach(angle,Angle(target),max_angle_delta)};if max_magnitude_delta>0{length=Approach(length,spatial_vec2_length(target),max_magnitude_delta)};return AngleToVector(angle,length)}

SineMap :: proc(radians,new_min,new_max:f32)->f32{return MapTo(math.sin(radians), -1, 1, new_min, new_max)}
AngleVector :: proc(v:Vec2)->f32{return math.atan2(v[1],v[0])}
AngleBetween :: proc(from,to:Vec2)->f32{return math.atan2(to[1]-from[1],to[0]-from[0])}
Angle :: proc{AngleVector, AngleBetween}
AngleToVector :: proc(angle:f32,length:f32=1)->Vec2{return Vec2{math.cos(angle)*length,math.sin(angle)*length}}
AngleWrap :: proc(angle:f32)->f32{result:=math.mod(angle,TAU);if result<0{result+=TAU};return result}
AngleDiff :: proc(a,b:f32)->f32{result:=math.mod(b-a-PI,TAU);if result<0{result+=TAU};return result-PI}
AbsAngleDiff :: proc(a,b:f32)->f32{return math.abs(AngleDiff(a,b))}
AngleApproach :: proc(value,target,max_move:f32)->f32{d:=AngleDiff(value,target);if math.abs(d)<max_move{return target};return value+Clamp(d,-max_move,max_move)}
AngleLerp :: proc(a,b,percent:f32)->f32{return a+AngleDiff(a,b)*percent}
AngleReflectOnX :: proc(angle:f32)->f32{return AngleWrap(-angle)}
AngleReflectOnY :: proc(angle:f32)->f32{return AngleWrap(HalfPI-(angle-HalfPI))}
spatial_vec2_length :: proc(v:Vec2)->f32{return math.sqrt(v[0]*v[0]+v[1]*v[1])}

NextPowerOfTwo :: proc(x:int)->int{if x<=0{return 0};if x==1{return 1};v:=x-1;v|=v>>1;v|=v>>2;v|=v>>4;v|=v>>8;v|=v>>16;return v+1}
Approx :: proc(a,b:f32)->bool{return math.abs(a-b)<=0.001}
GetBresenhamsLine :: proc(a,b:Point2)->[dynamic]Point2{result:[dynamic]Point2={};aa:=a;bb:=b;steep:=math.abs(bb.Y-aa.Y)>math.abs(bb.X-aa.X);if steep{aa.X,aa.Y=aa.Y,aa.X;bb.X,bb.Y=bb.Y,bb.X};if aa.X>bb.X{aa.X,bb.X=bb.X,aa.X;aa.Y,bb.Y=bb.Y,aa.Y};dx:=bb.X-aa.X;dy:=math.abs(bb.Y-aa.Y);err:=dx/2;ystep:=1;if aa.Y>=bb.Y{ystep=-1};y:=aa.Y;for x:=aa.X;x<=bb.X;x+=1{if steep{append(&result,Point2{y,x})}else{append(&result,Point2{x,y})};err-=dy;if err<0{y+=ystep;err+=dx}};return result}
SolveQuadratic :: proc(a,b,c:f32)->(bool,f32,f32){d:=b*b-4*a*c;if d<0{return false,0,0};if d==0{r:=-b/(2*a);return true,r,r};s:=math.sqrt(d);return true,(-b+s)/(2*a),(-b-s)/(2*a)}

GetClosestPointIndexVec2 :: proc(points:[]Vec2,to:Vec2)->int{best:=-1;dist:f32=0;for i:=0;i<len(points);i+=1{p:=points[i];dx:=p[0]-to[0];dy:=p[1]-to[1];d:=dx*dx+dy*dy;if best<0||d<dist{best=i;dist=d}};return best}
GetFurthestPointIndexVec2 :: proc(points:[]Vec2,to:Vec2)->int{best:=-1;dist:f32=0;for i:=0;i<len(points);i+=1{p:=points[i];dx:=p[0]-to[0];dy:=p[1]-to[1];d:=dx*dx+dy*dy;if best<0||d>dist{best=i;dist=d}};return best}
GetClosestPointIndexPoint2 :: proc(points:[]Point2,to:Vec2)->int{best:=-1;dist:f32=0;for i:=0;i<len(points);i+=1{p:=points[i];dx:=f32(p.X)-to[0];dy:=f32(p.Y)-to[1];d:=dx*dx+dy*dy;if best<0||d<dist{best=i;dist=d}};return best}
GetFurthestPointIndexPoint2 :: proc(points:[]Point2,to:Vec2)->int{best:=-1;dist:f32=0;for i:=0;i<len(points);i+=1{p:=points[i];dx:=f32(p.X)-to[0];dy:=f32(p.Y)-to[1];d:=dx*dx+dy*dy;if best<0||d>dist{best=i;dist=d}};return best}
GetClosestPointIndex :: proc{GetClosestPointIndexVec2, GetClosestPointIndexPoint2}
GetFurthestPointIndex :: proc{GetFurthestPointIndexVec2, GetFurthestPointIndexPoint2}

Smallest :: proc(values: []$T) -> int { if len(values)==0{return -1}; best:=0; for i:=1;i<len(values);i+=1 { if values[i] < values[best] {best=i} }; return best }
Largest :: proc(values: []$T) -> int { if len(values)==0{return -1}; best:=0; for i:=1;i<len(values);i+=1 { if values[i] > values[best] {best=i} }; return best }

GetClosestValueIndex :: proc(values: []$T, to: T) -> int where intrinsics.type_is_numeric(T) { best:int=-1; dist:T={}; for v,i in values { d:T=v-to; if d<T(0) {d=-d}; if best<0 || d < dist {best=i;dist=d} }; return best }
GetFurthestValueIndex :: proc(values: []$T, to: T) -> int where intrinsics.type_is_numeric(T) { best:int=-1; dist:T={}; for v,i in values { d:T=v-to; if d<T(0) {d=-d}; if best<0 || d > dist {best=i;dist=d} }; return best }
GetClosestValue :: proc(values: []$T, to: T) -> T where intrinsics.type_is_numeric(T) { i:=GetClosestValueIndex(values,to); if i<0{return {}}; return values[i] }
GetFurthestValue :: proc(values: []$T, to: T) -> T where intrinsics.type_is_numeric(T) { i:=GetFurthestValueIndex(values,to); if i<0{return {}}; return values[i] }
GetClosestPointVec2 :: proc(points:[]Vec2,to:Vec2)->Vec2{i:=GetClosestPointIndexVec2(points,to);if i<0{return {}};return points[i]}
GetFurthestPointVec2 :: proc(points:[]Vec2,to:Vec2)->Vec2{i:=GetFurthestPointIndexVec2(points,to);if i<0{return {}};return points[i]}
GetClosestPointPoint2 :: proc(points:[]Point2,to:Vec2)->Point2{i:=GetClosestPointIndexPoint2(points,to);if i<0{return {}};return points[i]}
GetFurthestPointPoint2 :: proc(points:[]Point2,to:Vec2)->Point2{i:=GetFurthestPointIndexPoint2(points,to);if i<0{return {}};return points[i]}
GetClosestPoint :: proc{GetClosestPointVec2, GetClosestPointPoint2}
GetFurthestPoint :: proc{GetFurthestPointVec2, GetFurthestPointPoint2}

Lerp :: proc(a,b,percent:f32)->f32{return a+(b-a)*percent}
ClampedLerp :: proc(a,b,percent:f32)->f32{return Lerp(a,b,Clamp01(percent))}
Bezier3 :: proc(a,b,c,t:f32)->f32{return Lerp(Lerp(a,b,t),Lerp(b,c,t),t)}
Bezier4 :: proc(a,b,c,d,t:f32)->f32{return Bezier3(Lerp(a,b,t),Lerp(b,c,t),Lerp(c,d,t),t)}
BezierVec3 :: proc(a,b,c:Vec2,t:f32)->Vec2{return Vec2{Bezier3(a[0],b[0],c[0],t),Bezier3(a[1],b[1],c[1],t)}}
BezierVec4 :: proc(a,b,c,d:Vec2,t:f32)->Vec2{return BezierVec3(Vec2{Lerp(a[0],b[0],t),Lerp(a[1],b[1],t)},Vec2{Lerp(b[0],c[0],t),Lerp(b[1],c[1],t)},Vec2{Lerp(c[0],d[0],t),Lerp(c[1],d[1],t)},t)}
Bezier :: proc{Bezier3, Bezier4, BezierVec3, BezierVec4}

SnapScalar :: proc(value,interval:f32)->f32{if interval==0{return value};return math.round(value/interval)*interval}
SnapFloorScalar :: proc(value,interval:f32)->f32{if interval==0{return value};return math.floor(value/interval)*interval}
SnapCeilScalar :: proc(value,interval:f32)->f32{if interval==0{return value};return math.ceil(value/interval)*interval}
SnapVec2 :: proc(value,interval:Vec2)->Vec2{return Vec2{SnapScalar(value[0],interval[0]),SnapScalar(value[1],interval[1])}}
SnapFloorVec2 :: proc(value,interval:Vec2)->Vec2{return Vec2{SnapFloorScalar(value[0],interval[0]),SnapFloorScalar(value[1],interval[1])}}
SnapCeilVec2 :: proc(value,interval:Vec2)->Vec2{return Vec2{SnapCeilScalar(value[0],interval[0]),SnapCeilScalar(value[1],interval[1])}}
SnapFloatPoint2 :: proc(value: Vec2, interval: Point2) -> Point2 { return Point2{int(math.round(value[0]/f32(interval.X)))*interval.X, int(math.round(value[1]/f32(interval.Y)))*interval.Y} }
SnapScalarVec2 :: proc(value: Vec2, interval: f32) -> Vec2 { return Vec2{Snap(value[0],interval),Snap(value[1],interval)} }
SnapIntPoint2 :: proc(value: Vec2, interval: int) -> Point2 { return Point2{int(math.round(value[0]/f32(interval)))*interval,int(math.round(value[1]/f32(interval)))*interval} }
Snap :: proc{SnapScalar, SnapVec2, SnapFloatPoint2, SnapScalarVec2, SnapIntPoint2}
SnapFloorFloatPoint2 :: proc(value: Vec2, interval: Point2) -> Point2 { return Point2{int(math.floor(value[0]/f32(interval.X)))*interval.X, int(math.floor(value[1]/f32(interval.Y)))*interval.Y} }
SnapFloorScalarVec2 :: proc(value: Vec2, interval: f32) -> Vec2 { return Vec2{SnapFloor(value[0],interval),SnapFloor(value[1],interval)} }
SnapFloorIntPoint2 :: proc(value: Vec2, interval: int) -> Point2 { return Point2{int(math.floor(value[0]/f32(interval)))*interval,int(math.floor(value[1]/f32(interval)))*interval} }
SnapFloor :: proc{SnapFloorScalar, SnapFloorVec2, SnapFloorFloatPoint2, SnapFloorScalarVec2, SnapFloorIntPoint2}
SnapCeilFloatPoint2 :: proc(value: Vec2, interval: Point2) -> Point2 { return Point2{int(math.ceil(value[0]/f32(interval.X)))*interval.X, int(math.ceil(value[1]/f32(interval.Y)))*interval.Y} }
SnapCeilScalarVec2 :: proc(value: Vec2, interval: f32) -> Vec2 { return Vec2{SnapCeil(value[0],interval),SnapCeil(value[1],interval)} }
SnapCeilIntPoint2 :: proc(value: Vec2, interval: int) -> Point2 { return Point2{int(math.ceil(value[0]/f32(interval)))*interval,int(math.ceil(value[1]/f32(interval)))*interval} }
SnapCeil :: proc{SnapCeilScalar, SnapCeilVec2, SnapCeilFloatPoint2, SnapCeilScalarVec2, SnapCeilIntPoint2}

MoveVec2 :: proc(points: []Vec2, delta: Vec2) -> []Vec2 { for i:=0;i<len(points);i+=1 { points[i] += delta }; return points }
InsideTriangle :: proc(a,b,c,p: Vec2) -> bool { return TriangleContainsPoint(a,b,c,p) }

ParseVector2 :: proc(value: string, delimiter: u8) -> (Vec2, bool) {
	result: Vec2 = {}; start:=0; parts:[dynamic]f32={}; defer delete(parts)
	for i:=0; i<=len(value); i+=1 { if i==len(value) || value[i]==delimiter { if i==start{return result,false}; v,ok:=strconv.parse_f32(value[start:i]); if !ok{return result,false}; append(&parts,v); start=i+1 } }
	if len(parts)!=2{return result,false}; return Vec2{parts[0],parts[1]},true
}
ParseVector3 :: proc(value: string, delimiter: u8) -> (Vec3, bool) {
	result: Vec3 = {}; start:=0; parts:[dynamic]f32={}; defer delete(parts)
	for i:=0; i<=len(value); i+=1 { if i==len(value) || value[i]==delimiter { if i==start{return result,false}; v,ok:=strconv.parse_f32(value[start:i]); if !ok{return result,false}; append(&parts,v); start=i+1 } }
	if len(parts)!=3{return result,false}; return Vec3{parts[0],parts[1],parts[2]},true
}

StaticStringHashString :: proc(value: string) -> int { hash:u32=5381; for b in value { hash = (hash << 5) + hash + u32(b) }; return int(i32(hash)) }
StaticStringHashBytes :: proc(value: []u8) -> int { hash:u32=5381; for b in value { hash = (hash << 5) + hash + u32(b) }; return int(i32(hash)) }
StaticStringHash :: proc{StaticStringHashString, StaticStringHashBytes}
EqualsOrdinalIgnoreCaseUtf8String :: proc(a,b: string) -> bool { if len(a)!=len(b){return false}; for i:=0;i<len(a);i+=1 {ca:=a[i];cb:=b[i];if ca>='A'&&ca<='Z'{ca+=32};if cb>='A'&&cb<='Z'{cb+=32};if ca!=cb{return false}};return true }
EqualsOrdinalIgnoreCaseUtf8Bytes :: proc(a,b: []u8) -> bool { if len(a)!=len(b){return false}; for i:=0;i<len(a);i+=1 {ca:=a[i];cb:=b[i];if ca>='A'&&ca<='Z'{ca+=32};if cb>='A'&&cb<='Z'{cb+=32};if ca!=cb{return false}};return true }
EqualsOrdinalIgnoreCaseUtf8 :: proc{EqualsOrdinalIgnoreCaseUtf8String, EqualsOrdinalIgnoreCaseUtf8Bytes}
AmountInCommon :: proc(a,b: string) -> int { n:=0; for i:=0; i<min(len(a),len(b)); i+=1 { if a[i]==b[i] {n+=1} else {break} }; return n }
NormalizePathSingle :: proc(path: string) -> string { b:=strings.builder_make(); defer strings.builder_destroy(&b); previous_slash:=false; for c in path { if c=='\\' || c=='/' {if !previous_slash {strings.write_byte(&b,'/');previous_slash=true}} else {strings.write_rune(&b,c);previous_slash=false} }; return strings.to_string(b) }
NormalizePathPair :: proc(a,b: string) -> string { bld:=strings.builder_make(); defer strings.builder_destroy(&bld); strings.write_string(&bld,a); strings.write_byte(&bld,'/'); strings.write_string(&bld,b); return NormalizePathSingle(strings.to_string(bld)) }
NormalizePathTriple :: proc(a,b,c: string) -> string { bld:=strings.builder_make(); defer strings.builder_destroy(&bld); strings.write_string(&bld,a); strings.write_byte(&bld,'/'); strings.write_string(&bld,b); strings.write_byte(&bld,'/'); strings.write_string(&bld,c); return NormalizePathSingle(strings.to_string(bld)) }
NormalizePath :: proc{NormalizePathSingle, NormalizePathPair, NormalizePathTriple}
Swap :: proc(a,b:^$T) { t:=a^; a^=b^; b^=t }

SmoothDamp :: proc(current,target:f32, velocity:^f32, smooth_time,max_speed,delta_time:f32) -> f32 { st:=math.max(0.0001,smooth_time); omega:=2/st; x:=omega*delta_time; exp:=1/(1+x+0.48*x*x+0.235*x*x*x); change:=current-target; original:=target; max_change:=max_speed*st; change=Clamp(change,-max_change,max_change); adjusted_target:=current-change; temp:=(velocity^+omega*change)*delta_time; velocity^=(velocity^-omega*temp)*exp; output:=adjusted_target+(change+temp)*exp; if (original-current)*(output-original)>0 {output=original;velocity^=(output-original)/delta_time}; return output }

tri_area :: proc(vertices: []Vec2) -> f32 { area:f32=0; if len(vertices)<3{return 0}; p:=len(vertices)-1; for q:=0;q<len(vertices);q+=1 { area += vertices[p][0]*vertices[q][1]-vertices[q][0]*vertices[p][1]; p=q }; return area*0.5 }
tri_inside :: proc(a,b,c,p: Vec2) -> bool { p0:=c-b; p1:=a-c; p2:=b-a; ap:=p-a; bp:=p-b; cp:=p-c; return Cross(p0,bp)>=0 && Cross(p2,ap)>=0 && Cross(p1,cp)>=0 }
Triangulate :: proc(vertices: []Vec2, indices: ^[dynamic]int) {
	clear(indices)
	n := len(vertices)
	if n < 3 { return }
	v: [dynamic]int = {}
	defer delete(v)
	if tri_area(vertices) > 0 {
		for i := 0; i < n; i += 1 { append(&v, i) }
	} else {
		for i := 0; i < n; i += 1 { append(&v, n-1-i) }
	}
	nv := n
	count := 2 * nv
	m := nv - 1
	for nv > 2 {
		if count <= 0 { return }
		count -= 1
		u := m
		if u >= nv { u = 0 }
		vv := u + 1
		if vv >= nv { vv = 0 }
		w := vv + 1
		if w >= nv { w = 0 }
		a := vertices[v[u]]
		b := vertices[v[vv]]
		c := vertices[v[w]]
		if Cross(b-a, c-a) > 0 {
			snip := true
			for p := 0; p < nv; p += 1 {
				if p == u || p == vv || p == w { continue }
				if tri_inside(a, b, c, vertices[v[p]]) { snip = false; break }
			}
			if snip {
				append(&indices^, v[u], v[vv], v[w])
				for s, t := vv, vv+1; t < nv; s, t = s+1, t+1 { v[s] = v[t] }
				nv -= 1
				count = 2 * nv
				m = vv
			}
		} else {
			m = vv
		}
	}
}

// ===== merged from Utility/Converters.odin =====


Vector2Converter :: struct {}
Vector3Converter :: struct {}
Vector4Converter :: struct {}
Matrix3x2Converter :: struct {}
FloatVectorJsonConverter :: struct {}
IntVectorJsonConverter :: struct {}
FloatVectorToString :: proc(values: []f32) -> string { b:=strings.builder_make(); defer strings.builder_destroy(&b); strings.write_string(&b,"["); for i,v in values { if i>0 {strings.write_string(&b,", ")}; strings.write_string(&b,fmt.aprintf("%g",v)) }; strings.write_string(&b,"]"); return strings.to_string(b) }
IntVectorToString :: proc(values: []int) -> string { b:=strings.builder_make(); defer strings.builder_destroy(&b); strings.write_string(&b,"["); for i,v in values { if i>0 {strings.write_string(&b,", ")}; strings.write_string(&b,fmt.aprintf("%d",v)) }; strings.write_string(&b,"]"); return strings.to_string(b) }

// ===== merged from Utility/Ease.odin =====


Linear :: proc(t: f32) -> f32 { return t }
InQuad :: proc(t: f32) -> f32 { return t*t }
OutQuad :: proc(t: f32) -> f32 { return t*(2-t) }
InOutQuad :: proc(t: f32) -> f32 { if t < 0.5 do return 2*t*t; return -1+(4-2*t)*t }
SineIn :: proc(t: f32) -> f32 { return 1-math.cos(t*f32(math.PI)*0.5) }
SineOut :: proc(t: f32) -> f32 { return math.sin(t*f32(math.PI)*0.5) }
SineInOut :: proc(t: f32) -> f32 { return -(math.cos(f32(math.PI)*t)-1)*0.5 }

// ===== merged from Utility/Log.odin =====


LogState :: struct { History: [dynamic]string, OnInfo: proc(msg: string), OnWarning: proc(msg: string), OnError: proc(msg: string) }
log_append :: proc(state: ^LogState, message: string) { append(&state.History,message) }
LogInfo :: proc(state: ^LogState, message: string) { log_append(state,message); if state.OnInfo != nil { state.OnInfo(message) } else { fmt.println(message) } }
LogWarning :: proc(state: ^LogState, message: string) { log_append(state,message); if state.OnWarning != nil { state.OnWarning(message) } else { fmt.println(message) } }
LogError :: proc(state: ^LogState, message: string) { log_append(state,message); if state.OnError != nil { state.OnError(message) } else { fmt.println(message) } }
LogClearHistory :: proc(state: ^LogState) { clear(&state.History) }
LogHistory :: proc(state: ^LogState) -> []string { return state.History[:] }

// ===== merged from Utility/Pool.odin =====

Pool :: struct($T: typeid) { Available: [dynamic]T }
PoolGet :: proc(pool: ^Pool($T)) -> T { if len(pool.Available)>0 { n:=len(pool.Available)-1; v:=pool.Available[n]; resize(&pool.Available,n); return v }; return T{} }
PoolReturn :: proc(pool: ^Pool($T), value:T){append(&pool.Available,value)}
PoolClear :: proc(pool: ^Pool($T)){clear(&pool.Available)}
IPoolable :: #type proc(value: rawptr)

// ===== merged from Utility/Rng.odin =====


Rng :: struct { Seed: u64 }
RngMake :: proc(seed: u64) -> Rng { return Rng{Seed=seed} }
RngU64 :: proc(r: ^Rng) -> u64 { r.Seed += 0x9e3779b97f4a7c15; n:=r.Seed; n=(n ~ (n>>30))*0xbf58476d1ce4e5b9; n=(n ~ (n>>27))*0x94d049bb133111eb; return n ~ (n>>31) }
RngU64Max :: proc(r: ^Rng, max:u64) -> u64 { if max==0{return 0}; return RngU64(r)%max }
RngU64Range :: proc(r: ^Rng,min,max:u64)->u64{return min+RngU64Max(r,max-min)}
RngU32 :: proc(r: ^Rng)->u32{return u32(RngU64(r))}
RngU32Max :: proc(r:^Rng,max:u32)->u32{if max==0{return 0};return RngU32(r)%max}
RngU32Range :: proc(r:^Rng,min,max:u32)->u32{return min+RngU32Max(r,max-min)}
RngInt :: proc(r:^Rng)->int{return int(RngU64(r))}
RngIntMax :: proc(r:^Rng,max:int)->int{if max<=0{return 0};return int(RngU64Max(r,u64(max)))}
RngIntRange :: proc(r:^Rng,min,max:int)->int{return min+RngIntMax(r,max-min)}
RngFloat :: proc(r:^Rng)->f32{return f32(RngU32(r)>>8)/f32(1<<24)}
RngFloatMax :: proc(r:^Rng,max:f32)->f32{return RngFloat(r)*max}
RngFloatRange :: proc(r:^Rng,min,max:f32)->f32{return min+RngFloatMax(r,max-min)}
RngDouble :: proc(r:^Rng)->f64{return f64(RngU64(r)>>11)/f64(1<<53)}
RngBoolean :: proc(r:^Rng)->bool{return (RngU64(r)&1)!=0}
RngChance :: proc(r:^Rng,p:f32)->bool{return RngFloat(r)<p}
RngAngle :: proc(r:^Rng)->f32{return RngFloatMax(r,f32(math.TAU))}
RngSpread :: proc(r:^Rng, angle, spread:f32)->f32{return angle+RngFloatRange(r,-spread,spread)}
RngChoose :: proc(r:^Rng, choices: []$T)->T{if len(choices)==0{return {}};return choices[RngIntMax(r,len(choices))]}
RngShuffle :: proc(r:^Rng, values: []$T){for i:=len(values)-1;i>0;i-=1{j:=RngIntMax(r,i+1);values[i],values[j]=values[j],values[i]}}
RngPointInside :: proc(r:^Rng, rect: Rect)->Vec2{return RectOn(rect,RngFloat(r),RngFloat(r))}

// ===== merged from Utility/StackList.odin =====

StackList4 :: struct($T: typeid) { Data: [4]T, Count: int }
StackList8 :: struct($T: typeid) { Data: [8]T, Count: int }
StackList16 :: struct($T: typeid) { Data: [16]T, Count: int }
StackList32 :: struct($T: typeid) { Data: [32]T, Count: int }
StackList64 :: struct($T: typeid) { Data: [64]T, Count: int }

stack_add :: proc(list: ^$L, value: $T) where intrinsics.type_is_struct(L) {
	if list.Count >= len(list.Data) { panic("Exceeding Capacity of StackList") }; list.Data[list.Count]=value; list.Count+=1
}
StackList4Add :: proc(list: ^StackList4($T), value:T){stack_add(list,value)}
StackList8Add :: proc(list: ^StackList8($T), value:T){stack_add(list,value)}
StackList16Add :: proc(list: ^StackList16($T), value:T){stack_add(list,value)}
StackList32Add :: proc(list: ^StackList32($T), value:T){stack_add(list,value)}
StackList64Add :: proc(list: ^StackList64($T), value:T){stack_add(list,value)}
StackList4Clear :: proc(list: ^StackList4($T)){list.Count=0}
StackList8Clear :: proc(list: ^StackList8($T)){list.Count=0}
StackList16Clear :: proc(list: ^StackList16($T)){list.Count=0}
StackList32Clear :: proc(list: ^StackList32($T)){list.Count=0}
StackList64Clear :: proc(list: ^StackList64($T)){list.Count=0}

// ===== merged from Utility/TriangulationEnumerator.odin =====


TriangulationEnumerable :: struct { Vertices: []Vec2, Triangles: []int }
TriangulationEnumerableMake :: proc(vertices: []Vec2, triangles: []int) -> TriangulationEnumerable { return TriangulationEnumerable{vertices,triangles} }
TriangulationEnumerator :: struct { Vertices: []Vec2, Triangles: []int, Index: int, Current: Triangle }
TriangulationEnumeratorGet :: proc(value: TriangulationEnumerable) -> TriangulationEnumerator { return TriangulationEnumerator{Vertices=value.Vertices,Triangles=value.Triangles,Index=-3} }
TriangulationMoveNext :: proc(e: ^TriangulationEnumerator) -> bool { e.Index += 3; if e.Index+2 >= len(e.Triangles) { return false }; e.Current=Triangle{e.Vertices[e.Triangles[e.Index]],e.Vertices[e.Triangles[e.Index+1]],e.Vertices[e.Triangles[e.Index+2]]}; return true }
