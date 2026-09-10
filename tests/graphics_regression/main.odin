package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import SDL "vendor:sdl3"
import foster "ofoster:."

pipeline_errors: int
validation_errors: int

capture_log :: proc "c" (userdata: rawptr, category: SDL.LogCategory, priority: SDL.LogPriority, message: cstring) {
    context = runtime.default_context()
    text := string(message)
    if strings.contains(text, "OFoster: SDL_CreateGPUGraphicsPipeline failed") {
        assert(strings.contains(text, "vertex='incompatible'") && strings.contains(text, "fragment='hdr-fragment'"))
        pipeline_errors += 1
    }
    if strings.contains(text, "OFoster: draw requires both") { validation_errors += 1 }
    fmt.println(text)
}

begin :: proc(device: ^foster.GraphicsDevice) {
    device.CommandBuffer = SDL.AcquireGPUCommandBuffer(device.Device)
    assert(device.CommandBuffer != nil)
    device.InFrame = true
}

submit :: proc(device: ^foster.GraphicsDevice) {
    foster.end_render_pass(device)
    assert(SDL.SubmitGPUCommandBuffer(device.CommandBuffer))
    device.CommandBuffer = nil
    device.InFrame = false
    assert(SDL.WaitForGPUIdle(device.Device))
}

load_shader :: proc(shader: ^foster.Shader, device: ^foster.GraphicsDevice, directory, file, entry, name: string, stage: foster.ShaderStage, uniforms: int) {
    extension := device.Driver == .D3D12 ? "dxil" : "spv"
    path := fmt.tprintf("%s/%s.%s", directory, file, extension)
    code, err := os.read_entire_file(path, context.allocator)
    assert(err == nil)
    // Shader.CreateInfo retains Code for recreation. Freed after ShaderDispose.
    foster.ShaderInit(shader, device, foster.ShaderCreateInfo{
        Stage = stage, Code = code, EntryPoint = entry, UniformBufferCount = uniforms,
    }, name)
}

dispose_shader :: proc(shader: ^foster.Shader) {
    code := shader.CreateInfo.Code
    foster.ShaderDispose(shader)
    delete(code)
}

verify_pixels :: proc(texture: ^foster.Texture, expected: [4]f32) {
    data := foster.TextureDownloadData(texture)
    defer delete(data)
    assert(len(data) == foster.TextureMemorySize(texture))
    for pixel in 0..<texture.Width * texture.Height {
        #partial switch texture.Format {
        case .R16G16B16A16_FLOAT:
            values := ([^]f16)(raw_data(data))
            for component in 0..<4 { assert(f32(values[pixel * 4 + component]) == expected[component]) }
        case .R32G32B32A32_FLOAT:
            values := ([^]f32)(raw_data(data))
            for component in 0..<4 { assert(values[pixel * 4 + component] == expected[component]) }
        case .R11G11B10_UFLOAT:
            // Exact packed representation of RGB = (2, 4, 8).
            packed := ([^]u32)(raw_data(data))
            assert(packed[pixel] == (u32(16 << 6) | u32(17 << 6) << 11 | u32(18 << 5) << 22))
        }
    }
    // Exercise upload/readback of the same native bits on a sampled texture.
    clone: foster.Texture
    foster.TextureInit(&clone, texture.GraphicsDevice, texture.Width, texture.Height, texture.Format)
    defer foster.TextureDispose(&clone)
    foster.TextureSetData(&clone, raw_data(data), len(data))
    roundtrip := foster.TextureDownloadData(&clone)
    defer delete(roundtrip)
    assert(len(roundtrip) == len(data))
    for value, i in data { assert(roundtrip[i] == value) }
}

