# Why Odin???

During my devoir1 presentation, I mentioned that I switched to using Odin from C++ as my main programming language of choice.
Unsurprisingly, I received quite a few questions about why I made this decision, why I prefer Odin, what features does it have that I enjoy, etc.
My answer at the time was "I can't really answer that in 30 seconds, but we can talk about it after", which I'm sure was a bit unsatisfying.

So I figured I'd write a (hopefully short!) document to address some of these points, and in doing so hopefully give a more satisfying answer.
This will by no means be an exhaustive list of _all_ the things I love about the language, and I will probably add more to this as time goes by.
Rather these are some of the things I consider the most important and valuable.

For more details in general about the language, see the overview page: https://odin-lang.org/docs/overview/.

## Type system

See https://odin-lang.org/docs/overview/#numbers and https://odin-lang.org/docs/overview/#type-conversion for more
details.

As some people might know, C++ numeric literals are actually _typed_, eg `1` is of type `int`, `2.0` is of type `double`, and so on.
If you write the following in C++, you will get a warning from the compiler:
```
int X = 1.0;
```
This is because `1.0` is of type `double`, and you are assigning it to an `int`.
In Odin, however, the type system recognizes that `1.0` can be represented by an `int`, and so the following is
perfectly valid with no warnings or errors:
```
X : int = 1.0
```
The following is also valid (the equivalent in C++ can generate warnings about assigning an `int` to a `float`, especially
if templates are involved in more complex examples):
```
Y : f32 = 2
```
Odin also has type inference using the same `:=` syntax as Go:
```
// Returns an int
Foo :: proc() -> int
{
    // ...
}

main :: proc()
{
    X := Foo() // type of X is inferred to be int
}
```





## Multiple return values

Oftentimes you might want a function to return multiple values. In C++ you have two options:
- "out" parameters (eg, pass a pointer or reference to the variable that you want as "output")
- Use `std::tuple`

The former gets the job done, but it isn't actually a return value.
The latter _is_ a return value but it's not very ergonomic.

Imagine a function that returns an `int` and a `double`. In C++ with `std::tuple`, this would look something like:
```
#include <tuple>

std::tuple<int, double> Foo()
{
    int X = -20;
    double Y = 1.5;

    // You can also shorten this using auto instead of specifying the full type, ie:
    // auto Tuple = std::make_tuple(X, Y);
    std::tuple<int, double> Tuple = std::make_tuple(X, Y);

    return Tuple;
}

int main(void)
{
    // Again, you can use auto to shorten this
    std::tuple<int, double> Tuple = Foo();

    int X = std::get<0>(Tuple);     // -20
    double Y = std::get<1>(Tuple);  // 1.5
}
```
This works, but you _must_ use this `std::make_tuple` function to "merge" the variables together, and then use
`std::get` to actually access the variables. Yuck...

By contrast, Odin supports functions returning multiple return values _completely natively_.
It looks something like this:
```
Foo :: proc() -> (int, f64)
{
    return 2, 1
}

main:: proc()
{
    // With explicit types
    A : int
    B : f64

    A, B = Foo()

    // With type inference
    X, Y := Foo()
}
```
Much cleaner and more ergonomic: no `std::make_tuple` or `std::get` nonsense, just return the variables and
use them. This also enables other nice features within the language, which I might present in the future.

You can also use this syntax to "swap" two (or more) variables without using any temp variables:
```
X := 4,
Y := 5

X, Y = Y, X
```






## Slices

See https://odin-lang.org/docs/overview/#slices for more details.

This will be very familiar to Python or Go programmers.
A slice is essentially a "reference" to an existing array (pointer + a length). A slice is formed by specifying two indices
(lower and upper bound, respectively), separated by a colon.
```
array[low : high]
```
This creates a range that includes the low element but excludes the high element:
```
Fibonaccis := [6]int{0, 1, 1, 2, 3, 5}
Slice := Fibonaccis[1:4] // Creates a slice with elements 1, 2, and 3

fmt.println(Slice) // [1, 1, 2]

C++ has no native way of expressing this kind of idea. The only option is to use `std::span`, which is _only_
available starting in C++20 and has a much less elegant syntax compared to that of Odin (in my opinion).
```





## Struct literals

See https://odin-lang.org/docs/overview/#struct-literals for more details.

This is a feature in C99 (called "designated initializers") that I absolutely love, but it's not natively
supported in C++. It was only made available in C++20 and even then it's less expressive than the C99 version.
This is actually one of many reasons that saying "C++ is a superset of C" is false: there are features in C that
are not available in C++.





