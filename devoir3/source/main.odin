package main

import os      	"core:os"
import log      "core:log"
import strings  "core:strings"
import strconv	"core:strconv"
import slice	"core:slice"
import fmt		"core:fmt"
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

main :: proc()
{
	if len(os.args) < 2
	{
		fmt.println("Need an image filename...!")
		return
	}

	ImageFileName := os.args[1]

	Series := InitializeRandomSeries(GetEntropy())
	Colors := LoadColorData()
	ColorPalette := BuildColorPalette(Colors[:], &Series)

	Image, _ := LoadImage(ImageFileName, false)
	PostprocessImage(Image, ColorPalette[:])

	TileCountX : u32 = 8
	TileCountY : u32 = 8
	TileWidth : u32 = Image.Width / TileCountX
	TileHeight : u32 = Image.Height / TileCountY
	Tiles, Width, Height := GenerateImageTiles(Image, TileWidth, TileHeight)

	Shuffle(&Series, Tiles[:])

	TiledImage := CreateImage(Width, Height)

	BaseX, BaseY : u32
	for Tile, TileIndex in Tiles
	{
		for TileY in 0..<Tile.Size.y
		{
			for TileX in 0..<Tile.Size.x
			{
				TilePixelX := TileX + Tile.Offset.x
				TilePixelY := TileY + Tile.Offset.y

				PixelValue := ReadPixel(Image, TilePixelX, TilePixelY)
				
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

	SaveImage(TiledImage, "blah.png")

    ///////////////////////////////////////////////////////////////////////////
    // Render

    // rl.SetTraceLogLevel(.NONE)
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

	for !rl.WindowShouldClose()
	{
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rlImage := rl.Image {
			data = raw_data(TiledImage.Pixels),
			width = i32(TiledImage.Width),
			height = i32(TiledImage.Height),
			mipmaps = 1,
			format = .UNCOMPRESSED_R32G32B32,
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
	for Y = 0; Y < Image.Height - TileHeight; Y += TileHeight
	{
		for X = 0; X < Image.Width - TileWidth; X += TileWidth
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