run :: proc(driver: foster.GraphicsDriver, directory: string) {
    driver_name: cstring = driver == .D3D12 ? "direct3d12" : "vulkan"
    device := foster.GraphicsDevice{Driver = driver}
    device.Device = SDL.CreateGPUDevice({.SPIRV, .DXIL}, false, driver_name)
    assert(device.Device != nil, string(SDL.GetError()))
    defer SDL.DestroyGPUDevice(device.Device)
    defer foster.graphics_device_dispose_caches(&device)
    fmt.println("Testing", driver)

    vertex, fragment: foster.Shader
    load_shader(&vertex, &device, directory, "vertex", "vertex_main", "hdr-vertex", .Vertex, 0)
    defer dispose_shader(&vertex)
    load_shader(&fragment, &device, directory, "fragment", "fragment_main", "hdr-fragment", .Fragment, 1)
    defer dispose_shader(&fragment)
    material: foster.Material
    foster.MaterialInit(&material, &vertex, &fragment)
    defer delete(material.Fragment.UniformBuffers[0])
    defer foster.UniformBufferDispose(&material.Fragment.UniformBufferObjects[0])
    mesh: foster.Mesh
    foster.MeshInitTyped(foster.BatcherVertex, &mesh, &device, foster.IndexFormat.Sixteen)
    defer foster.MeshDispose(&mesh)
    vertices := [3]foster.BatcherVertex{
        foster.MakeBatcherVertex({-1, -1}, {}, foster.White, foster.White),
        foster.MakeBatcherVertex({3, -1}, {}, foster.White, foster.White),
        foster.MakeBatcherVertex({-1, 3}, {}, foster.White, foster.White),
    }
    foster.MeshSetVerticesTyped(foster.BatcherVertex, &mesh, vertices[:])

    target: foster.Target
    attachments := [2]foster.TargetAttachmentSpec{
        {Format = .R16G16B16A16_FLOAT}, {Format = .R32G32B32A32_FLOAT},
    }
    foster.TargetInit(&target, &device, 16, 16, attachments[:], "HDR MRT")
    defer foster.TargetDispose(&target)
    command: foster.DrawCommand
    foster.DrawCommandFromMesh(&command, foster.DrawableTargetFromTarget(&target), &mesh, &material)
    defer foster.DrawCommandDispose(&command)
    assert(command.BlendMode == foster.BlendModePremultiply)
    assert(foster.BlendModeDisabled == foster.BlendModeMake(.Add, .One, .Zero))
    command.BlendMode = foster.BlendModeDisabled
    params := [1][4]f32{{2, 4, 8, 0.25}}
    foster.MaterialStageSetUniformBuffer(&material.Fragment, mem.slice_to_bytes(params[:]), 0)
    for frame in 0..<100 {
        begin(&device)
        foster.GraphicsDeviceDraw(&device, &command)
        submit(&device)
        if frame == 0 || frame == 99 {
            verify_pixels(foster.TargetAttachment(&target, 0), {2, 4, 8, 0.25})
            verify_pixels(foster.TargetAttachment(&target, 1), {4, 8, 16, 0.5})
        }
        free_all(context.temp_allocator)
    }
    assert(len(device.PipelineCache) == 1)
    fmt.println("PASS: RGBA16F/RGBA32F MRT, HDR values, alpha and upload/download stable for 100 frames")

    // Switching back to premultiplied blending must select a distinct pipeline.
    command.BlendMode = foster.BlendModePremultiply
    begin(&device)
    foster.GraphicsDeviceDraw(&device, &command)
    submit(&device)
    verify_pixels(foster.TargetAttachment(&target, 0), {3.5, 7, 14, 0.4375})
    assert(len(device.PipelineCache) == 2)
    command.BlendMode = foster.BlendModeDisabled
    fmt.println("PASS: premultiplied blending and pipeline cache separation")

    packed_target: foster.Target
    packed_attachments := [2]foster.TargetAttachmentSpec{
        {Format = .R11G11B10_UFLOAT}, {Format = .R16G16B16A16_FLOAT},
    }
    foster.TargetInit(&packed_target, &device, 16, 16, packed_attachments[:], "Packed HDR")
    defer foster.TargetDispose(&packed_target)
    command.Target = foster.DrawableTargetFromTarget(&packed_target)
    begin(&device)
    foster.GraphicsDeviceDraw(&device, &command)
    submit(&device)
    verify_pixels(foster.TargetAttachment(&packed_target, 0), {2, 4, 8, 0.25})
    fmt.println("PASS: packed R11G11B10_UFLOAT render and upload/download")

    before := validation_errors
    material.Vertex.Shader = nil
    begin(&device)
    for _ in 0..<100 { foster.GraphicsDeviceDraw(&device, &command) }
    submit(&device)
    material.Vertex.Shader = &vertex
    assert(validation_errors == before + 1)
    fmt.println("PASS: missing shader reports once without crashing")

    if driver == .D3D12 {
        incompatible: foster.Shader
        load_shader(&incompatible, &device, directory, "incompatible", "incompatible_vertex", "incompatible", .Vertex, 0)
        defer dispose_shader(&incompatible)
        material.Vertex.Shader = &incompatible
        before_pipeline := pipeline_errors
        for _ in 0..<3 {
            begin(&device)
            foster.GraphicsDeviceDraw(&device, &command)
            submit(&device)
        }
        assert(pipeline_errors == before_pipeline + 1)
        assert(len(device.FailedPipelineHashes) == 1)
        foster.ShaderRecreate(&incompatible, incompatible.CreateInfo)
        assert(len(device.FailedPipelineHashes) == 0)
        begin(&device)
        foster.GraphicsDeviceDraw(&device, &command)
        submit(&device)
        assert(pipeline_errors == before_pipeline + 2)
        material.Vertex.Shader = &vertex
        begin(&device)
        foster.GraphicsDeviceDraw(&device, &command)
        submit(&device)
        verify_pixels(foster.TargetAttachment(&packed_target, 0), {2, 4, 8, 0.25})
        fmt.println("PASS: actual pipeline failure logs names/error once, recreation resets diagnostics, valid draw recovers")
    }
}

main :: proc() {
    assert(len(os.args) == 3, "usage: graphics-regression <d3d12|vulkan> <shader-directory>")
    assert(SDL.Init({.VIDEO}), string(SDL.GetError()))
    defer SDL.Quit()
    SDL.SetLogOutputFunction(capture_log, nil)
    driver := os.args[1] == "d3d12" ? foster.GraphicsDriver.D3D12 : foster.GraphicsDriver.Vulkan
    run(driver, os.args[2])
}
