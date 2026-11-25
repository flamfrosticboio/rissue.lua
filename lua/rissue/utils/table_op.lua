-- RIssue - Plugin for getting issues and merge requests from git providers
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

---@diagnostic disable: undefined-global

---@class rissue.mod.TableOperations
local M = {}

---@param t any
---@return boolean is_list
function M.is_list(t)
  if type(t) ~= "table" then
    return false
  end
  ---@cast t table<any, any>
  local i = 0
  for k in pairs(t) do
    i = i + 1
    if k ~= i then
      return false
    end
  end
  return true
end

--- Merges two tables based on keys. Cases with lists are not supported and may get overwritten
---@param dest table<any, any>
---@param source table<any, any>
function M.shallow_key_merge_overwrite(dest, source)
  for key, value in pairs(source) do
    dest[key] = value
  end
end

--- Creates a copy of a table with deeply merged items.
---
--- Similar rules to `vim.tbl_extend()` where:
--- - If the right table is a pure list (with `table_op.is_list()`), then overwrite it.
--- - Merge recursively on each table.
---@param ... table<any, any>
---@return table<any, any>
function M.force_deep_extend(...)
  local tables = { ... }
  local result = {}

  ---@param dst table<any, any>
  ---@param src table<any, any>
  local function merge(dst, src)
    for k, v in pairs(src) do
      if
        type(v) == "table"
        and type(dst[k]) == "table"
        and not M.is_list(v)
      then
        merge(dst[k], v)
      else
        if type(v) == "table" then
          if M.is_list(v) then
            ---@cast v any[]
            local copy = {} ---@type table<any, any>
            for i, item in ipairs(v) do
              copy[i] = (type(item) == "table") and M.force_deep_extend(item)
                or item
            end
            dst[k] = copy
          else
            local copy = {}
            merge(copy, v)
            dst[k] = copy
          end
        else
          dst[k] = v
        end
      end
    end
  end

  for _, t in ipairs(tables) do
    merge(result, t)
  end

  return result
end

--- Returns the number of items of the table
---@param tbl table<any, any>
---@return integer
function M.count(tbl)
  local n = 0
  for _ in pairs(tbl) do
    n = n + 1
  end
  return n
end

---@generic T, M
---@param list T[]
---@param func fun(v: T): M
---@return M[]
function M.map_list(list, func)
  local result = {} ---@type any[]
  for i = 1, #list do
    result[i] = func(list[i])
  end
  return result
end

--- Returns if all booleans are true
---@param bool_table boolean[]
---@return boolean
function M.all(bool_table)
  for _, item in pairs(bool_table) do
    if item == false then
      return false
    end
  end
  return true
end

--- Finds the item in the list.
--- Supports accessing values with 'fun(v: any): boolean'
---@param list any[]
---@param value_to_find any
---@overload fun(list: any[], value_to_find: fun(v: any): boolean): any|nil, integer
---@return any|nil, integer
function M.find(list, value_to_find)
  if type(value_to_find) ~= "function" then
    local orig = value_to_find
    value_to_find = function(v)
      return v == orig
    end
  end
  for i, item in ipairs(list) do
    if value_to_find(item) then
      return item, i
    end
  end
  return nil, -1
end

---@param dest any[] Items to be merged
---@param source any[] Items to merge with
function M.list_extend(dest, source)
  local offset = #dest
  for i = 1, #source do
    dest[offset + i] = source[i]
  end
end

---@deprecated use table_op.tbl_values()
---@generic T
---@param set table<unknown, T>
---@return T[]
function M.set_into_list(set)
  return M.tbl_values(set)
end

---@generic T
---@param list table<any, T>
---@return T[]
function M.tbl_values(list)
  local result = {} ---@type any[]
  for _, v in pairs(list) do
    result[#result + 1] = v
  end
  return result
end

--- Basic appender function from existing table.
---
--- Note: Does not track additional inserted items not updated by appender.
---@generic T
---@param tbl T[]
---@return fun(item: T): integer
function M.appender(tbl)
  local n = #tbl
  return function(item)
    n = n + 1
    tbl[n] = item
    return n
  end
end

---@generic K: any
---@param tbl table<K, any>
---@return K[]
function M.tbl_keys(tbl)
  local res = {} ---@type any
  local push = M.appender(res)
  ---@diagnostic disable-next-line: no-unknown
  for k in pairs(tbl) do
    push(k)
  end
  return res
end

return M
