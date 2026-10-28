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

local M = {}

---@param obj  any
---@param list any
---@return boolean
local function _is_instance(obj, list)
  local t = type(obj)
  for _, expected_type in ipairs(list) do
    if t == expected_type then
      return true
    end
  end
  return false
end

---@param obj any
---@param ... type
---@return boolean
---@overload fun(obj: any, t: type[]): boolean
function M.is_instance(obj, ...)
  local args = { ... }
  if type(args[1]) == "table" then
    return _is_instance(obj, args[1])
  end
  return _is_instance(obj, args)
end

---@alias rissue.utils.Matcher fun(_obj: any): (boolean, string?, string?)

---@class rissue.utils.Matchers
---@field is_table rissue.utils.Matcher
---@field is_function rissue.utils.Matcher
---@field is_string rissue.utils.Matcher
---@field is_boolean rissue.utils.Matcher
---@field is_number rissue.utils.Matcher
---@field is_thread rissue.utils.Matcher
---@field is_userdata rissue.utils.Matcher
---@field is_nil rissue.utils.Matcher
---@field multiple fun(...: rissue.utils.Matcher|any): rissue.utils.Matcher
---@field follows fun(schema: table<string, rissue.utils.Matcher|any>, schema_name: string): rissue.utils.Matcher

---@param obj any
---@return string
local function represent(obj)
  if type(obj) == "string" then
    return '"' .. obj .. '"'
  end
  return tostring(obj)
end

M.DISALLOWED_KEYWORDS = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["goto"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
}

local function can_use_dot(s)
  return type(s) == "string"
    and s:match("^[%a_][%w_]*$") ~= nil
    and not M.DISALLOWED_KEYWORDS[s]
end
---@param key string
---@return string
local function represent_key(key)
  if type(key) == "string" and can_use_dot(key) then
    return "." .. key
  end
  return "[" .. represent(key) .. "]"
end

local registered_matchers = {}

---@param func fun()
local function is_matcher(func)
  for _, matcher in ipairs(registered_matchers) do
    if func == matcher then
      return true
    end
  end
  return false
end

---@type rissue.utils.Matchers
M.matchers =
  ---@diagnostic disable-next-line: missing-fields
  {
    multiple = function(...)
      local matchers = { ... } ---@type (rissue.utils.Matcher|any)[]
      local total_matchers = select("#", ...)

      ---@type rissue.utils.Matcher
      local matcher = function(_obj)
        local out_str_tbl = {}
        for i = 1, total_matchers do
          local v = matchers[i]
          if is_matcher(v) then
            local is_match, _, expected_type = v(_obj)
            if is_match == true then
              return true
            else
              out_str_tbl[#out_str_tbl + 1] = expected_type
            end
          else
            if _obj == v then
              return true
            end
            out_str_tbl[#out_str_tbl + 1] = "`" .. represent(v) .. "`"
          end
        end
        local concatted_types = table.concat(out_str_tbl, "|")
        return false,
          table.concat({
            "Expecting %s to be ",
            concatted_types,
            ", got ",
            represent(_obj),
            " (type ",
            type(_obj),
            ")",
          }),
          concatted_types
      end

      registered_matchers[#registered_matchers + 1] = matcher

      return matcher
    end,

    follows = function(schema, schema_name)
      ---@type rissue.utils.Matcher
      local matcher = function(tbl)
        local obj_type = type(tbl)
        if obj_type ~= "table" then
          return false, "Expecting %s to be a table, got " .. obj_type, "table"
        end

        ---@cast tbl table
        for k, v in pairs(schema) do
          local obj = tbl[k]
          if is_matcher(v) then
            local is_matched, err_msg = v(obj)
            if is_matched ~= true then
              return false,
                string.format(
                  (err_msg or "unknown reason"),
                  "%s" .. represent_key(k)
                ),
                schema_name
            end
          else
            if obj ~= v then
              return false,
                string.format(
                  "Expecting %%s%s to be %s, got %s",
                  represent_key(k),
                  represent(v),
                  represent(obj)
                ),
                schema_name
            end
          end
        end

        return true
      end

      registered_matchers[#registered_matchers + 1] = matcher

      return matcher
    end,
  }

local types = {
  "boolean",
  "function",
  "string",
  "number",
  "userdata",
  "thread",
  "table",
  "nil",
} ---@type table<integer, type>
for _, t in ipairs(types) do
  local name = "is_" .. t
  ---@type rissue.utils.Matcher
  local matcher = function(_obj)
    local obj_type = type(_obj)
    if obj_type == t then
      return true
    end
    return false,
      table.concat({
        "Expecting %s to be a ",
        t,
        ", got ",
        represent(_obj),
        " (type ",
        obj_type,
        ")",
      }),
      t
  end

  M.matchers[name] = matcher
  registered_matchers[#registered_matchers + 1] = matcher
end

--- Checks a table's structure to see if it matches with the specified literal data or
--- matcher.
---@param obj any
---@param structure table
---@param name string?
---@return boolean success
---@return string? err_msg
function M.table_expects(obj, structure, name)
  name = name or "obj"
  if type(obj) ~= "table" then
    return false, ("Expecting %s to be table, got %s"):format(name, type(obj))
  end

  ---@cast obj table

  for k, v in pairs(structure) do
    local val = obj[k]
    if is_matcher(v) then
      ---@cast v rissue.utils.Matcher
      local is_match, err_msg = v(val)
      if is_match ~= true then
        return false,
          (err_msg or "unknown message"):format(name .. represent_key(k))
      end
    elseif v ~= val then
      return false,
        ("Expecting %s to be %s, got %s"):format(
          name .. represent_key(k),
          represent(v),
          represent(val)
        )
    end
  end

  return true
end

return M
