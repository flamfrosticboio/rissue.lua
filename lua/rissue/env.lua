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

local config = require("rissue.config")

local M = {}

M.env = {}

---@param path string
local function load_env(path)
  local env = {}
  local file = io.open(path, "r")
  if not file then
    return env
  end

  for line in file:lines() do
    if type(line) == "string" then
      -- skip blank lines and comments
      if line:match("%S") and not line:match("^%s*#") then
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key and value then
          -- strip surrounding quotes if present
          value = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
          env[key] = value
        end
      end
    end
  end
  file:close()
  return env
end

local sep = package.config:sub(1, 1)
local function path_join(...)
  return table.concat({ ... }, sep)
end

--- Default: cwd='.'
---@param env_filename string
---@param cwd          string?
function M.setup(env_filename, cwd)
  local env_path = path_join(cwd or ".", env_filename)
  M.env = load_env(env_path)
end

---@param name string
---@return string?
function M.get(name)
  return M.env[name] or os.getenv(name)
end

---@param provider rissue.ProviderName
---@return string?
function M.get_token(provider)
  return M.get(config.options.env.provider_prefix .. provider:upper())
end

return M
