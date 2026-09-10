# Foster → OFoster 移植映射

本文档记录上游 C# Foster 源文件与本项目 Odin 文件的对应关系，以及移植中
有意做出的 API 差异。同步上游时，先对照本表定位每个上游文件在 Odin 侧的
落点，再更新 `README.md` 的 sync baseline 一节与 `framework.odin`
里的版本号。

## 布局原则

- 上游仓库是 C# 的"一类型一文件 + 命名空间目录"结构；Odin 惯例是单一包内
  按主题分文件。因此 OFoster 不复刻上游目录形状，改用本表承担映射职责。
- 公共 API 全部在根包 `foster_framework`（`import foster "ofoster:."`），
  以少量主题文件组织（`framework`/`foundation`/`graphics`/`images`/`input`/
  `spatial`/`utility`/`storage`/`web`，外加 `#+build` 平台对与 `web.odin`）。
  仅保留两个内部子包：`Internal/ThirdParty`（vendored C 绑定）与
  `Internal/Web`（js 桥的 JS 侧）。
- 历史上的 `Graphics/`、`Input/`、`Storage/`、`Spatial/`、`Utility/`、
  `Images/`、`Extensions/` 别名转发层已于 2026-09 移除。

## 文件映射

| 上游 Foster (C#) | OFoster (Odin) | 状态 |
| --- | --- | --- |
| `Framework/App.cs`、`Framework/Window.cs`、`Framework/Platform*.cs`、主循环 | `framework.odin` | 已移植（App/Window 合于一文件） |
| `Framework/Time.cs` 等基础数值/颜色/Point2 | `foundation.odin` | 已移植 |
| `Framework/Graphics/GraphicsDevice.cs` | `graphics.odin` | 已移植 |
| `Framework/Graphics/Texture.cs`、`Target.cs`、`Shader.cs`、`Material.cs`、`Mesh.cs`、`GraphicsBuffer.cs`、`UniformBuffer.cs` | `graphics.odin` | 已移植 |
| `Framework/Graphics/Batcher.cs` | `graphics.odin`（Batcher 一节） | 已移植 |
| `Framework/Graphics/SpriteFont.cs` | `images.odin` | 已移植 |
| `Framework/Graphics/Subtexture.cs` | `graphics.odin`（Subtexture 一节） | 已移植 |
| 顶点类型 / 类型化初始化辅助（PosTexColVertex、`MeshInitTyped` 等） | `graphics.odin` | 已移植 |
| 计算管线 / uniform buffer | `graphics.odin` | 已移植 |
| `Framework/Graphics/Defaults/*` | `graphics.odin`（`DefaultResources*` 一节） | 已移植 |
| `Framework/Input/*`（Input、States、Controller） | `input.odin` | 已移植 |
| `Framework/Input/Bindings/*`、`BindingSet` | `input.odin`（Bindings/Sets 一节） | 已移植 |
| `Framework/Input/VirtualInput/*` | `input.odin`（Virtual 一节） | 已移植 |
| 光标 / 独立输入供给（工具、测试用） | `input.odin`（Provider/Cursor 一节） | 已移植 |
| `Framework/Storage/*` | `storage.odin` + `storage_os_*.odin` + `storage_path_*.odin`（native/web 按 `#+build` 分文件） | 已移植 |
| Web (js_wasm32) 桥 | `web.odin` + `Internal/Web/foster.js` | 已移植 |
| 线程 ID 平台差异 | `platform_thread_native.odin` / `platform_thread_web.odin` | 已移植 |
| `Framework/Spatial/*`（Rect、Circle、Polygon 等） | `spatial.odin` | 已移植（RectInt 以本文件实现为准） |
| `Framework/Utils/*`（Calc、Ease、Log、Pool、Rng 等） | `utility.odin` | 已移植 |
| `Framework/Extensions/*` | `utility.odin`（Extensions 一节） | 已移植 |
| `Framework/Images/*`（Image、Packer、Aseprite、Font、MsdfFont） | `images.odin` | 已移植 |
| QOI / stb_truetype 绑定 | `Internal/ThirdParty/`（唯一保留的子包） | vendored |

C# 的接口（`IVertex`、`IProvideKerning`、`IDrawableTarget` 等）在 Odin 侧
不设占位类型：顶点布局由 `VertexFormat` 运行时描述，字距由数据字段提供，
可绘制目标由 `DrawableTarget` 值类型表达。

## 有意的 API 差异

C# 的重载/实例方法在 Odin 侧多为"前缀 + 显式名"或 proc group，调用方需要注意：

| C# / 旧门面 | OFoster | 说明 |
| --- | --- | --- |
| `Calc.Approach(f/Vector2/Vector3, ...)` | `Approach`（proc group：`ApproachScalar`/`ApproachVec2`/`Approach3`） | 标量版即原根包 `Approach`，已更名 `ApproachScalar`，组名 `Approach` 可按参数分发 |
| `Calc.Map(val,min,max)` / `Calc.Map(val,min,max,nmin,nmax)` | `Map` / `MapTo` | 展开域版本不设 `MapExtended`/`MapRange` 别名（与 `MapTo` 重复） |
| `Calc.Down` 等方向常量 | `Down`/`Up`/`Left`/`Right`... | 键盘态辅助原名 `Down`/`Pressed`/`Released` 已更名 `KeyboardDown`/`KeyboardPressed`/`KeyboardReleased`，让出常量名 |
| `Calc.TriangleArea(a,b,c)` | `TriangleAreaVec2` | `TriangleArea` 保留给 `Triangle` 结构版本 |
| `Texture.SetData` 区域重载 | `TextureSetDataRegion` / `TextureSetDataRegionRect` | 两个显式名，不设同名 proc group |
| `KeyboardState.Down(key)` 等 | `KeyboardDown(state, key)` 等 | 见上 |
| 子包导入（`ofoster:Graphics` 等） | 一律 `import foster "ofoster:."` | 门面层已删除 |

另有若干类型并存但语义不同，属于历史形态，暂不合并：

- `Point2`（struct，根包）与 `Vec2`（`[2]f32`，spatial）——整数像素坐标 vs 浮点向量。
- `Vec2f`（input 内部鼠标数据）。

## 同步上游的流程

1. 在上游仓库对比 sync baseline commit 之后的变更清单。
2. 按本表把每个改动的 C# 文件映射到对应 Odin 文件并移植。
3. 跑 `tests/webtest`（native + `js_wasm32`）与 `tests/graphics_regression`，以及
   `build/glade-regression` 与 `build/exhaustive-format-check`（若适用）。
4. 更新 `README.md` 的 baseline、`framework.odin` 的版本号和本表。
