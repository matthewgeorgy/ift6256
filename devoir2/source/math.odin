package main

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
Lerp				:: math.lerp
Inverse				:: linalg.matrix4_inverse
InverseTranspose	:: linalg.matrix4_inverse_transpose
IsNaN				:: linalg.is_nan
IsInf				:: linalg.is_inf
Mod					:: math.mod

MinV3 :: proc(A, B : v3) -> v3
{
	return v3{Min(A.x, B.x), Min(A.y, B.y), Min(A.z, B.z)}
}

MaxV3 :: proc(A, B : v3) -> v3
{
	return v3{Max(A.x, B.x), Max(A.y, B.y), Max(A.z, B.z)}
}

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

Mat4Scale :: proc {
	Mat4ScaleByScalar,
	Mat4ScaleByVector,
}

Mat4ScaleByScalar :: proc(Scale : real) -> m4
{
	Mat := MAT4_IDENTITY

	Mat[0, 0] = Scale
	Mat[1, 1] = Scale
	Mat[2, 2] = Scale

	return Mat
}

Mat4ScaleByVector :: proc(Scale : v3) -> m4
{
	Mat := MAT4_IDENTITY

	Mat[0, 0] = Scale.x
	Mat[1, 1] = Scale.y
	Mat[2, 2] = Scale.z

	return Mat
}

Mat4Rotate :: proc {
	Mat4RotateFromEulerAngles,
	Mat4RotateFromAngleAxis,
}

when REAL_AS_F64
{
	Mat4RotateFromEulerAngles :: linalg.matrix4_from_euler_angles_yxz_f64
}
else
{
	Mat4RotateFromEulerAngles :: linalg.matrix4_from_euler_angles_yxz_f32
}

Mat4RotateFromAngleAxis :: proc(Angle : real, Axis : v3) -> m4
{
	Mat := MAT4_IDENTITY

	C := Cos(DegsToRads(Angle))
	S := Sin(DegsToRads(Angle))
	C1 := 1 - C
	Vec := Normalize(Axis)

	Mat[0, 0] = (C1 * Vec.x * Vec.x) + C
	Mat[1, 0] = (C1 * Vec.x * Vec.y) + S * Vec.z
	Mat[2, 0] = (C1 * Vec.x * Vec.z) - S * Vec.y

	Mat[0, 1] = (C1 * Vec.x * Vec.y) - S * Vec.z
	Mat[1, 1] = (C1 * Vec.y * Vec.y) + C
	Mat[2, 1] = (C1 * Vec.y * Vec.z) + S * Vec.x

	Mat[0, 2] = (C1 * Vec.x * Vec.z) + S * Vec.y
	Mat[1, 2] = (C1 * Vec.y * Vec.z) - S * Vec.x
	Mat[2, 2] = (C1 * Vec.z * Vec.z) + C

	Mat[3, 3] = 1.0

	return Mat
}

Mat4LookAt :: proc(From, To, Up : v3) -> m4
{
	Mat : m4

	f := Normalize(From - To)
	s := Normalize(Cross(Up, f))
	u := Cross(f, s)

	Mat[0, 0] =  s.x
	Mat[0, 1] =  u.x
	Mat[0, 2] =  f.x

	Mat[1, 0] =  s.y
	Mat[1, 1] =  u.y
	Mat[1, 2] =  f.y

	Mat[2, 0] =  s.z
	Mat[2, 1] =  u.z
	Mat[2, 2] =  f.z

	Mat[0, 3] = From.x
	Mat[1, 3] = From.y 
	Mat[2, 3] = From.z

	Mat[3, 3] = 1.0

	return Mat
}

