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

local M = {}

local config = require("rissue.config")
local env = require("rissue.env")
local log = require("rissue.utils.log")
local process = require("rissue.utils.process")
local table_op = require("rissue.utils.table_op")

--- Merge settings with order (highest = priority):
---   - request options
---   - user defined settings
---   - provider's default settings
---@param provider rissue.Provider
---@param request table?
---@param settings table?
local function merge_settings(provider, settings, request)
  return table_op.force_deep_extend(provider.settings, settings or {}, request or {})
end

---@param info rissue.ProviderInfo
---@param opts table? Settings that are based on provider
---@return rissue.issue[]? results
---@return string? errors
function M.get_issues(info, opts)
  ---@type rissue.Provider?
  local provider = config.providers[info.name]
  if not provider then
    return nil, "Could not find provider: " .. info.name
  end

  local done = false
  local result, err = nil, nil

  coroutine.wrap(function()
    result, err = provider.get_issues(
      info,
      env.get_token(provider.name),
      merge_settings(provider, config.options.provider_options[provider.name], opts)
    )
    done = true
  end)()

  process.wait(function()
    return done
  end, 60000) -- todo: add timeout

  if not result then
    log.error("Failed to get issues: " .. err)
  end

  return result, err
end

return M
