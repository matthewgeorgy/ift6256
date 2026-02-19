package main

import os      	"core:os"
import flags    "core:flags"
import log      "core:log"
import strings  "core:strings"
import strconv	"core:strconv"
import slice	"core:slice"
import fmt		"core:fmt"
import win32    "core:sys/windows"
import rl		"vendor:raylib"

SCR_WIDTH 	:: 1024
SCR_HEIGHT 	:: 1024

xkcd_color :: struct
{
	Name : string,
	Value : v3,
}

image_tile :: struct
{
	Offset : v2u,
	Size : v2u, 
}

opts :: struct
{
	name : string `args:"required" usage:"Input image filename"`, 
    seed : u32 `usage:"Initial seed [default: 0, random seed each time]"`,
	x : u32 `usage:"Number of tiles in X"`,
	y : u32 `usage:"Number of tiles in Y"`,
}

main :: proc()
{
    ///////////////////////////////////////////////////////////////////////////
    // Opts

	Opts : opts

	flags.parse_or_exit(&Opts, os.args, .Odin)

    Seed : u32 = (Opts.seed != 0) ? Opts.seed : GetEntropy()
	TileCountX : u32 = (Opts.x != 0) ? Opts.x : 8
	TileCountY : u32 = (Opts.y != 0) ? Opts.y : 8

	ImageFileName := Opts.name

	fmt.println("Seed:", Seed)

    ///////////////////////////////////////////////////////////////////////////
    // Setup

	Series := InitializeRandomSeries(Seed)
	Colors := LoadColorData()
	ColorPalette := BuildColorPalette(Colors[:], &Series)

	Image, Success := LoadImage(ImageFileName, false)
	if !Success
	{
		fmt.println("Failed to open file:", ImageFileName)
		return
	}

	PostprocessImage(Image, ColorPalette[:])

	TileWidth : u32 = Image.Width / TileCountX
	TileHeight : u32 = Image.Height / TileCountY
	Tiles, Width, Height := GenerateImageTiles(Image, TileWidth, TileHeight)

	TiledImage := CreateImage(Width, Height)

	copy(TiledImage.Pixels, Image.Pixels)

    ///////////////////////////////////////////////////////////////////////////
    // Timers

	StartingTime, Frequency, UpdateFrame : win32.LARGE_INTEGER

	win32.QueryPerformanceCounter(&StartingTime)
	win32.QueryPerformanceFrequency(&Frequency)

	UpdateFrame = StartingTime + Frequency / 2
	TicksPerMillisecond := f32(Frequency) / 1000

    ///////////////////////////////////////////////////////////////////////////
    // Render

    rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(SCR_WIDTH, SCR_HEIGHT, "tiles")
	rl.SetTargetFPS(60)

	SourceRect := rl.Rectangle {
		x = 0,
		y = 0,
		width = real(TiledImage.Width),
		height = real(TiledImage.Height),
	}

	DestRect := rl.Rectangle {
		x = 0,
		y = 0,
		width = SCR_WIDTH,
		height = SCR_HEIGHT,
	}

	rlImage := rl.Image {
		data = raw_data(TiledImage.Pixels),
		width = i32(TiledImage.Width),
		height = i32(TiledImage.Height),
		mipmaps = 1,
		format = .UNCOMPRESSED_R32G32B32,
	}

	ShuffleTiles : bool = false

	for !rl.WindowShouldClose()
	{
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		End : win32.LARGE_INTEGER
		win32.QueryPerformanceCounter(&End)

		if rl.IsKeyPressed(.SPACE)
		{
			ShuffleTiles = !ShuffleTiles
		}

		if End >= UpdateFrame
		{
			if ShuffleTiles
			{
				ShuffleImage(TiledImage, Image, Tiles[:], &Series, TileWidth, TileHeight)
			}

			UpdateFrame = End + Frequency / 2
		}

		rlTexture := rl.LoadTextureFromImage(rlImage)

		rl.DrawTexturePro(rlTexture, SourceRect, DestRect, v2{}, 0, rl.WHITE)

		rl.EndDrawing()

		rl.UnloadTexture(rlTexture)
	}

	rl.CloseWindow()
}