## Discriminated unions

See https://odin-lang.org/docs/overview/#unions for more details.

We often want some kind of polymorphic behaviour between types/objects in our program. For instance, you might
want to have a classes for different types of shapes (eg. square, circle, triangle, etc), which can then all
be treated as a single generic "shape" type. C++ makes this easy with inheritance and virtual functions:
```
class shape
{
public:
    shape() {}
    virtual float GetArea() = 0;
};

class square : shape
{
public:
    square(float SideInit) : Side(SideInit) {}
    virtual float GetArea() { return Side * Side; }

private:
    float Side;
};

class circle : shape
{
public:
    circle(float RadiusInit) : Radius(RadiusInit) {}
    virtual float GetArea() { return PI * Radius * Radius; }

private:
    float Radius;
}

shape *Shape = ...;
float Area Shape->GetArea();
```
I personally dislike this approach for a number of reasons, the main one being performance. The short version:
virtual functions are often implemented in C++ using vtables, and these lead to significantly slower code because
they neuter the compiler's ability to perform optimizations.

Instead, I prefer using discriminated unions + switch statements with plain functions:
```
struct square
{
    float Side;
};

struct circle
{
    float Radius;
};

enum shape_tag
{
    ShapeTag_SQUARE = 0,
    ShapeTag_CIRCLE = 1,
};

struct shape
{
    shape_tag Tag;

    union
    {
        square Square;
        circle Circle;
    };
};

// You could also make these member functions instead if you were so inclined
float GetArea_square(square Square) { return Square.Side * Square.Side; }
float GetArea_circle(circle Circle) { return PI * Circle.Radius * Circle.Radius; }

float GetArea(shape Shape)
{
    float Result;

    switch (Shape.Tag)
    {
        case ShapeTag_CIRCLE:
        {
            Result = GetArea_circle(Shape.Circle);
        } break;

        case ShapeTag_SQUARE:
        {
            Result = GetArea_square(Shape.Square);
        } break;
    }

    return Result;
}

shape Shape = ...;
float Area = GetArea(Shape);
```
This works, but it has some deficiences:
- You have to remember to assign the tag in the shape's internal constructor (or whatever type of code that is
meant to initialize it).
- If you add a new shape, you have to remember to update the tag enum and add the new cases to all the functions.
In a large code base with lots of function and types, this could be very easy to forget!
- You cannot pass a `square` or `circle` directly to `GetArea`. They have to first be wrapped into a `shape` with
 the tag.

Now, C++17 does address all of these points with the introduction of `std::variant`, so that is what you should be
reaching for by default if you want this kind of behaviour (although it does have its quirks). Odin, also addresses
all of these points as well, and quite elegantly, which I'll demonstrate.

A `union` in Odin is a discriminated union by default, so you just make a list of the types that you want:
```
square :: struct
{
    Side : f32,
}

circle :: struct
{
    Radius : f32,
}

// This implicitly stores a tag variable, akin to the explicit tag that we had in the C++ version
shape :: union
{
    square,
    circle,
}
```
No need to assign a tag explicitly: it will be automatically produced for you by the compiler. So there's point #1.

You then have your subtype functions:
```
GetArea_square :: proc(Square : square) -> f32
{
    return Square.Side * Square.Side
}

GetArea_circle :: proc(Circle : circle) -> f32
{
    return PI * Circle.Radius * Circle.Radius
}
```
Finally, in your handler function, you just do a switch _on the type itself!_
```
GetArea :: proc(Shape : shape) -> f32
{
    Result : f32

    // This will automatically "down-cast" E to the appropriate type
    switch E in Shape
    {
        case square:
        {
            Result = GetArea_square(E)
        }

        case circle:
        {
            Result = GetArea_circle(E)
        }
    }

    return Result
}
```
If you then decide to add a new shape (eg, a triangle), you just add it to your union. Then, if you forget to add
the new case to any of the switch statements, then you'll get a compile error saying that a missing type wasn't
handled. If you forget to do this when using `std::variant`, you get bombared with about 15 compile errors, none
of which directly point to the offending code (at least on MSVC 2022). There's point #2.

