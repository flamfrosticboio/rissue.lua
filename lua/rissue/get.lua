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

--- Implementations of `rissue.get_issues()` and `rissue.get_merge_requests()`
---@class rissue.mod.Get
local get = {}

local config = require("rissue.config")
local env = require("rissue.env")
local process = require("rissue.utils.process")

---@generic A, B
---@param func fun(): A, B
---@return A
---@return B
local function with_co_blocking(func)
  local done = false
  local a, b
  local co = coroutine.create(function()
    a, b = func()
    done = true
  end)

  local co_ok, co_err = coroutine.resume(co)
  if not co_ok then
    return nil, co_err
  end

  local wait_ok, wait_err = process.wait(function()
    return done
  end, config.options.timeout)

  if not wait_ok then
    return nil, wait_err or "unknown error while waiting"
  end

  return a, b
end

---@param info rissue.ProviderInfo
---@param opts table?
---@param command "get_issues" | "get_merge_requests"
---@return any[]? results
---@return string? errors
local function get_issues_or_merge(info, opts, command)
  ---@type rissue.Provider?
  local provider = config.providers[info.name]
  if not provider then
    return nil, "Could not find provider: " .. info.name
  end

  local co, is_main = coroutine.running()
  if not is_main and co then
    return provider[command](
      info,
      env.get_token(provider.name),
      config.merge_provider_settings(provider, opts)
    )
  end

  -- Blocking implementation
  return with_co_blocking(function()
    return provider[command](
      info,
      env.get_token(provider.name),
      config.merge_provider_settings(provider, opts)
    )
  end)
end

--- Gets issues specified with info and provider opts
---@param info rissue.ProviderInfo
---@param opts table? Settings that are based on provider
---@return rissue.issue[]? results
---@return string? errors
function get.issues(info, opts)
  local res, err = get_issues_or_merge(info, opts, "get_issues")
  return res, err
end

--- Gets merge requests specified with info and provider opts
---@param info rissue.ProviderInfo
---@param opts table? Settings that are based on provider
---@return rissue.pr[]? results
---@return string? errors
function get.merge_requests(info, opts)
  local res, err = get_issues_or_merge(info, opts, "get_merge_requests")
  return res, err
end

return get
