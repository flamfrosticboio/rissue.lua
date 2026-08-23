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

local log = require("rissue.utils.log")

local token_header_template = "Authorization: Bearer " -- just append the token after this
-- local fetch_response_header = "Accept: application/vnd.github.raw+json"
local basic_json_header = "Accept: application/json"
local curl_headers_template = {
  "X-GitHub-Api-Version: 2022-11-28",
}

local function list_shallow_copy(list)
  local result = {}
  for i = 1, #list do
    result[i] = list[i]
  end
  return result
end

---@param mod rissue.utils.ProcessModule
---@param url string
---@param headers string[]
---@return rissue.utils.CmdResult? result
---@return string? error
local function curl_get(mod, url, headers)
  local args = { "-sS", "-L", "-X", "GET", url }
  for _, header in ipairs(headers) do
    args[#args + 1] = "-H"
    args[#args + 1] = header
  end
  print("START RUNNING WITH CO")
  return mod.run_co({
    cmd = "curl",
    args = args,
  })
end

---@type rissue.provider_spec
local M = {
  provider_name = "github",
  map_into_issue = function(_fetch_result)
    return {}
  end,
  map_into_pr = function(_fetch_result)
    return {}
  end,
  supports = function(info, util, token)
    ---@type string[]
    local headers = list_shallow_copy(curl_headers_template)
    headers[#headers + 1] = basic_json_header
    if token then
      headers[#headers + 1] = token_header_template .. token
    end

    ---@type string[]
    local urls = {
      info.curl_protocol .. "://" .. info.domain .. "/meta",
      info.curl_protocol .. "://" .. info.domain .. "/api/v3/meta",
    }

    for _, url in ipairs(urls) do
      local result, err = curl_get(util, url, headers)
      if not result then
        log.warn("Failed to fetch endpoint: " .. err)
      end

      if result and result.stdout:match("verifiable_password_authentication") then
        return true
      end
    end

    return false
  end,
}

return M