Finally, when you go to use these functions, you can either pass a `shape` or one of the internal types:
```
main:: proc()
{
    Square : square = square{2}
    Circle : circle = circle{2.5}
    Shape  : shape  = square{4}

    SquareArea := GetArea(Square)
    CircleArea := GetArea(Circle)
    ShapeArea  := GetArea(Shape)
}
```
As you can see, I'm using struct literals (discussed above) directly. No need for additional "up-casting" to the generic
`shape` type -- they all just work. And there's point #3.





## Support for custom allocators

See https://odin-lang.org/docs/overview/#allocators for more details.

In Odin, allocators are very much a "first-class" concept.
That is to say, Odin has tons of support for custom allocators at the language level itself.
Any code that _could_ perform a memory (heap) allocation will use the default `context` allocator, but you also
have the option to supply your own custom allocator instead. This applies to built-in types like dynamic arrays
or maps (eg, you can tell them to use a specific allocator rather than the `context` one), as well as core library
functions that could internally allocate memory. This makes it incredibly easy to make specific pieces of code
use specific allocators, which allows you to vastly simplify memory management throughout your program.

C++ simply does not have this same kind of mechanism. You can still try to use custom allocators in certain
cases, but nowhere near as pervasively or elegantly as Odin. C++ as a language itself was simply not designed with
this type of behaviour in mind, whereas Odin was.





## Huge set of core libraries

This is probably one of the biggest selling-points of Odin, which is that it has an incredibly vast standard
library that you can use as soon as you install the compiler. As a simple example, Odin has a library called
`core:strings` that provides a whole slew of functions for working with strings, and in particular string parsing.
This is something that I use quite heavily in certain projects when I have to do parsing of mesh files, for example.
Of course, I _could_ write my own string parsing library if I had to, but having one available with the compiler
makes things drastically easier.

Not to mention, of course, that Odin also has bindings for other 3rd party libraries and APIs, such as OpenGL,
Direct3D 11 and 12, Vulkan, GLFW, raylib, and the list goes on and on. Having these bindings available
from day one is a huge relief. No need to dig through GitHub repos for bindings that someone else wrote,
or potentially not find any and having to roll-your-own: they're all just _there_.

I want to emphasize this point because I actually think that it's incredibly important. A large part of what makes
modern languages like Python so powerful is not just the language itself, but also the tooling around these languages.
Python is, of course, a programming language, but people rarely think of it as _just_ a programming language. They
also think of things like `numpy`, `pytorch`, `pandas`, and so on (of course, not to mention that Python also has
a very extensive standard library). And of course the same thing can be said about others like C++, Go, JavaScript, and
so on. That is to say, the _ecosystem_ around a language is just as, if not more, important than the language itself.

I highly recommend watching (at least part of) this video if you have time:
https://youtu.be/eAhWIO1Ra6M?si=2EphuOmPw3A1YZla
which talks about how C is often seen as inferior to modern languages, simply because of its mediocre standard library.

One comment in particular from the creator of the video summarizes the point nicely:
```
So yes, I absolutely agree that there are problems where the much bigger libraries of some classic dynamic languages
allow you to construct a solution in those languages much more quickly than you can solve the same problem in C with
a poorly-fitting library. One of the points of the talk is that the gap between those two can be greatly reduced if
you have a better library in C. Of course, instead of developing a better library for C, you can commit some amount
of time into learning two, three, or more languages and all of their libraries. My point is that everyone ALWAYS talks
about the latter as the only possible approach, and I wanted to point out that the former is a viable approach for
some of us. There are obvious issues with the latter--with using different languages to solve different problems--that
people NEVER mention (because nobody perceives an alternative, so why even talk about it). What if the two other languages
you've learned ALSO don't happen to have low-friction ways of solving the toy example you demonstrate on stream?
Whoops! What if you can only commit the time to deeply learning the standard libraries of one language of the three,
so you're not proficient in the other two to the same level and don't even know what is easy in the language because
you're not an expert? What if the "it's easy in this language because you can download a library that solves it" involves
a library with a poor, difficult-to-learn API? (And this doesn't even touch on the performance issue, which is usually
unimportant for small programs but does come up for me once in a while...).
```







## Array programming

See https://odin-lang.org/docs/overview/#array-programming and https://odin-lang.org/docs/overview/#matrix-type
for more details.

Odin does not have operator overloading like in C++, which is quite important for vector or matrix types that you
might need in graphcis programming. Instead, Odin just supports these constructs natively, such as being able to
add two arrays together directly, or the built-in `matrix` type. The core library also provides many of the
functions you would need when working with vectors (eg, dot product, cross product, norm, etc).





