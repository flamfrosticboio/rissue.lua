-- RIssue - Abstract implementation for getting issues and merge requests from git providers
-- Copyright (C) 2026  flamfrosticboio
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

---@meta

---@param name string
---@param fn   fun()
function describe(name, fn) end

---@param name string
---@param fn   fun()
function it(name, fn) end

---@param fn fun()
function before_each(fn) end

---@param fn fun()
function after_each(fn) end

---@param fn fun()
function setup(fn) end

---@param fn fun()
function teardown(fn) end

---@param name string
function pending(name) end

---@class Assert
---@field is_true    fun(value: any)
---@field is_false   fun(value: any)
---@field is_nil     fun(value: any)
---@field is_not_nil fun(value: any)
---@field are        Assert
---@field are_not    Assert
---@field is_not     Assert
---@field equal      fun(expected: any, actual: any)
---@field same       fun(expected: table, actual: table)
---@field not_equal  fun(expected: any, actual: any)
---@field not_same   fun(expected: table, actual: table)
---@field truthy     fun(value: any)
---@field falsy      fun(value: any)
---@overload fun(value: any, message?: string): any
assert = {}
