package main

import fmt      "core:fmt"
import win32    "core:sys/windows"
import os       "core:os"
import flags    "core:flags"
import libc		"core:c/libc"
import strconv	"core:strconv"
import strings	"core:strings"

import glfw     "vendor:glfw"
import d3d      "vendor:directx/d3d11"
import dxgi     "vendor:directx/dxgi"
import dxc      "vendor:directx/d3d_compiler"
import stbi     "vendor:stb/image"

opts :: struct
{
    seed : uint `usage:"Initial seed [default: 0, random seed each time]"`,
    name : string `usage:"Output filename WITHOUT extension, saved as a .PNG [default: rocks]"`,
	window : bool `usage:"Interactive 3D window [default: false]"`,
	verbose : bool `usage:"Append seed to filename [default : false]"`,
}

vertex :: struct
{
    Position : v3,
    Normal : v3,
    TexCoord : v2,
}

transform :: struct
{
    World : m4,
    View : m4,
    Proj : m4,
}

camera :: struct
{
    Pos : v3,
    Front : v3,
    Up : v3,
}

SCR_WIDTH           :: 1280
SCR_HEIGHT          :: 720

gCamera : camera

main :: proc()
{
    Opts : opts

    flags.parse_or_exit(&Opts, os.args, .Odin)

    Seed := u64(Opts.seed)

    if Opts.seed == 0
    {
        Seed = GetEntropy()
    }

	fmt.println("Seed:", Seed)

    ///////////////////////////////////////////////////////////////////////////
    // GLFW setup

    glfw.Init()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	if !Opts.window
	{
		glfw.WindowHint(glfw.VISIBLE, glfw.FALSE)
	}

    Window := glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, "rocks", nil, nil)
    hWnd := glfw.GetWin32Window(Window)

    glfw.SetCursorPosCallback(Window, MouseCallback)
    glfw.SetInputMode(Window, glfw.CURSOR, glfw.CURSOR_DISABLED)

    ///////////////////////////////////////////////////////////////////////////
    // D3D11 setup

    SwapChainDesc := dxgi.SWAP_CHAIN_DESC {
        BufferDesc = {
            Width = SCR_WIDTH,
            Height = SCR_HEIGHT,
            Format = .R8G8B8A8_UNORM,
            RefreshRate = {60, 1},
        },
        SampleDesc = {1, 0},
        BufferUsage = {.RENDER_TARGET_OUTPUT},
        BufferCount = 2,
        OutputWindow = hWnd,
        Windowed = win32.TRUE,
        SwapEffect = .DISCARD,
    }

    DepthBufferDesc := d3d.TEXTURE2D_DESC {
        Width = SCR_WIDTH,
        Height = SCR_HEIGHT,
        Format = .D24_UNORM_S8_UINT,
        MipLevels = 1,
        ArraySize = 1,
        SampleDesc = {1, 0},
        BindFlags = {.DEPTH_STENCIL},
    }

    Device : ^d3d.IDevice
    Context : ^d3d.IDeviceContext
    SwapChain : ^dxgi.ISwapChain

    d3d.CreateDeviceAndSwapChain(nil, .HARDWARE, nil, {.DEBUG}, nil, 0, d3d.SDK_VERSION,
        &SwapChainDesc, &SwapChain, &Device, nil, &Context)

    Framebuffer, DepthBuffer : ^d3d.ITexture2D
    FramebufferRTV : ^d3d.IRenderTargetView
    FramebufferDSV : ^d3d.IDepthStencilView

    SwapChain->GetBuffer(0, d3d.ITexture2D_UUID, cast(^rawptr)&Framebuffer)
    Device->CreateRenderTargetView(Framebuffer, nil, &FramebufferRTV)
    Device->CreateTexture2D(&DepthBufferDesc, nil, &DepthBuffer)
    Device->CreateDepthStencilView(DepthBuffer, nil, &FramebufferDSV)

    Context->OMSetRenderTargets(1, &FramebufferRTV, FramebufferDSV)

    Viewport := d3d.VIEWPORT {
        Width = SCR_WIDTH,
        Height = SCR_HEIGHT,
        MaxDepth = 1.0,
    }

    Context->RSSetViewports(1, &Viewport)

    RasterizerState : ^d3d.IRasterizerState
    RasterizerDesc := d3d.RASTERIZER_DESC {
        FillMode = .SOLID,
        CullMode = .NONE,
        DepthClipEnable = win32.TRUE,
    }

    Device->CreateRasterizerState(&RasterizerDesc, &RasterizerState)
    Context->RSSetState(RasterizerState)

    ///////////////////////////////////////////////////////////////////////////
    // Shaders

    VS : ^d3d.IVertexShader
    PS : ^d3d.IPixelShader
    VSBlob, PSBlob : ^d3d.IBlob

	dxc.CompileFromFile(win32.L("source/shaders/shader.vs"), nil, nil, "main", "vs_5_0", 0, 0, &VSBlob, nil)
	dxc.CompileFromFile(win32.L("source/shaders/shader.ps"), nil, nil, "main", "ps_5_0", 0, 0, &PSBlob, nil)
    Device->CreateVertexShader(VSBlob->GetBufferPointer(), VSBlob->GetBufferSize(), nil, &VS)
    Device->CreatePixelShader(PSBlob->GetBufferPointer(), PSBlob->GetBufferSize(), nil, &PS)

    Context->VSSetShader(VS, nil, 0)
    Context->PSSetShader(PS, nil, 0)

    ///////////////////////////////////////////////////////////////////////////
    // Noise generation

    Vertices, Indices := GenerateRockMesh(Seed)

    ///////////////////////////////////////////////////////////////////////////
    // Buffer setup

    VertexBuffer, IndexBuffer : ^d3d.IBuffer
    VertexBufferView : ^d3d.IShaderResourceView

    VertexBufferDesc := d3d.BUFFER_DESC {
        Usage = .DEFAULT,
        ByteWidth = u32(len(Vertices) * size_of(vertex)),
        StructureByteStride = u32(size_of(vertex)),
        BindFlags = {.SHADER_RESOURCE},
        MiscFlags = {.BUFFER_STRUCTURED},
    }

    VertexBufferSubData := d3d.SUBRESOURCE_DATA {
        pSysMem = &Vertices[0],
    }

    IndexBufferDesc := d3d.BUFFER_DESC {
        ByteWidth = u32(len(Indices)) * size_of(u32),
        BindFlags = {.INDEX_BUFFER},
    }

    IndexBufferSubData := d3d.SUBRESOURCE_DATA {
        pSysMem = &Indices[0],
    }

    VertexBufferViewDesc := d3d.SHADER_RESOURCE_VIEW_DESC {
        Format = .UNKNOWN,
        ViewDimension = .BUFFER,
        Buffer = {
            FirstElement = 0,
            NumElements = u32(len(Vertices)),
        },
    }

    Device->CreateBuffer(&VertexBufferDesc, &VertexBufferSubData, &VertexBuffer)
    Device->CreateBuffer(&IndexBufferDesc, &IndexBufferSubData, &IndexBuffer)
    Device->CreateShaderResourceView(VertexBuffer, &VertexBufferViewDesc, &VertexBufferView)

    ///////////////////////////////////////////////////////////////////////////
    // Texture

    RockTexture : ^d3d.ITexture2D
    RockTextureSRV : ^d3d.IShaderResourceView

    TextureWidth, TextureHeight, NumChannels : i32

    TextureData := stbi.load("assets/rock_texture.jpg", &TextureWidth, &TextureHeight, &NumChannels, 4)

    RockTextureDesc := d3d.TEXTURE2D_DESC {
        Width = u32(TextureWidth),
        Height = u32(TextureHeight),
        Usage = .DEFAULT,
        Format = .R8G8B8A8_UNORM,
        MipLevels = 0,
        ArraySize = 1,
        SampleDesc = {1, 0},
        BindFlags = {.SHADER_RESOURCE, .RENDER_TARGET},
		MiscFlags = {.GENERATE_MIPS},
    }

    RockTextureSubData := d3d.SUBRESOURCE_DATA {
        pSysMem = TextureData,
        SysMemPitch = u32(TextureWidth) * 4,
    }

    Device->CreateTexture2D(&RockTextureDesc, nil, &RockTexture)

    RockTextureSRVDesc := d3d.SHADER_RESOURCE_VIEW_DESC {
        Format = RockTextureDesc.Format,
        ViewDimension = .TEXTURE2D,
        Texture2D = {
            MipLevels = 4,
            MostDetailedMip = 0,
        }
    }

    Device->CreateShaderResourceView(RockTexture, &RockTextureSRVDesc, &RockTextureSRV)

	Context->UpdateSubresource(RockTexture, 0, nil, TextureData, u32(TextureWidth) * 4, 0)

	Context->GenerateMips(RockTextureSRV)

    ///////////////////////////////////////////////////////////////////////////
    // Sampler

    LinearSampler : ^d3d.ISamplerState

    LinearSamplerDesc := d3d.SAMPLER_DESC {
        Filter = .MIN_MAG_MIP_LINEAR,
        AddressU = .WRAP,
        AddressV = .WRAP,
        AddressW = .WRAP,
        ComparisonFunc = .NEVER,
        MinLOD = 0,
        MaxLOD = d3d.FLOAT32_MAX,
    }

    Device->CreateSamplerState(&LinearSamplerDesc, &LinearSampler)

    ///////////////////////////////////////////////////////////////////////////
    // Transform

    Transform : transform
    TransformBuffer : ^d3d.IBuffer

    TransformBufferDesc := d3d.BUFFER_DESC {
        Usage = .DEFAULT,
        ByteWidth = u32(size_of(transform)),
        BindFlags = {.CONSTANT_BUFFER},
    }

    Device->CreateBuffer(&TransformBufferDesc, nil, &TransformBuffer)

    // gCamera.Pos   = v3{-17.5, 50, -80}
	gCamera.Pos   = v3{-60, 45, -100}
    gCamera.Front = v3{0.5, -0.25, 0.8}
    gCamera.Up    = v3{0, 1, 0}

    ///////////////////////////////////////////////////////////////////////////
    // Staging texture

	StagingTexture : ^d3d.ITexture2D

	StagingTextureDesc : d3d.TEXTURE2D_DESC

	Framebuffer->GetDesc(&StagingTextureDesc)

	StagingTextureDesc.BindFlags = {}
	StagingTextureDesc.Usage = .STAGING
	StagingTextureDesc.CPUAccessFlags = {.READ, .WRITE}

	Device->CreateTexture2D(&StagingTextureDesc, nil, &StagingTexture)

    ///////////////////////////////////////////////////////////////////////////
    // Main loop

	WroteImage := false

    Context->IASetPrimitiveTopology(.TRIANGLELIST)

	CurrentFrame, LastFrame : real
	DeltaTime : real

    for !glfw.WindowShouldClose(Window)
    {
		CurrentFrame = real(glfw.GetTime())
		DeltaTime = CurrentFrame - LastFrame
		LastFrame = CurrentFrame

        glfw.PollEvents()
        ProcessInput(Window, DeltaTime)

		ClearColor := v4{0, 0, 0, 1}

        Transform.World = Mat4Scale(10) * Mat4Rotate(50 * CurrentFrame, v3{0, 1, 0}) * Mat4Translate(v3{-X_SIZE/2, 0, -Y_SIZE/2})
        Transform.View = Mat4LookAtLH(gCamera.Pos, gCamera.Pos + gCamera.Front, gCamera.Up)
        Transform.Proj = Mat4PerspectiveLH(45, real(SCR_WIDTH) / real(SCR_HEIGHT), 0.1, 1000.0)

        Context->UpdateSubresource(TransformBuffer, 0, nil, &Transform, 0, 0)
        Context->VSSetConstantBuffers(0, 1, &TransformBuffer)

        Context->IASetIndexBuffer(IndexBuffer, .R32_UINT, 0)
        Context->VSSetShaderResources(0, 1, &VertexBufferView)
        Context->PSSetSamplers(0, 1, &LinearSampler)
        Context->PSSetShaderResources(0, 1, &RockTextureSRV)

        Context->ClearRenderTargetView(FramebufferRTV, &ClearColor)
        Context->ClearDepthStencilView(FramebufferDSV, {.DEPTH, .STENCIL}, 1, 0)
        Context->DrawIndexed(u32(len(Indices)), 0, 0)

		if !WroteImage
		{
			Mapped : d3d.MAPPED_SUBRESOURCE

			Context->CopyResource(StagingTexture, Framebuffer)
			Context->Map(StagingTexture, 0, .READ, {}, &Mapped)

			Buffer := cast(^real)libc.malloc(uint(Mapped.RowPitch * StagingTextureDesc.Height * size_of(real)))
			libc.memcpy(Buffer, Mapped.pData, uint(Mapped.RowPitch * StagingTextureDesc.Height))

			BaseName : string

			if len(Opts.name) != 0
			{
				BaseName = Opts.name
			}
			else
			{
				BaseName = "rocks"
			}

			FileName : string

			if Opts.verbose
			{
				Buf : [128]byte
				SeedString := strconv.write_uint(Buf[:], Seed, 10)
				FileName = strings.concatenate([]string{BaseName, "_", SeedString, ".png"})
			}
			else
			{
				FileName = strings.concatenate([]string{BaseName, ".png"})
			}

			cFileName := strings.clone_to_cstring(FileName)

			stbi.write_png(cFileName, SCR_WIDTH, SCR_HEIGHT, 4, Buffer, 4 * SCR_WIDTH)

			WroteImage = true

			if !Opts.window
			{
				return
			}
		}

        SwapChain->Present(0, {})
    }
}

