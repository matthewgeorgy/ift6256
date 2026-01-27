package main

RockHeight :: proc(P : v2, Perm : []int) -> real
{
	LAYER_HEIGHT_MIN 		: real = 0.4	// 0.4
	LAYER_HEIGHT_MAX 		: real = 0.6	// 0.6
	TILT_SCALE 				: real = 0.0	// 0.1
	DETAIL_AMP_MIN 			: real = 0.2	// 0.2
	DETAIL_AMP_MAX 			: real = 0.6	// 0.6
	EROSION_THRESHOLD		: real = 0.05	// 0.65
	EROSION_SCALE 			: real = 0.9	// 0.3


    // Spatially varying layer thickness
	LayerHeight := Lerp(PerlinNoise(0.05 * P, Perm) * 0.5 + 0.5, LAYER_HEIGHT_MIN, LAYER_HEIGHT_MAX)

	// Tilt
    Tilt := (PerlinNoise(0.03 * P, Perm) - 0.5) * TILT_SCALE

	// // Layering
    y := (P.y + P.x * Tilt) / LayerHeight
    Layer := Floor(y)

    Height := Layer * LayerHeight

    // // Local erosion
    if PerlinNoise(Layer, 1.1, Perm) > EROSION_THRESHOLD
	{
        Height -= LayerHeight * EROSION_SCALE
	}

    // // Spatially varying surface damage
	DetailAmp := Lerp(PerlinNoise(0.08 * P, Perm) * 0.5 + 0.5, DETAIL_AMP_MIN, DETAIL_AMP_MAX)

    Height += PerlinNoise(1.5 * P, Perm) * DetailAmp

    return Height
}

Nx : u32 = 50
Ny : u32 = 50
X_SIZE : real = 10.0
Y_SIZE : real = 5.0

GenerateRockMesh :: proc(Seed : u64) -> ([dynamic]vertex, [dynamic]u32)
{
	Vertices : [dynamic]vertex
	Indices : [dynamic]u32

	Series := InitializeRandomSeries(Seed)

	Perm := GeneratePermutationVector(&Series)

	dX := X_SIZE / real(Nx - 1)
	dY := Y_SIZE / real(Ny - 1)

	// Positions
	for Y in 0..<Ny
	{
		for X in 0..<Nx
		{
			XCoord := real(X) * dX
			YCoord := real(Y) * dY

			Height := RockHeight(v2{XCoord, YCoord}, Perm[:])

			Vertex := vertex {
				Position = v3{XCoord, Height, YCoord},
				Normal = v3{0, 0, 0},
				TexCoord = v2{XCoord, YCoord},
			}

			append(&Vertices, Vertex)
		}
	}

	// Indices
	for Y in 0..<Ny - 1
	{
		for X in 0..<Nx - 1
		{
			BaseIndex := X + Y * Nx

			// First triangle
			append(&Indices, BaseIndex + 1)
			append(&Indices, BaseIndex)
			append(&Indices, BaseIndex + Nx)

			// Second triangle
			append(&Indices, BaseIndex + 1)
			append(&Indices, BaseIndex + Nx)
			append(&Indices, BaseIndex + Nx + 1)
		}
	}

	// Normals
	FaceNormals : [dynamic]v3

	for I := 0; I < len(Indices); I += 3
	{
		P0 := Vertices[Indices[I + 0]].Position
		P1 := Vertices[Indices[I + 1]].Position
		P2 := Vertices[Indices[I + 2]].Position

		Edge1 := P1 - P0
		Edge2 := P2 - P0

		Normal := Normalize(Cross(Edge1, Edge2))

		append(&FaceNormals, Normal)
	}

	CREASE_ANGLE_DEG : real = 85.0
	COS_C := Cos(DegsToRads(CREASE_ANGLE_DEG))

	HasRef := make([]bool, len(Vertices))
	RefNormals := make([]v3, len(Vertices))

	for &R in HasRef
	{
		R = false
	}

	for FaceNormal, F in FaceNormals
	{
		for K in 0..<3
		{
			VertexIndex := Indices[F * 3 + K]

			if !HasRef[VertexIndex]
			{
				RefNormals[VertexIndex] = FaceNormal
				HasRef[VertexIndex] = true
				Vertices[VertexIndex].Normal = FaceNormal
			}
			else if Dot(RefNormals[VertexIndex], FaceNormal) > COS_C
			{
				Vertices[VertexIndex].Normal += FaceNormal
			}
		}
	}

	for &V in Vertices
	{
		V.Normal = Normalize(V.Normal)
	}

	return Vertices, Indices
}

