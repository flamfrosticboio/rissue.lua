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

local _log = require("rissue.utils.log")
local json = require("rissue.utils.json")

shared.log = _log.new({ context = "Github" })
local log = shared.log

---@param body string
---@return string? msg
local function try_print_server_error(body)
  local decoded, decode_err = json.decode(body)
  if type(decoded) ~= "table" then
    log.debug("Failed to read failing body message:", decode_err)
    log.trace("Failing decode error body:", body)
    return nil
  end

  ---@type string?
  local msg = type(decoded.message) == "string" and decoded.message
    or type(decoded.detail) == "string" and decoded.detail
    or nil
  if not msg then
    return nil
  end

  local decoded_errors = decoded.errors ---@type (string|table)[]?
  -- 422: append details (strings or objects)
  if type(decoded_errors) == "table" then
    for _, e in ipairs(decoded_errors) do
      if type(e) == "string" then
        msg = msg .. "\n- " .. e
      elseif type(e) == "table" then
        ---@type string?
        local text = e.message or e.code

        if type(text) == "string" then
          msg = msg
            .. "\n- "
            .. (type(e.field) == "string" and (e.field .. ": ") or "")
            .. text
        end
      end
    end
  end

  return msg
end

---@param err rissue.curl.Error
---@return string
function shared.into_error_message(err)
  local base = err.msg or "unknown error"
  local server = err.server_msg
  if type(server) ~= "string" or server == "" then
    return base
  end

  local detail = try_print_server_error(server) or server
  return base .. "\nServer Message: " .. detail
end

return shared
