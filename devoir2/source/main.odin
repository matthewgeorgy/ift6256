package main

import slice    "core:slice"
import flags    "core:flags"
import os       "core:os"
import fmt      "core:fmt"
import time     "core:time"
import rl       "vendor:raylib"

SCR_WIDTH           :: 900
SCR_HEIGHT          :: 900
X_MARGIN_PERCENT    :: 0.1
Y_MARGIN_PERCENT    :: 0.1
X_MARGIN            :: SCR_WIDTH * X_MARGIN_PERCENT
Y_MARGIN            :: SCR_HEIGHT * Y_MARGIN_PERCENT
CANVAS_WIDTH        :: SCR_WIDTH - 2 * X_MARGIN
CANVAS_HEIGHT       :: SCR_HEIGHT - 2 * Y_MARGIN
NUM_POINTS          :: 1000

opts :: struct
{
    seed : uint `usage:"Initial seed [default: 0, random seed each time]"`,
    n : uint `usage:"Number of points to generate [default: 1000]"`,
}

main :: proc()
{
    ///////////////////////////////////////////////////////////////////////////
    // Opts

    Opts : opts

    flags.parse_or_exit(&Opts, os.args, .Odin)

    Seed := (Opts.seed != 0) ? u32(Opts.seed) : u32(GetEntropy())
    NumPoints := (Opts.n != 0) ? Opts.n : NUM_POINTS

    fmt.println("Seed:", Seed)
    fmt.println("NumPoints:", NumPoints)

    ///////////////////////////////////////////////////////////////////////////
    // Build points and tree

    Tree : kd_tree
    Series := InitializeRandomSeries(Seed)

    for I in 0..<NumPoints
    {
        X := RandomReal(&Series, 0.01, 0.99)
        Y := RandomReal(&Series, 0.01, 0.99)
        append(&Tree.Points, v2{X, Y})
    }

    BuildTree(&Tree)

    ///////////////////////////////////////////////////////////////////////////
    // Render

    SleepDuration : time.Duration = 1e8

    rl.SetTraceLogLevel(.NONE)
    rl.InitWindow(SCR_WIDTH, SCR_HEIGHT, "kd")
    rl.SetTargetFPS(60)

    MaxDepth : int = 1

	ShowPoints : bool = false

    for !rl.WindowShouldClose()
    {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        DrawBorder()

		if rl.IsKeyPressed(.P)
		{
			ShowPoints = !ShowPoints
		}

		if ShowPoints
		{
        	DrawPoints(Tree.Points[:])
		}

        DrawHyperplanes(Tree, 0, 0, MaxDepth, v2{0, 0}, v2{1, 1})

        // if rl.IsKeyPressed(.SPACE)
        // {
            MaxDepth = (MaxDepth + 1) % (Tree.MaxDepth + 1)
        // }
        time.sleep(SleepDuration)

        rl.EndDrawing()
    }

    rl.CloseWindow()
}

//////////////////////////////////////
// Graphics
//////////////////////////////////////

CoordToPixel :: proc(Coord : v2) -> v2
{
    Pixel := v2 {
        Coord.x * CANVAS_WIDTH + X_MARGIN,
        (1 - Coord.y) * CANVAS_HEIGHT + Y_MARGIN,
    }

    return Pixel
}

DrawBorder :: proc()
{
    TopLeft := v2{X_MARGIN, Y_MARGIN}
    LineWidth : f32 = 5
    LineColor := rl.WHITE

    // Top
    rl.DrawLineEx(TopLeft, TopLeft + v2{CANVAS_WIDTH, 0}, LineWidth, LineColor)

    // Bottom
    rl.DrawLineEx(TopLeft + v2{0, CANVAS_HEIGHT}, TopLeft + v2{CANVAS_WIDTH, CANVAS_HEIGHT}, LineWidth, LineColor)

    // Left
    rl.DrawLineEx(TopLeft, TopLeft + v2{0, CANVAS_HEIGHT}, LineWidth, LineColor)

    // Right
    rl.DrawLineEx(TopLeft + v2{CANVAS_WIDTH, 0}, TopLeft + v2{CANVAS_WIDTH, CANVAS_HEIGHT}, LineWidth, LineColor)
}

DrawPoints :: proc(Points : []v2)
{
    for Point in Points
    {
        Center := CoordToPixel(Point)
        rl.DrawCircle(i32(Center.x), i32(Center.y), 5.0, rl.YELLOW)
    }
}

