package main

// NOTE(matthew): Based on: https://github.com/LiamHz/atlas/blob/master/perlin.h

Fade :: proc(t : real) -> real
{
    return t * t * t * (t * (t * 6 - 15) + 10)
}

Lerp :: proc(t, A, B : real) -> real
{
    return A + t * (B - A)
}

SmoothStep :: proc(x, Edge0, Edge1 : real) -> real
{
    x := Clamp(x, Edge0, Edge1)

    return x * x * (3.0 - 2.0 * x)
}

Grad :: proc(Hash : int, x, y, z : real) -> real
{
    H := Hash & 15
    u, v : real

    if H < 8
    {
        u = x
    }
    else
    {
        u = v
    }

    if H < 4
    {
        v = y
    }
    else
    {
        if H == 12 || H == 14
        {
            v = x
        }
        else
        {
            v = z
        }
    }

   return ((H & 1) == 0 ? u : -u) + ((H & 2) == 0 ? v : -v)
}

PerlinNoise :: proc {
	PerlinNoise_xy,
	PerlinNoise_v2,
}

PerlinNoise_xy :: proc(x, y : real, Perm : []int) -> real
{
    x := x
    y := y
    z : real

    // Find unit cube that contains the point
    X := cast(int)Floor(x) & 255
    Y := cast(int)Floor(y) & 255
    Z := cast(int)Floor(z) & 255

    // Find relative (x,y,z) of point in the cube
    x -= Floor(x)
    y -= Floor(y)
    z -= Floor(z)

    // Compute fade curves for each of (x,y,z)
    u := Fade(x)
    v := Fade(y)
    w := Fade(z)

    // Hash coordinates of the 8 cube corners
    A  := Perm[X  ]   + Y
    AA := Perm[A]     + Z
    AB := Perm[A + 1] + Z
    B  := Perm[X + 1] + Y
    BA := Perm[B]     + Z
    BB := Perm[B + 1] + Z

    // Linearly blend results from the 8 corners
    return Lerp(w, Lerp(v, Lerp(u, Grad(Perm[AA    ], x    , y    , z    ),
                                   Grad(Perm[BA    ], x - 1, y    , z    )),
                           Lerp(u, Grad(Perm[AB    ], x    , y - 1, z    ),
                                   Grad(Perm[BB    ], x - 1, y - 1, z    ))),
                   Lerp(v, Lerp(u, Grad(Perm[AA + 1], x    , y    , z - 1),
                                   Grad(Perm[BA + 1], x - 1, y    , z - 1)),
                           Lerp(u, Grad(Perm[AB + 1], x    , y - 1, z - 1),
                                   Grad(Perm[BB + 1], x - 1, y - 1, z - 1))))
}

PerlinNoise_v2 :: proc(P : v2, Perm : []int) -> real
{
    return PerlinNoise_xy(P.x, P.y, Perm)
}

GeneratePermutationVector :: proc(Series : ^random_series) -> [dynamic]int
{
	Permutation : [dynamic]int
	N := 256

	for I in 0..<N
	{
		append(&Permutation, I)
	}

	Shuffle(Series, Permutation[:])

	for I in 0..<N
	{
		append(&Permutation, Permutation[I])
	}

	return Permutation
}

