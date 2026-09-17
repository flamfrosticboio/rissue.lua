#!/bin/sh

# Run this on the project root directory
export LUA_PATH="./?.lua;./?/init.lua;./test/?.lua;./test/?/init.lua;$LUA_PATH"
lua5.1 test/api/setup.lua
