package main

import fmt		"core:fmt"
import math		"core:math"
import linalg	"core:math/linalg"

///////////////////////////////////////
// Types
///////////////////////////////////////

REAL_AS_F64 :: #config(REAL_AS_F64, false)

when REAL_AS_F64
{
	real :: f64
}
else
{
	real :: f32
}

v2f	:: [2]real
v2i :: [2]i32
v2u :: [2]u32
v2 	:: v2f

v3f	:: [3]real
v3i :: [3]i32
v3u :: [3]u32
v3 	:: v3f

v4f	:: [4]real
v4i :: [4]i32
v4u :: [4]u32
v4 	:: v4f

m2f :: matrix[2, 2]real
m2  :: m2f

m3f :: matrix[3, 3]real
m3  :: m3f

m4f :: matrix[4, 4]real
m4  :: m4f

///////////////////////////////////////
// Constants
///////////////////////////////////////

when REAL_AS_F64
{
	REAL_MAX	:: math.F64_MAX
	REAL_MIN	:: math.F64_MIN
}
else
{
	REAL_MAX	:: math.F32_MAX
	REAL_MIN	:: math.F32_MIN
}

PI				: real : math.PI
INV_PI			: real : 1.0 / PI
INV_HALFPI		: real : 2.0 / PI
INV_TWOPI		: real : 1.0 / (2 * PI)
INV_FOURPI		: real : 1.0 / (4 * PI)

when REAL_AS_F64
{
	MAT4_IDENTITY	:: linalg.MATRIX4F64_IDENTITY
}
else
{
	MAT4_IDENTITY	:: linalg.MATRIX4F32_IDENTITY
}

///////////////////////////////////////
// Intrinsics
///////////////////////////////////////

Cross 				:: linalg.cross
Dot 				:: linalg.dot
Normalize 			:: linalg.normalize
Length 				:: linalg.length
LengthSquared		:: linalg.length2
SquareRoot 			:: linalg.sqrt
Abs 				:: abs
Min 				:: min
Max 				:: max
Sin					:: math.sin
Cos					:: math.cos
ACos				:: math.acos
ATan2				:: math.atan2
Tan					:: math.tan
Pow					:: math.pow
DegsToRads			:: math.to_radians
RadsToDegs			:: math.to_degrees
Clamp				:: clamp
Floor				:: math.floor
Fract				:: linalg.fract
Inverse				:: linalg.matrix4_inverse
InverseTranspose	:: linalg.matrix4_inverse_transpose
IsNaN				:: linalg.is_nan
IsInf				:: linalg.is_inf

///////////////////////////////////////
// Mat4 functions
///////////////////////////////////////

Mat4Translate :: proc(Vec : v3) -> m4
{
	Mat := MAT4_IDENTITY

	Mat[0, 3] = Vec.x
	Mat[1, 3] = Vec.y
	Mat[2, 3] = Vec.z

	return Mat
}

Mat4Scale :: proc(Scale : f32) -> m4
{
	Mat := MAT4_IDENTITY

	Mat[0, 0] = Scale
	Mat[1, 1] = Scale
	Mat[2, 2] = Scale

	return Mat
}

Mat4Rotate :: proc(Angle : f32, Axis : v3) -> m4
{
	Mat : m4

	C := Cos(DegsToRads(Angle))
	C1 := 1 - C
	S := Sin(DegsToRads(Angle))
	Vec := Normalize(Axis)

	Mat[0, 0] = (C1 * Vec.x * Vec.x) + C;
    Mat[1, 0] = (C1 * Vec.x * Vec.y) + S * Vec.z;
    Mat[2, 0] = (C1 * Vec.x * Vec.z) - S * Vec.y;

    Mat[0, 1] = (C1 * Vec.x * Vec.y) - S * Vec.z;
    Mat[1, 1] = (C1 * Vec.y * Vec.y) + C;
    Mat[2, 1] = (C1 * Vec.y * Vec.z) + S * Vec.x;

    Mat[0, 2] = (C1 * Vec.x * Vec.z) + S * Vec.y;
    Mat[1, 2] = (C1 * Vec.y * Vec.z) - S * Vec.x;
    Mat[2, 2] = (C1 * Vec.z * Vec.z) + C;

    Mat[3, 3] = 1.0

	return Mat
}

Mat4PerspectiveLH :: proc(FOV, AspectRatio, NearPlane, FarPlane : real) -> m4
{
	Mat : m4

	t := Tan(DegsToRads(FOV) * 0.5)
	Range := FarPlane / (FarPlane - NearPlane)

	Mat[0, 0] = 1 / (AspectRatio * t)
	Mat[1, 1] = 1 / t
	Mat[2, 2] = Range
	Mat[3, 2] = 1.0
	Mat[2, 3] = -Range * NearPlane

	return Mat
}

Mat4LookAtLH :: proc(Eye, Center, Up : v3) -> m4
{
	Mat : m4

	f := Normalize(Center - Eye)
	s := Normalize(Cross(Up, f))
	u := Cross(f, s)

	Mat[0, 0] =  s.x
	Mat[1, 0] =  u.x
	Mat[2, 0] =  f.x

	Mat[0, 1] =  s.y
	Mat[1, 1] =  u.y
	Mat[2, 1] =  f.y

	Mat[0, 2] =  s.z
	Mat[1, 2] =  u.z
	Mat[2, 2] =  f.z

	Mat[0, 3] = -Dot(s, Eye)
	Mat[1, 3] = -Dot(u, Eye)
	Mat[2, 3] = -Dot(f, Eye)

	Mat[3, 3] = 1.0

	return Mat
}

