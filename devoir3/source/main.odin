package main

import os      	"core:os"
import log      "core:log"
import strings  "core:strings"
import strconv	"core:strconv"
import slice	"core:slice"
import fmt		"core:fmt"

import rl		"vendor:raylib"

xkcd_color :: struct
{
	Name : string,
	Value : v3,
}

main :: proc()
{
	if len(os.args) < 2
	{
		fmt.println("Need an image filename...!")
		return
	}

	ImageFileName := os.args[1]

	Series := InitializeRandomSeries(0)
	Colors := LoadColorData()

	ColorPalette : [dynamic]xkcd_color
	Indices : [dynamic]u32

	// Build 16-color palette
	for len(Indices) < 16
	{
		Index := RandomUInt(&Series, u32(len(Colors)))

		if !slice.contains(Indices[:], Index)
		{
			append(&Indices, Index)
			append(&ColorPalette, Colors[Index])
		}
	}

	for Color in ColorPalette
	{
		fmt.println(Color)
	}

	Image, _ := LoadImage(ImageFileName, false)

	PostprocessImage(Image, ColorPalette[:])

	SaveImage(Image, "blah.png")
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