HYPERPLANE_COLORS := [?] rl.Color{
    rl.PINK,
    rl.GREEN,
    rl.RED,
    rl.DARKGRAY,
    rl.ORANGE,
    rl.SKYBLUE,
    rl.LIME,
    rl.MAROON,
    rl.LIGHTGRAY,
    rl.PURPLE,
    rl.BEIGE,
    rl.BLUE,
    rl.BROWN,
    rl.VIOLET,
    rl.GOLD,
    rl.MAGENTA,
    rl.GRAY,
}

DrawHyperplanes :: proc(Tree : kd_tree, NodeIndex : int, Depth, MaxDepth : int, MinCoord, MaxCoord : v2)
{
    if Depth >= MaxDepth
    {
        return
    }

    if (NodeIndex == -1) || (NodeIndex >= len(Tree.Nodes))
    {
        return
    }

    Node := Tree.Nodes[NodeIndex]
    Axis := Node.Axis
    SplitPos := Node.SplitPos

    Color := HYPERPLANE_COLORS[Depth % len(HYPERPLANE_COLORS)]

    Start := MinCoord
    End := MaxCoord
    Start[Axis] = SplitPos
    End[Axis] = SplitPos

    StartPixel := CoordToPixel(Start)
    EndPixel := CoordToPixel(End)

    rl.DrawLineEx(StartPixel, EndPixel, 2.0, Color)

    // Recurse down left children
    {
        NewMax := MaxCoord
        NewMax[Axis] = SplitPos

        DrawHyperplanes(Tree, Node.LeftChildIndex, Depth + 1, MaxDepth, MinCoord, NewMax)
    }

    // Recurse down right children
    {
        NewMin := MinCoord
        NewMin[Axis] = SplitPos

        DrawHyperplanes(Tree, Node.RightChildIndex, Depth + 1, MaxDepth, NewMin, MaxCoord)
    }
}

//////////////////////////////////////
// KD-tree
//////////////////////////////////////

kd_node :: struct
{
    Axis : int, // 0=x, 1=y
    SplitPos : real,
    Index : int,
    LeftChildIndex, RightChildIndex : int
}

kd_tree :: struct
{
    Nodes : [dynamic]kd_node,
    Points : [dynamic]v2,
    MaxDepth : int,
}

BuildTree :: proc(Tree : ^kd_tree)
{
    Indices := make([]int, len(Tree.Points))

    for I in 0..<len(Indices)
    {
        Indices[I] = I
    }

    // Need this when looking up points in the sort routines
    context.user_ptr = Tree

    BuildNode(Tree, Indices[:], 0, 1)
}

BuildNode :: proc(Tree : ^kd_tree, Indices : []int, Axis : int, Depth : int)
{
    if len(Indices) == 0
    {
        return
    }

    slice.sort_by(Indices, SortByAxis[Axis])

    Mid := (len(Indices) - 1) / 2

    // Remember parent index before we recurse down
    ParentIndex := len(Tree.Nodes)

    Node := kd_node {
        Axis = Axis,
        Index = Indices[Mid],
        SplitPos = Tree.Points[Indices[Mid]][Axis],
    }

    append(&Tree.Nodes, Node)

    Tree.MaxDepth = Depth
    NewAxis := (Axis + 1) % 2

    // Left children
    LeftChildIndex := len(Tree.Nodes)
    BuildNode(Tree, Indices[0:Mid], NewAxis, Depth + 1)

    if LeftChildIndex == len(Tree.Nodes)
    {
        Tree.Nodes[ParentIndex].LeftChildIndex = -1
    }
    else
    {
        Tree.Nodes[ParentIndex].LeftChildIndex = LeftChildIndex
    }

    // Right children
    RightChildIndex := len(Tree.Nodes)
    BuildNode(Tree, Indices[Mid + 1 :], NewAxis, Depth + 1)

    if RightChildIndex == len(Tree.Nodes)
    {
        Tree.Nodes[ParentIndex].RightChildIndex = -1
    }
    else
    {
        Tree.Nodes[ParentIndex].RightChildIndex = RightChildIndex
    }
}

//////////////////////////////////////
// Spatial sorts
//////////////////////////////////////

SortByX :: proc(Index1, Index2 : int) -> bool
{
    Ptr := context.user_ptr
    Tree := (cast(^kd_tree)Ptr)^

    return Tree.Points[Index1].x < Tree.Points[Index2].x
}

SortByY :: proc(Index1, Index2 : int) -> bool
{
    Ptr := context.user_ptr
    Tree := (cast(^kd_tree)Ptr)^

    return Tree.Points[Index1].y < Tree.Points[Index2].y
}

SortByAxis : []proc(int, int)->bool = { SortByX, SortByY, }

