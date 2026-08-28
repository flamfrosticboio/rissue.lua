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

local ghes_latest = 03022
---@type {[1]: integer, [2]: integer, [3]: string}[]
local ghes_api_versions_range = {
  { 03009, 03020, "2022-11-28" }, -- ghes 3.9-3.20
  { 03021, ghes_latest, "2026-03-10" }, -- ghes 3.21+
}

---@generic T
---@param range {[1]: integer, [2]: integer, [3]: T}[]
---@param target integer
---@return T?
local function from_range(range, target)
  for _, val in ipairs(range) do
    if val[1] <= target and val[2] >= target then
      return val[3]
    end
  end
end

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
---@return boolean
---@return string? result
local function check(url, headers)
  local result, err = curl_get(url, headers)
  if not result then
    log.warn(("Failed to fetch endpoint '%s': %s"):format(url, err))
  end

  return result and result.stdout:match("verifiable_password_authentication"),
    result and result.stdout
end

---@alias rissue.Github.SupportedApiVersions "2026-03-10" | "2022-11-28"

---@class rissue.Github.supports.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.SupportedApiVersions?

---@type rissue.provider_spec
local M = {
  provider_name = "github",
  get_merge_requests = function(opts, info, token) end,
  get_issues = function(opts, info, token) end,

  ---@param opts rissue.provider_spec.supports.Opts<rissue.Github.supports.Opts>
  supports = function(info, token, opts)
    ---@type string[]
    local headers = list_shallow_copy(curl_headers_template)
    headers[#headers + 1] = basic_json_header
    if token then
      headers[#headers + 1] = token_header_template .. token
    end

    local base = info.curl_protocol .. "://" .. info.domain

    -- ghes version
    local is_ghes, ghes_output = check(base .. "/api/v3/meta", headers)
    if is_ghes then
      ---@type rissue.Github.supports.AdditionalInfo
      local additional_info = {}
      if ghes_output then
        local major, minor = ghes_output:match('"installed_version":%s*"(%d+)%.(%d+)')
        local version = tonumber(major) * 1000 + tonumber(minor)
        additional_info.ghes = major .. "." .. minor
        additional_info.ghes_code = version

        if opts.request then
          if type(opts.request.api_version) == "string" then
            additional_info.api_version = opts.request.api_version
          end
          -- do nothing if api_version is false or any other types
        else
          additional_info.api_version = from_range(ghes_api_versions_range, version)
        end
      end
      return true, additional_info
    end

    -- ghec or api.github.com version (when checking with url failed)
    -- examples includes: domain proxy, GHEC with Data Residency
    if check(base .. "/meta", headers) then
      return true
    end

    return false
  end,
}

return M
