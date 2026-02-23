
package main

import os "core:os"
import fmt "core:fmt"
import slice "core:slice"
import strings "core:strings"
import strconv "core:strconv"
import rl "vendor:raylib"

main :: proc()
{
	if len(os.args) < 2
	{
		fmt.println("missing arg")
		return
	}

	Image, _ := LoadImage(os.args[1], false)

	SCREEN_WIDTH := Min(Image.Width, 960)
	SCREEN_HEIGHT := Min(Image.Height, 960)

	LumImage := CreateImage(Image.Width, Image.Height)

	for Y in 0..<Image.Height
	{
		for X in 0..<Image.Width
		{
			Lum := Luminance(ReadPixel(Image, X, Y))
			WritePixel(LumImage, X, Y, v3{Lum, Lum, Lum})
		}
	}

	SaveImage(LumImage, "lum0.hdr", false)

	Series := InitializeRandomSeries(GetEntropy())
	Perm := GeneratePermutationVector(&Series)

	XkcdColors := LoadColors()
	Palette := ChoosePalette(&Series, XkcdColors[:])

	for Color in Palette
	{
		fmt.println(Color.Name, Color.Value)
	}

	PreprocessImage(Image, Palette[:])

	//////////////////////////////////////////////////////////////////////////
	// Render

    rl.SetTraceLogLevel(.NONE)
    rl.InitWindow(i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), "pxl")
    rl.SetTargetFPS(60)

	Sorted := CreateImage(Image.Width, Image.Height)

	rlImage := rl.Image {
		data = raw_data(Sorted.Pixels),
		width = i32(Sorted.Width),
		height = i32(Sorted.Height),
		mipmaps = 1,
		format = .UNCOMPRESSED_R32G32B32,
	}

	SrcRect := rl.Rectangle{0, 0, f32(Sorted.Width), f32(Sorted.Height)}
	DstRect := rl.Rectangle{0, 0, f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}

	Threshold : real = 1.0

    for !rl.WindowShouldClose()
    {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

		rlTexture := rl.LoadTextureFromImage(rlImage)

		rl.DrawTexturePro(rlTexture, SrcRect, DstRect, 0, 0, rl.WHITE)

		SortPixels(Image, Sorted, Threshold, SortPixelLeftToRight)

		Threshold = Max(Threshold - 0.05, 0.01)

        rl.EndDrawing()

		rl.UnloadTexture(rlTexture)
    }

	for Y in 0..<Sorted.Height
	{
		for X in 0..<Sorted.Width
		{
			Lum := Luminance(ReadPixel(Sorted, X, Y))
			WritePixel(LumImage, X, Y, v3{Lum, Lum, Lum})
		}
	}

	SaveImage(LumImage, "lum1.hdr", false)

    rl.CloseWindow()
}

SortPixels :: proc(Image, Sorted : image, BaseThreshold : real, SortProc : proc(v3, v3) -> bool)
{
	copy(Sorted.Pixels, Image.Pixels)

	for Y in 0..<Sorted.Height
	{
		Row := Sorted.Pixels[Y * Sorted.Width : (Y + 1) * Sorted.Width]

		X := 0

		for X < len(Row)
		{
			Threshold := BaseThreshold// + PerlinNoise(real(X), real(Y), Perm)

			for X < len(Row) && Luminance(Row[X]) <= Threshold
			{
				X += 1
			}

			Start := X

			for X < len(Row) && Luminance(Row[X]) > Threshold
			{
				X += 1
			}

			End := X

			if End - Start > 1
			{
				slice.sort_by(Row[Start : End], SortProc)
			}
		}
	}
}

xkcd_color :: struct
{
	Name : string,
	Value : v3,
}

LoadColors :: proc() -> [dynamic]xkcd_color
{
	Colors : [dynamic]xkcd_color

	File, ok := os.read_entire_file("xkcd_colors.txt")
	defer delete(File)

	StringFile := string(File)

	for Line in strings.split_lines_iterator(&StringFile)
	{
		Trimmed := strings.trim(Line, " ")
		Tokens := strings.fields(Trimmed)

		ColorToken := Tokens[len(Tokens) - 1]
		NameTokens := Tokens[0 : len(Tokens) - 1]

		Color := HexColorToFloatColor(ColorToken)
		Name : string

		for I in 0..<len(NameTokens) - 1
		{
			Token := &NameTokens[I]
			Token^ = strings.concatenate([]string{Token^, " "})
		}

		Name = strings.concatenate(NameTokens[:])

		append(&Colors, xkcd_color{Name, Color})
	}

	return Colors
}

ChoosePalette :: proc(Series : ^random_series, Colors : []xkcd_color) -> [dynamic]xkcd_color
{
	PALETTE_SIZE :: 200
	Indices : [dynamic]u32
	Palette : [dynamic]xkcd_color

	defer delete(Indices)

	for len(Indices) < PALETTE_SIZE
	{
		Index := RandomUInt(Series, u32(len(Colors)))
		if !(slice.contains(Indices[:], Index))
		{
			append(&Indices, Index)
			append(&Palette, Colors[Index])
		}
	}

	return Palette
}

PreprocessImage :: proc(Image : image, Palette : []xkcd_color)
{
	for Y in 0..<Image.Height
	{
		for X in 0..<Image.Width
		{
			MinDist : real = REAL_MAX
			ClosestColor : v3
			Pixel := ReadPixel(Image, X, Y)

			for Color in Palette
			{
				Dist := Length(Pixel - Color.Value)
				if Dist < MinDist
				{
					MinDist = Dist
					ClosestColor = Color.Value
				}
			}

			WritePixel(Image, X, Y, ClosestColor)
		}
	}
}

HexColorToFloatColor :: proc(HexColor : string) -> v3
{
	Red   := HexColor[1:3]
	Green := HexColor[3:5]
	Blue  := HexColor[5:7]

	R, _ := strconv.parse_int(Red, 16)
	G, _ := strconv.parse_int(Green, 16)
	B, _ := strconv.parse_int(Blue, 16)

	FloatColor := v3 {
		real(R) / real(255),
		real(G) / real(255),
		real(B) / real(255),
	}

	return FloatColor
}

SortPixelLeftToRight :: proc(A, B : v3) -> bool
{
	return Luminance(A) < Luminance(B)
}

SortPixelRightToLeft :: proc(A, B : v3) -> bool
{
	return Luminance(A) > Luminance(B)
}

