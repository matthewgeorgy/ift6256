package main

import stbi 	"vendor:stb/image"
import strings	"core:strings"
import log		"core:log"

image :: struct
{
	Width : u32,
	Height : u32,
	Pixels : []v3,
}

CreateImage :: proc(Width, Height : u32) -> image
{
	Image : image

	Image.Width = Width
	Image.Height = Height
	Image.Pixels = make([]v3, Width * Height)

	return Image
}

ReadPixel :: proc(Image : image, X, Y : u32) -> v3
{
	return Image.Pixels[X + Y * Image.Width]
}

WritePixel :: proc(Image : image, X, Y : u32, PixelColor : v3)
{
	Image.Pixels[X + Y * Image.Width] = PixelColor
}

LinearTosRGB :: proc (LinearRGB : v3) -> v3
{
	sRGB : v3

	// Apply the linear-to-sRGB mapping to each channel
	for Comp in 0..<3
	{
		R := Clamp(LinearRGB[Comp], 0, 1)

		if R > 0.0031308
		{
			sRGB[Comp] = 1.055 * Pow(R, 1.0 / 2.4) - 0.055
		}
		else
		{
			sRGB[Comp] = 12.92 * R
		}
	}

	return sRGB
}

sRGBToLinear :: proc(sRGB : v3) -> v3
{
	Linear : v3

	for I in 0..<3
	{
		Value := sRGB[I]

		if Value <= real(0.04045)
		{
			Linear[I] = Value * (1.0 / 12.92)
		}
		else
		{
			Linear[I] = Pow((Value + 0.055) / 1.055, 2.4)
		}
	}

	return Linear
}

LoadImage :: proc(FileName : string, Gamma : bool) -> (image, bool)
{
	Image : image
	cFileName := strings.clone_to_cstring(FileName)

	// NOTE(matthew): stb_image uses gamma=2.2 instead of exact linear-to-srgb
	// conversion
	// We override this and do our own sRGB conversion instead at the end
	stbi.ldr_to_hdr_scale(1)
	stbi.ldr_to_hdr_gamma(1)

	Width, Height, NumChannels : i32
	FloatData := stbi.loadf(cFileName, &Width, &Height, &NumChannels, 3)
	IsHDR := (stbi.is_hdr(cFileName) != 0) || !Gamma

	if FloatData != nil
	{
		Image = CreateImage(u32(Width), u32(Height))

		for Y in 0..<Image.Height
		{
			for X in 0..<Image.Width
			{
				Index := X + Y * Image.Width

				Color := v3 {
					real(FloatData[3 * Index + 0]),
					real(FloatData[3 * Index + 1]),
					real(FloatData[3 * Index + 2]),
				}

				if !IsHDR
				{
					Color = sRGBToLinear(Color)
				}

				WritePixel(Image, X, Y, Color)
			}
		}

		stbi.image_free(FloatData)
		return Image, true
	}
	else
	{
		log.error("Failed to load image:", FileName)
		return Image, false
	}
}

SaveImage :: proc(Image : image, FileName : string, Gamma : bool = true)
{
	Split := strings.split(FileName, ".")
	Extension := Split[len(Split) - 1]

	cFileName := strings.clone_to_cstring(FileName)
	Width := cast(i32)Image.Width
	Height := cast(i32)Image.Height
	NumComponents : i32 = 3

	if Extension == "hdr"
	{
		// Pixel data for .hdr files must be 32bit floats
		when REAL_AS_F64
		{
			PixelsF32 := make([]f32, 3 * Width * Height)

			for Y in 0..<Height
			{
				for X in 0..<Width
				{
					Index := X + Y * Width
					Color := Image.Pixels[Index]

					PixelsF32[3 * Index + 0] = cast(f32)Color.r
					PixelsF32[3 * Index + 1] = cast(f32)Color.g
					PixelsF32[3 * Index + 2] = cast(f32)Color.b
				}
			}

			stbi.write_hdr(cFileName, Width, Height, NumComponents, raw_data(PixelsF32))
		}
		else
		{
			stbi.write_hdr(cFileName, Width, Height, NumComponents, raw_data(&Image.Pixels[0]))
		}
	}
	else
	{
		// Convert floating-point pixel data to 8-bits per channel
		ByteData := make([]u8, Width * Height * 3)

		for Y in 0..<Height
		{
			for X in 0..<Width
			{
				Index := X + Y * Width

				Color := Image.Pixels[Index]

				if Gamma
				{
					Color = LinearTosRGB(Color)
				}

				Red   := u8(real(255) * Clamp(Color.r, 0, 1))
				Green := u8(real(255) * Clamp(Color.g, 0, 1))
				Blue  := u8(real(255) * Clamp(Color.b, 0, 1))

				ByteData[3 * Index + 0] = Red
				ByteData[3 * Index + 1] = Green
				ByteData[3 * Index + 2] = Blue
			}
		}

		if Extension == "png"
		{
			stbi.write_png(cFileName, Width, Height, NumComponents, &ByteData[0], Width * 3)
		}
		else if Extension == "jpg" || Extension == "jpeg"
		{
			stbi.write_jpg(cFileName, Width, Height, NumComponents, &ByteData[0], 100)
		}
		else if Extension == "bmp"
		{
			stbi.write_bmp(cFileName, Width, Height, NumComponents, &ByteData[0])
		}
		else
		{
			log.warn("Unrecognized file extension:", Extension, "; saving as PNG instead")

			cFileName = strings.clone_to_cstring(strings.concatenate([]string{Split[0], ".png"}))
			stbi.write_png(cFileName, Width, Height, NumComponents, &ByteData[0], Width * 3)
		}
	}
}

