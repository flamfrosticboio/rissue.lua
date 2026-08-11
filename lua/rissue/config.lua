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

local assert_op = require("rissue.utils.assert_op")
local table_op = require("rissue.utils.table_op")

local config = {}

---@type rissue.Config
config.options = {
  additional_providers = {},
  env_file = ".env",
  env = {
    provider_prefix = "GIT_TK_",
  },
  endpoints = {},
  endpoint_shortcuts = {
    github = {
      domain = "api.github.com",
      patterns = { "github%.com" },
    },
  },
}

---@type table<rissue.provider, rissue.provider_spec>
config.providers = { github = require("rissue.providers.github") }

---@param obj any
---@return rissue.provider_spec
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

--- Returns an error as string if it errors
---@param opts rissue.Opts?
---@return string?
function config.setup(opts)
  config.options = table_op.force_deep_extend(config.options, opts or {})

  local errors = {}
  local _err_idx = 0
  for _, filepath in ipairs(config.options.additional_providers) do
    local name = filepath:match("rissue[/\\]providers[/\\](.+)%.lua$")
    if name then
      local ok, mod = pcall(require, "rissue.providers." .. name)
      if ok then
        local load_ok, err = pcall(function()
          if not is_provider_spec(mod) then
            return
          end
          ---@cast mod rissue.provider_spec
          config.providers[mod.provider_name] = mod
        end)

        if not load_ok then
          _err_idx = _err_idx + 1
          errors[_err_idx] = err
        end
      end
    end
  end

  if _err_idx > 0 then
    return "Failed to setup rissue properly: \n\n" .. table.concat(errors, "\n")
  end
end

return config
