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

--- ### rissue.config.settings ### ---

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
    {
      name = "github",
      domain = "api.github.com",
      patterns = { "github%.com" },
      additional_info = {
        api_version = "2026-03-10",
      } --[[@as rissue.Github.supports.AdditionalInfo]],
    },
    {
      name = "gitlab",
      domain = "gitlab.com",
      patterns = { "gitlab%.com" },
    },
  },
  timeout = 60000,
  log = {},
}

--- ### rissue.config.settings ### ---

--- Table of available providers
---@type table<rissue.ProviderName, rissue.Provider>
config.providers = {}

---@type table<rissue.ProviderName, fun(): rissue.Provider>
local LOCAL_PROVIDERS = {
  github = function()
    return require("rissue.providers.github")
  end,
  gitlab = function()
    return require("rissue.providers.gitlab")
  end,
}

local matchers = assert_op.matchers

---@param obj any
---@return boolean success
---@return string? err_msg
local function is_provider_spec(obj)
  local ok, err = assert_op.table_expects(obj, {
    name = matchers.is_string,
    version = matchers.follows({
      major = matchers.is_integer,
      minor = matchers.is_integer,
      patch = matchers.is_integer,
    }, "rissue.Version"),
    get_issues = matchers.is_function,
    get_merge_requests = matchers.is_function,
    supports = matchers.is_function,
    settings = matchers.is_table,
  }, "m")
  if not ok then
    return false, ("Not a provider spec: %s"):format(err)
  end
  return true
end

---@param chunk fun(): any
---@return rissue.Provider?
---@return string? err_msg
local function try_load_provider(chunk)
  ---@type boolean, rissue.Provider|string
  local ok, err_or_provider = pcall(function()
    local mod = chunk() ---@type any
    local check_ok, err_msg = is_provider_spec(mod)
    if check_ok ~= true then
      error(err_msg, 0)
    end

    ---@type rissue.Provider
    return mod
  end)

  if ok then
    ---@cast err_or_provider rissue.Provider
    return err_or_provider
  else
    ---@cast err_or_provider string
    return nil, err_or_provider or "unknown error"
  end
end

---@param push_error fun(err: string)
local function load_local_providers(push_error)
  for name, chunk in pairs(LOCAL_PROVIDERS) do
    local provider, load_err = try_load_provider(chunk)

    if not provider then
      push_error(
        string.format(
          "[bug]: failed to load %s: %s",
          name,
          load_err or "unknown error"
        )
      )
    elseif provider.name ~= name then
      push_error(
        string.format(
          "[bug]: provider key '%s' does not match its name '%s'",
          name,
          provider.name
        )
      )
    else
      config.providers[provider.name] = provider
    end
  end
end

---@param push_error fun(err: string)
local function load_additional_providers(push_error)
  for _, filepath in ipairs(config.options.additional_providers) do
    local chunk, err = loadfile(filepath)
    if chunk then
      local provider, load_err = try_load_provider(chunk)
      if provider then
        config.providers[provider.name] = provider
      else
        push_error(
          string.format(
            "failed to load '%s': %s",
            filepath,
            load_err or "unknown error"
          )
        )
      end
    else
      push_error(string.format("failed to load '%s': %s", filepath, err))
    end
  end
end

--- Setups settings, scans available providers and configure other
--- configurations.
---@param opts rissue.Opts?
---@return string? setup_error
function config.setup(opts)
  config.options = table_op.force_deep_extend(config.options, opts or {})
  local errors = {} ---@type string[]

  local push_error = table_op.appender(errors)
  load_local_providers(push_error)
  load_additional_providers(push_error)

  if #errors > 0 then
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
