@echo off

if not exist build (
	mkdir build
)

odin build source -out:build\main.exe -o:speed