LoadColorData :: proc() -> [dynamic]xkcd_color
{
	Colors : [dynamic]xkcd_color

	File, ok := os.read_entire_file("xkcd_colors.txt")
	defer delete(File)

	StringFile := string(File)

	HexColorToFloatColor("#010101")

	for Line in strings.split_lines_iterator(&StringFile)
	{
		Trimmed := strings.trim(Line, " ")
		Tokens := strings.fields(Trimmed)

		NameTokens := Tokens[0 : len(Tokens) - 1]
		ColorToken := Tokens[len(Tokens) - 1]

		Color := HexColorToFloatColor(ColorToken)

		// Add spaces between each token
		for I in 0..<len(NameTokens)-1
		{
			NameTokens[I] = strings.concatenate([]string{NameTokens[I], " "})
		}

		Name := strings.concatenate(NameTokens)

		append(&Colors, xkcd_color{Name, Color})
	}

	return Colors
}

HexColorToFloatColor :: proc(HexColor : string) -> v3
{
	Red := HexColor[1:3]
	Green := HexColor[3:5]
	Blue := HexColor[5:7]

	R, _ := strconv.parse_int(Red, 16)
	G, _ := strconv.parse_int(Green, 16)
	B, _ := strconv.parse_int(Blue, 16)

	FloatColor := v3 {
		real(R) / 255,
		real(G) / 255,
		real(B) / 255,
	}

	return FloatColor
}

BuildColorPalette :: proc(Colors : []xkcd_color, Series : ^random_series) -> [dynamic]xkcd_color
{
	ColorPalette : [dynamic]xkcd_color
	Indices : [dynamic]u32

	// Build 16-color palette
	for len(Indices) < 16
	{
		Index := RandomUInt(Series, u32(len(Colors)))

		if !slice.contains(Indices[:], Index)
		{
			append(&Indices, Index)
			append(&ColorPalette, Colors[Index])
		}
	}

	delete(Indices)

	return ColorPalette
}

PostprocessImage :: proc(Image : image, ColorPalette : []xkcd_color)
{
	for Y in 0..<Image.Height
	{
		for X in 0..<Image.Width
		{
			Pixel := ReadPixel(Image, X, Y)
			MinDistance : real = REAL_MAX
			ClosestColorIndex : int

			for Color, Index in ColorPalette
			{
				Delta := Pixel - Color.Value
				Dist := Length(Delta)
				if Dist < MinDistance
				{
					ClosestColorIndex = Index
					MinDistance = Dist
				}
			}

			WritePixel(Image, X, Y, ColorPalette[ClosestColorIndex].Value)
		}
	}
}

GenerateImageTiles :: proc(Image : image, TileWidth, TileHeight : u32) -> ([dynamic]image_tile, u32, u32)
{
	Tiles : [dynamic]image_tile
	Width, Height : u32

	X, Y : u32
	for Y = 0; Y <= Image.Height - TileHeight; Y += TileHeight
	{
		for X = 0; X <= Image.Width - TileWidth; X += TileWidth
		{
			Tile := image_tile {
				Offset = v2u{X, Y},
				Size = v2u{TileWidth, TileHeight},
			}

			append(&Tiles, Tile)
		}
	}

	Width = X
	Height = Y

	return Tiles, Width, Height
}

ShuffleImage :: proc(TiledImage, BaseImage : image, Tiles : []image_tile, Series : ^random_series, TileWidth, TileHeight : u32)
{
	Shuffle(Series, Tiles[:])

	BaseX, BaseY : u32
	for Tile, TileIndex in Tiles
	{
		for TileY in 0..<Tile.Size.y
		{
			for TileX in 0..<Tile.Size.x
			{
				TilePixelX := TileX + Tile.Offset.x
				TilePixelY := TileY + Tile.Offset.y

				PixelValue := ReadPixel(BaseImage, TilePixelX, TilePixelY)
				
				WritePixel(TiledImage, BaseX + TileX, BaseY + TileY, PixelValue)
			}
		}

		BaseX += TileWidth
		if BaseX >= TiledImage.Width
		{
			BaseX = 0
			BaseY += TileHeight
		}
	}
}

