#!/bin/sh

# Run this on the project root directory
export LUA_PATH="./lua/?.lua;./lua/?/init.lua;./test/?.lua;./test/?/init.lua;;"
lua5.1 setup.lua
