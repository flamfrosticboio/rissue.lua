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

---@class rissue.utils.Strings
local strings = {}

--- Trims whitespaces from output
---@param s string
---@return string
function strings.trim(s)
  local first = s:find("%S")
  if not first then
    return ""
  end
  local last = #s - (s:reverse():find("%S") - 1)
  return s:sub(first, last)
end

--- Trims leading and trailing newlines (\n and \r\n)
---@param s string
---@return string
function strings.trim_newlines(s)
  local first = s:find("[^\r\n]")
  if not first then
    return ""
  end
  local last = #s - (s:reverse():find("[^\r\n]") - 1)
  return s:sub(first, last)
end

--- Safe truncate on utf-8
---@param s string
---@param max integer
---@return string
function strings.truncate(s, max)
  if #s <= max then
    return s
  end

  local cut = max
  while cut > 0 do
    local b = s:byte(cut + 1)
    if b and b >= 0x80 and b < 0xC0 then
      cut = cut - 1
    else
      break
    end
  end

  return s:sub(1, cut)
end

--- Represents the value based on the obj.
---
--- If the obj is a string, it will be enclosed in double quotes ("")
--- Else, it will use `tostring()` to represent the value
---@param obj any
---@return string
function strings.represent_value(obj)
  if type(obj) == "string" then
    return string.format('"%s"', obj)
  end
  return tostring(obj)
end

return strings
