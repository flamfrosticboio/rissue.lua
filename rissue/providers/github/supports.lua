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

local config = require("rissue.providers.github.config")
local curl = require("rissue.utils.curl")
local log = require("rissue.utils.log")

local M = {}

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

---@param url string
---@param opts rissue.utils.curl.Opts
---@return boolean
---@return string? result
local function check(url, opts)
  local result, err = curl.request(url, opts)
  if not result then
    log.warn(("Failed to fetch endpoint '%s': %s"):format(url, err))
  end

  return not not (result and result.content:match("verifiable_password_authentication")),
    result and result.content
end

---@type rissue.provider.Supports<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
function M.main(info, token, opts)
  local base = info.curl_protocol .. "://" .. info.domain

  ---@type rissue.utils.curl.Opts
  local settings = { auth = token, accept = "application/json", method = "GET" }

  -- ghes version
  local is_ghes, ghes_output = check(base .. "/api/v3/meta", settings)
  if is_ghes then
    ---@type rissue.Github.supports.AdditionalInfo
    local additional_info = {}
    if ghes_output then
      local major, minor = ghes_output:match('"installed_version":%s*"(%d+)%.(%d+)')
      local version = tonumber(major) * 1000 + tonumber(minor)
      additional_info.ghes = major .. "." .. minor
      additional_info.ghes_code = version

      if type(opts.api_version) == "string" then
        additional_info.api_version = opts.api_version
      elseif opts.api_version ~= false then
        additional_info.api_version = from_range(config.ghes_api_version_range, version)
      end
    end
    return true, additional_info
  end

  -- ghec or api.github.com version (when checking with url failed)
  -- examples includes: domain proxy, GHEC with Data Residency
  local res = check(base .. "/meta", settings)
  if res then
    return res, { api_version = "2026-03-10" } --[[@as rissue.Github.supports.AdditionalInfo]]
  end
  return false
end

return M
