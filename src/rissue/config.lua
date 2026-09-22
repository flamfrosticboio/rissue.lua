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

local assert_op = require("rissue.utils.assert_op")
local table_op = require("rissue.utils.table_op")

--- Used for storing current configurations and settings
---@class rissue.mod.Config
local config = {}

--- Settings (configured with `rissue.setup()`)
---@type rissue.Config
config.options = {
  additional_providers = {},
  env_file = ".env",
  env = {
    provider_prefix = "GIT_TK_",
  },
  provider_options = {},
  endpoint_shortcuts = {
    github = {
      domain = "api.github.com",
      patterns = { "github%.com" },
      additional_info = {
        api_version = "2026-03-10",
      } --[[@as rissue.Github.supports.AdditionalInfo]],
    },
  },
  timeout = 60000,
}

--- Table of available providers
---@type table<rissue.ProviderName, rissue.Provider>
config.providers = { github = require("rissue.providers.github") }

---@param obj any
---@return rissue.Provider
local function is_provider_spec(obj)
  local ok, err = assert_op.check_structure("rissue.provider_spec", obj, {
    provider_name = "string",
    map_into_issue = "function",
    map_into_pr = "function",
  }, "module")
  if not ok then
    error(err, 2)
  end
  return obj
end

--- Setups settings, scans available providers and configure other
--- configurations.
---@param opts rissue.Opts?
---@return string? setup_error
function config.setup(opts)
  config.options = table_op.force_deep_extend(config.options, opts or {})

  local errors = {}
  local _err_idx = 0
  for _, filepath in ipairs(config.options.additional_providers) do
    local chunk, err = loadfile(filepath)
    if chunk then
      local load_ok, load_err = pcall(function()
        local mod = chunk()
        if not is_provider_spec(mod) then
          return
        end
        ---@cast mod rissue.Provider
        config.providers[mod.name] = mod
      end)

      if not load_ok then
        _err_idx = _err_idx + 1
        errors[_err_idx] = load_err
      end
    else
      _err_idx = _err_idx + 1
      errors[_err_idx] = err
    end
  end

  if _err_idx > 0 then
    return "Failed to setup rissue properly: \n\n" .. table.concat(errors, "\n")
  end
end

--- A utility function for merging settings from:
---   1. request options (from `rissue.get_issues()` and etc.)
---   2. user defined settings
---   3. provider's default settings
---@param provider rissue.Provider
---@param request table?
---@return table? merged_settings
---@return string? error
function config.merge_provider_settings(provider, request)
  local settings = config.options.provider_options[provider.name]
  return table_op.force_deep_extend(
    provider.settings,
    settings or {},
    request or {}
  )
end

return config
