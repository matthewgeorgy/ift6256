
package main

import os 		"core:os"
import fmt 		"core:fmt"
import slice 	"core:slice"
import strings 	"core:strings"
import strconv 	"core:strconv"
import flags	"core:flags"

import rl 		"vendor:raylib"

opts :: struct
{
    seed : u32 `usage:"Initial seed [default: 0, random seed each time]"`,
    input : string `args:"required" usage:"Input image filename"`,
    output : string `usage:"Output image filename [default: out.png]"`,
	palette : uint `usage:"Color palette size [default: 0 - original image colours]"`,
	threshold : real `usage:"Minimum pixel-sorting threshold [default: 0.0]"`,
	step : real`usage:"Threshold decrement size [default: 0.05]"`,
}

main :: proc()
{
	//////////////////////////////////////////////////////////////////////////
	// Opts

	Opts : opts

	flags.parse_or_exit(&Opts, os.args, .Odin)

	Seed : u32 = (Opts.seed != 0) ? Opts.seed : GetEntropy()
	InputFileName := Opts.input
	OutputFileName := (len(Opts.output) != 0) ? Opts.output : "out.png"
	PaletteSize := Opts.palette
	MinThreshold := Opts.threshold
	ThresholdStep : real = (Opts.step != 0) ? Opts.step : 0.05

	Series := InitializeRandomSeries(Seed)

	//////////////////////////////////////////////////////////////////////////
	// Image & colors

	Image, ok := LoadImage(InputFileName, false)
	if !ok
	{
		fmt.println("Failed to open image file:", InputFileName)
		return
	}

	SCREEN_WIDTH := Min(Image.Width, 960)
	SCREEN_HEIGHT := Min(Image.Height, 960)

	if PaletteSize != 0
	{
		XkcdColors := LoadColors()
		Palette := ChoosePalette(&Series, XkcdColors[:], PaletteSize)

		for Color in Palette
		{
			fmt.println(Color.Name, Color.Value)
		}

		PreprocessImage(Image, Palette[:])
	}

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

		if Threshold > MinThreshold
		{
			SortPixels(Image, Sorted, Threshold, SortPixelLeftToRight)
			Threshold -= ThresholdStep
		}

        rl.EndDrawing()

		rl.UnloadTexture(rlTexture)
    }

	SaveImage(Sorted, OutputFileName, false)

    rl.CloseWindow()
}

SortPixels :: proc(Image, Sorted : image, Threshold : real, SortProc : proc(v3, v3) -> bool)
{
	copy(Sorted.Pixels, Image.Pixels)

	for Y in 0..<Sorted.Height
	{
		Row := Sorted.Pixels[Y * Sorted.Width : (Y + 1) * Sorted.Width]

		X := 0

		for X < len(Row)
		{
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

ChoosePalette :: proc(Series : ^random_series, Colors : []xkcd_color, PaletteSize : uint) -> [dynamic]xkcd_color
{
	Indices : [dynamic]u32
	Palette : [dynamic]xkcd_color

	PaletteSize := PaletteSize
	if PaletteSize > len(Colors)
	{
		fmt.printf("Palette size (%u) exceeds total number of colours (%d), clamping...\n", PaletteSize, len(Colors))
		PaletteSize = len(Colors)
	}

	for len(Indices) < int(PaletteSize)
	{
		Index := RandomUInt(Series, u32(len(Colors)))
		if !(slice.contains(Indices[:], Index))
		{
			append(&Indices, Index)
			append(&Palette, Colors[Index])
		}
	}

	delete(Indices)

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

