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
local process = require("rissue.utils.process")

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

---@param url string
---@param headers string[]
---@return rissue.utils.CmdResult? result
---@return string? error
local function curl_get(url, headers)
  local args = { "-sS", "-L", "-X", "GET", url }
  for _, header in ipairs(headers) do
    args[#args + 1] = "-H"
    args[#args + 1] = header
  end
  print("START RUNNING WITH CO")
  return process.run_co({
    cmd = "curl",
    args = args,
  })
end

--- todo: complete this
--- Instead of mapping, we just let the provider do it
--- But we need to implement the abstract method on curling

---@class rissue.Provider.Opts: table
---@field custom_fetch_endpoints string[]

---@param info rissue.ProviderInfo
local function get_api_endpoint(info)
  return info.protocol
    .. "://"
    .. info.domain
    .. (info.additional_info and info.additional_info.ghes == true and "/api/v3" or "")
end

---@param url string
---@param headers string[]
local function check(url, headers)
  local result, err = curl_get(url, headers)
  if not result then
    log.warn(("Failed to fetch endpoint '%s': %s"):format(url, err))
  end

  return result and result.stdout:match("verifiable_password_authentication")
end

---@type rissue.provider_spec
local M = {
  provider_name = "github",
  get_merge_requests = function(opts, info, token) end,
  get_issues = function(opts, info, token) end,
  supports = function(info, token)
    ---@type string[]
    local headers = list_shallow_copy(curl_headers_template)
    headers[#headers + 1] = basic_json_header
    if token then
      headers[#headers + 1] = token_header_template .. token
    end

    local base = info.curl_protocol .. "://" .. info.domain

    -- is ghes version
    if check(base .. "/api/v3/meta", headers) then
      return true, { ghes = true }
    elseif check(base .. "/meta", headers) then
      return true
    end

    return false
  end,
}

return M
