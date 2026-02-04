package main

import win32 "core:sys/windows"

/*
	JSF PRNG (32-bit version), see the following:
	- https://burtleburtle.net/bob/rand/smallprng.html
	- https://www.pcg-random.org/posts/bob-jenkins-small-prng-passes-practrand.html
*/

random_series :: struct
{
	A, B, C, D : u32,
}

InitializeRandomSeries :: proc(Seed : u32) -> random_series
{
	Series : random_series

	Series.A = 0xF1EA5EED
	Series.B = Seed
	Series.C = Seed
	Series.D = Seed

	for I in 0..<20
	{
		RandomU32(&Series)
	}

	return Series
}

GetEntropy :: proc() -> u32
{
	Seed : u32

	win32.BCryptGenRandom(nil, cast(^u8)&Seed, size_of(Seed), win32.BCRYPT_USE_SYSTEM_PREFERRED_RNG)

	return Seed
}

Rotate32 :: proc(V : u32, Shift : u32) -> u32
{
	return (V << Shift) | V >> (32 - Shift)
}

RandomU32 :: proc(Series : ^random_series) -> u32
{
	E := Series.A - Rotate32(Series.B, 27)

    Series.A = Series.B ~ Rotate32(Series.C, 17)
    Series.B = Series.C + Series.D
    Series.C = Series.D + E
    Series.D = E + Series.A

    return Series.D
}

// Generates a 32-bit float in the interval [0,1)
RandomF32 :: proc(Series : ^random_series) -> f32
{
	// Trick from MTGP: generate a uniformly distributed f32 in [1,2) and
	// subtract 1
	U := RandomU32(Series)
	X := (U >> 9) | 0x3F800000
	Bits := transmute(f32)X

	return Bits - 1.0
}

// Generates a 64-bit float in the interval [0,1)
// NOTE(matthew): Since U is 32bits, only the top 32 mantissa bits will be
// filled and the rest will be zero.
RandomF64 :: proc(Series : ^random_series) -> f64
{
	// Same trick as the f32 version
	U := RandomU32(Series)
	X := (u64(U) << 20) | 0x3ff0000000000000
	Bits := transmute(f64)X

	return Bits - 1.0
}

RandomReal :: proc {
	RandomReal01,
	RandomRealRanged,
}

when REAL_AS_F64
{
	RandomReal01 :: RandomF64
}
else
{
	RandomReal01 :: RandomF32
}

RandomRealRanged :: proc(Series : ^random_series, Min, Max : real) -> real
{
	t := RandomReal01(Series)

	return Lerp(Min, Max, t)
}