ProcessInput :: proc(Window : glfw.WindowHandle, DeltaTime : f32)
{
    CamSpeed : real = 50.5

    if glfw.GetKey(Window, glfw.KEY_ESCAPE) != 0
    {
        glfw.SetWindowShouldClose(Window, glfw.TRUE)
    }

    if glfw.GetKey(Window, glfw.KEY_W) != 0
    {
        gCamera.Pos += DeltaTime * CamSpeed * gCamera.Front
    }
    if glfw.GetKey(Window, glfw.KEY_S) != 0
    {
        gCamera.Pos -= DeltaTime * CamSpeed * gCamera.Front
    }
    if glfw.GetKey(Window, glfw.KEY_A) != 0
    {
        Dir := Normalize(Cross(gCamera.Front, gCamera.Up))
        gCamera.Pos += DeltaTime * CamSpeed * Dir
    }
    if glfw.GetKey(Window, glfw.KEY_D) != 0
    {
        Dir := Normalize(Cross(gCamera.Front, gCamera.Up))
        gCamera.Pos -= DeltaTime * CamSpeed * Dir
    }
}

MouseCallback :: proc "c" (Window : glfw.WindowHandle, XPos, YPos : f64)
{
    @(static) FirstMouse := true
    @(static) LastX := f64(SCR_WIDTH) / 2.0
    @(static) LastY := f64(SCR_HEIGHT) / 2.0
    @(static) Yaw : f64 = -90.0
    @(static) Pitch : f64 = 0.0
    MouseSens : real = 0.05

    if FirstMouse
    {
        LastX = XPos
        LastY = YPos
        FirstMouse = false
    }

    XOffset := LastX - XPos
    YOffset := LastY - YPos
    LastX = XPos
    LastY = YPos

    XOffset *= f64(MouseSens)
    YOffset *= f64(MouseSens)

    Yaw += XOffset
    Pitch += YOffset

    if Pitch > 89.9
    {
        Pitch = 89.9
    }
    if Pitch < -89.9
    {
        Pitch = -89.9
    }

    Dir := v3 {
        Cos(DegsToRads(real(Yaw))) * Cos(DegsToRads(real(Pitch))),
        Sin(DegsToRads(real(Pitch))),
        Sin(DegsToRads(real(Yaw))) * Cos(DegsToRads(real(Pitch))),
    }

    gCamera.Front = Normalize(Dir)
}

