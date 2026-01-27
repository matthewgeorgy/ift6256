package main

// JSF PRNG (64-bit)
// https://burtleburtle.net/bob/rand/smallprng.html
// https://www.pcg-random.org/posts/bob-jenkins-small-prng-passes-practrand.html

import win32 "core:sys/windows"

random_series :: struct
{
	A, B, C, D : u64,
}

GetEntropy :: proc() -> u64
{
	Seed : u64

	win32.BCryptGenRandom(nil, cast(^u8)&Seed, 8, win32.BCRYPT_USE_SYSTEM_PREFERRED_RNG)

	return Seed
}

InitializeRandomSeries :: proc(Seed : u64) -> random_series
{
	Series : random_series

	Series.A = 0xF1EA5EED
	Series.B = Seed
	Series.C = Seed
	Series.D = Seed

	for I in 0..<20
	{
		RandomU64(&Series)
	}

	return Series
}

Rotate64 :: proc(V : u64, Shift : u64) -> u64
{
	return (V << Shift) | V >> (64 - Shift)
}

RandomU64 :: proc(Series : ^random_series) -> u64
{
	E := Series.A - Rotate64(Series.B, 7)

	Series.A = Series.B ~ Rotate64(Series.C, 13)
	Series.B = Series.C + Rotate64(Series.D, 37)
	Series.C = Series.D + E
	Series.D = E + Series.A

	return Series.D
}

RandomUInt :: proc(Series : ^random_series, N : u64) -> u64
{
	Threshold := max(u64) - (max(u64) % N)
	R := max(u64)

	for R >= Threshold
	{
		R = RandomU64(Series)
	}

	return R % N
}

Shuffle :: proc(Series : ^random_series, A : []$T)
{
	N := u64(len(A))

	for I := N - 1; I > 0; I -= 1
	{
		J := RandomUInt(Series, I)

		A[I], A[J] = A[J], A[I]
	}
}

RandomReal :: proc {
	RandomReal01,
	RandomRealRanged,
}

RandomReal01 :: proc(Series : ^random_series) -> real
{
	RandomValue := RandomU64(Series)
	Result := real(RandomValue) / real(max(u64))

	return Result
}

RandomRealRanged :: proc(Series : ^random_series, Min, Max : real) -> real
{
	t := RandomReal01(Series)

	return Lerp(Min, Max, t)
}

