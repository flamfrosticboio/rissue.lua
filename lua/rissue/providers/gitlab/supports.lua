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

local supports = {}

local curl = require("rissue.utils.curl")
local json = require("rissue.utils.json")
local shared = require("rissue.providers.gitlab.shared")

local log = shared.log

---@param info rissue.RemoteInfo
---@param endpoint string
---@return string
local function construct_endpoint(info, endpoint)
  return info.curl_protocol .. "://" .. info.domain .. "/api/v4/" .. endpoint
end

local CHECK_ENDPOINTS = { "metadata", "version" }

---@return boolean? result nil would indicate skip
---@return rissue.Gitlab.AdditionalInfo?
local function check_result(res, err)
  if not res then
    log.error("Failed to start curl:", err or "unknown error")
    return -- skip to next endpoint
  end

  if res.exitcode ~= 0 then
    log.debug("Server response error: ", res.err .. "\n" .. res.content)
    return -- skip to next endpoint
  end

  local decoded, decode_err = json.decode(res.content)
  if not decoded then
    log.error("Failed to decode response:", decode_err)
    log.trace("Response that failed to decode:\n" .. res.content)
    return false
  end

  if
    type(decoded) ~= "table" or getmetatable(decoded).__jsontype ~= "object"
  then
    log.error("Decoded response is not an object")
    log.trace("Response that failed the assertion:\n" .. res.content)
    return false
  end

  if not decoded.version then
    log.debug("Not a valid gitlab response.")
    log.trace("Response:\n" .. res.content)
    return false
  end

  local version = decoded.version
  local is_enterprise = decoded.enterprise -- boolean or nil (nil on servers older than 15.6)

  if is_enterprise == nil and type(version) == "string" then
    is_enterprise = version:find("-ee", 1, true) ~= nil
  end

  ---@type rissue.Gitlab.AdditionalInfo
  local additional_info = {
    version = version,
    is_enterprise = is_enterprise,
  }

  return true, additional_info
end

---@async
---@type rissue.provider.Supports<rissue.Github.supports.AdditionalInfo, rissue.Gitlab.Config>
---@diagnostic disable-next-line: unused-local
function supports.main(async, info, token, _opts)
  if info.domain:match("gitlab%.com") then
    return true
  end

  local headers = {}
  if token then
    table.insert(headers, "PRIVATE-TOKEN: " .. token)
  end

  for _, endpoint in ipairs(CHECK_ENDPOINTS) do
    print("Gitlab: Checking endpoint", endpoint)
    local res, err = curl.request(async, construct_endpoint(info, endpoint), {
      headers = headers,
      retry_when = "connrefused",
    })

    -- should be fine since `suc` is `true|false|nil` and when `nil`, we just skip
    local suc, additional_info = check_result(res, err)
    if suc ~= nil then
      return suc, additional_info
    end
  end

  return false
end

return supports