## No header files / other C/C++ artifacts

There is no header/source file split like in C/C++; you just have `.odin` files which contain everything. Furthermore, all
the files in your project are compiled together as a single unit. Meaning if you define a struct or function in one file,
it is automatically visible in all the other files (no need for a #include).

Some other artifacts of the C/C++ compilation model are gone. For example, there are
no function declarations, just function definitions. You also can declare functions, structs, etc. _anywhere_ in
the source code -- the order doesn't matter. That is to say, the following is valid:
```
main :: proc()
{
    Bar := bar{10}

    Foo(Bar)
}

Foo :: proc(Bar : bar)
{
    // Do something
}

bar :: struct
{
    X : int,
}
```
This makes the mental overhead of organizing your code significantly lighter. No more worrying about "Oh shit I forgot to
#include the file that has this function declaration" or "Oops I ordered the #include's wrong, time to reorder them" -- you
just write whatever code you want in whichever files you want and it all works™.





## Type conversions

See https://odin-lang.org/docs/overview/#type-conversion and https://odin-lang.org/docs/overview/#type-conversion
for more details.

Odin is also very strict about type conversions: there are very few implicit type conversions that can occur.
For example, the following will not compile (passing `uint` to function that expects an `int`):
```
Foo :: proc(X : int)
{
    // Do some stuff...
}

main :: proc()
{
    Y : uint = 20

    // Error: Cannot assign value 'Y' of type 'uint' to 'int' in a procedure argument
    Foo(Y)
}

```
Rather, you must explicitly do type casting to convert between types -- the compiler will not do it for you.
```
// Both are valid, equivalent ways to cast
Foo(int(Y))
Foo(cast(int)Y)
```
While this might be irritating at first, it forces you to be more diligent about using the correct, expected types
throughout your code, thus allowing you to minimize bugs caused by implicit conversions.




## `distinct` keyword

See https://odin-lang.org/docs/overview/#distinct-types for more details.

In C++, `typedef` and `using` can be used to create a new name for an existing type. However, these mechanisms only create
_aliases_ for type -- they don't actually give you any type safety, which you might want.

As a concrete example, imagine we were writing a simple OS API where we refer to files using an opaque `uint` handle
(similar to POSIX).
Suppose we create two functions, `OpenFile()` and `ReadFile()`, the former returns a handle to an existing file on disk,
and the latter takes the handle and reads from the file:
```
uint OpenFile(const char *FileName);
void ReadFile(uint FileHandle, void *Ptr, uint NumBytesToRead);
```
Since we're just using a `uint` to refer to file handles, it is technically possible to pass _any_ `uint` value to the
`ReadFile` function. Thus, we would like some type-safety to ensure that only `uint`'s returned by `OpenFile` can be
passed to `ReadFile`. Unfortunately, since `typedef` and `using` only create aliases, simply doing something like
`typedef uint file_handle` won't actually work. That is to say, the following will compile without any complaints:
```
uint X = 0;
ReadFile(X, ...);
```
Instead we have to use the following "trick" where we wrap the handle in a struct:
```
struct file_handle
{
    // This is whatever the actual file handle value would be
    uint Internal;
};

file_handle OpenFile(const char *FileName);
void ReadFile(file_handle FileHandle, void *Ptr, uint NumBytesToRead);
```
This works and is a very common pattern, but it really is just a hack around C++'s type system.

Odin, on the other hand, solves this problem trivially with its `distinct` keyword, which actually creates a strong typedef:
```
file_handle :: distinct uint

OpenFile :: proc(FileName : string) -> file_handle
{
}

ReadFile :: proc(FileHandle : file_handle, Ptr : rawptr, NumBytesToRead : uint)
{
}
```
And then:
```
X : file_handle = OpenFile(...)
ReadFile(X, ...) // Compiles

Y : uint = 0
ReadFile(Y, ...) // Error: Cannot assign value 'Y' of type 'uint' to 'file_handle' in a procedure argument
```




## `or_return` operator

See https://odin-lang.org/docs/overview/#or_return-operator for more details.

I won't explain this directly, rather I'd just recommend reading the above reference (it explains the concept
very throughly). The idea is that it allows you to more cleanly handle the following:
```
// A common idiom in many codebases
Value, Error := Foo()
if Error != nil
{
    return
}

// Continue with stuff
```
This makes it very easy to propogate error values throughout a call-stack without needing hundreds of explicit
`if` checks or early return statements. 

