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

local shared = {}

local json = require("rissue.utils.json")
local log = require("rissue.utils.log")

shared.log = log.new({
  context = "Gitlab",
})

local function flatten_errors(value, path, out)
  local t = type(value)

  if t == "table" then
    if #value > 0 then
      -- array of messages (or nested items)
      for _, item in ipairs(value) do
        flatten_errors(item, path, out)
      end
    else
      local keys = {}
      for k in pairs(value) do
        keys[#keys + 1] = k
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)
      for _, k in ipairs(keys) do
        local name = tostring(k)
        flatten_errors(value[k], path and (path .. "." .. name) or name, out)
      end
    end
  elseif t == "string" or t == "number" or t == "boolean" then
    if path then
      out[#out + 1] = string.format("- %s: %s", path, tostring(value))
    else
      out[#out + 1] = string.format("- %s", tostring(value))
    end
  end
  -- anything else (nil, JSON null userdata) is ignored
end

--- Attempts to read the decoded server response and translates it into an error.
---@param decoded table Decoded server error message
---@return string? msg
function shared.try_represent_server_error(decoded)
  ---@type string?
  local msg = nil

  ---@type string?
  local decoded_message = decoded.message
  if type(decoded_message) == "string" then
    msg = decoded_message
  elseif type(decoded_message) == "table" then
    local lines = {}
    flatten_errors(decoded_message, nil, lines)
    if #lines > 0 then
      msg = table.concat(lines, "\n")
    end
  end

  ---@type string?
  local headline = type(decoded.error) == "string" and decoded.error or nil
  ---@type string?
  local description = type(decoded.error_description) == "string"
      and decoded.error_description
    or nil

  if headline and description then
    headline = headline .. ": " .. description
  end

  if headline and msg and headline ~= msg then
    -- multi-line messages (flattened lists) read better on their own lines
    msg = headline .. (msg:find("\n", 1, true) and "\n" or ": ") .. msg
  elseif headline then
    msg = headline
  end

  return msg
end

---@param body string
---@return string? msg
local function try_print_server_error(body)
  local decoded, decode_err = json.decode(body)
  if type(decoded) ~= "table" then
    log.debug("Failed to read failing body message:", decode_err)
    log.trace("Failing decode error body:", body)
    return nil
  end

  return shared.try_represent_server_error(decoded)
end

---@param err rissue.curl.Error
---@return string?
function shared.into_error_message(err)
  local base = err.msg
  local server = err.server_msg
  if type(server) ~= "string" or server == "" then
    return base
  end

  local detail = try_print_server_error(server) or server
  return base .. "\nServer Message: " .. detail
end

return shared
