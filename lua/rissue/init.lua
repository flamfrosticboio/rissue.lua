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

--- A plugin that gets issues and merge requests from git provider.
---
--- Example usage:
---
--- ```lua
--- local rissue = require('rissue')
--- rissue.setup({
---     -- your preferred configuration
--- })
--- rissue.get_issues("https://github.com/flamfrosticboio/rissue")
--- rissue.get_merge_requests("https://github.com/flamfrosticboio/rissue")
--- ```
---@class rissue
local rissue = {}

local async = require("rissue.utils.async")
local config = require("rissue.config")
local env = require("rissue.env")
local get = require("rissue.get")
local provider = require("rissue.provider")
local table_op = require("rissue.utils.table_op")

--- Run setup for rissue.
---
--- Example:
--- ```lua
--- rissue.setup({
---    timeout = 20000 -- 20 seconds
--- }, "/home/user/projects/my_project")
--- -- Will read the .env file from that path
--- ```
---@param opts? rissue.Opts Configuration
---@param cwd? string The current working directory (used in finding env file)
---@return string? err_msg The error message from setup
function rissue.setup(opts, cwd)
  local err = config.setup(opts)
  if err then
    return err
  end

  --- no need to check status
  env.setup(config.options.env_file, cwd)

  --- setup logging
  local log = require("rissue.utils.log")
  log.setup(opts and opts.log or {})
end

rissue.get_remote_info = provider.remote_info

---@param cb async fun(a: rissue.Async)
---@return string? err_msg
local function run_blocking(cb)
  local backend, wait = async.default_backend()
  local done = false
  async.run(
    backend, ---@async
    function(a)
      cb(a)
      done = true
    end
  )

  local success, err = wait(function()
    return done
  end, config.options.timeout)

  if not success then
    return err
  end
end

--- Gets the provider info from remote info or remote url.
---
--- Example:
---
--- ```lua
--- --- # With url
--- rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
--- -- should return a github related provider info
---
--- --- # With already parsed or manual constructed `rissue.RemoteInfo`
--- local remote_info =
---   rissue.get_remote_info("https://github.com/flamfrosticboio/rissue.git")
--- rissue.get_provider_info(remote_info)
--- ```
---@param remote rissue.RemoteInfo Where string is remote url
---@param opts?table<rissue.ProviderName,table?>Additional options for providers
---@return rissue.ProviderInfo? provider_info
---@return string? error
---@overload fun(remote: string, opts?: table<rissue.ProviderName, table?>):
---rissue.ProviderInfo?, string?
function rissue.get_provider_info(remote, opts)
  local remote_t = type(remote)
  if remote_t ~= "string" and remote_t ~= "table" then
    return nil, "Argument 1 is not string|rissue.RemoteInfo"
  end

  if remote_t == "string" then
    local remote_res, remote_err = provider.remote_info(remote --[[@as string]])

    if not remote_res then
      return nil, remote_err or "unknown error"
    end

    remote = remote_res
  end

  local result, err
  local run_err = run_blocking(
    ---@async
    function(a)
      result, err = provider.provider_info(a, remote, opts)
    end
  )

  return result, run_err or err
end

---@param remote string | rissue.RemoteInfo | rissue.ProviderInfo
---@param opts? table<rissue.ProviderName, table?> | table
---@return rissue.ProviderInfo?
---@return table? opts
---@return string? error
local function into_provider_info(remote, opts)
  local remote_t = type(remote)
  if remote_t ~= "string" and remote_t ~= "table" then
    return nil,
      nil,
      "Argument 1 is not string|rissue.ProviderInfo|rissue.RemoteInfo"
  end

  if
    remote_t == "string" or (remote --[[@as rissue.RemoteInfo]]).full_url
  then
    local remote_res, remote_err =
      rissue.get_provider_info(remote --[[@as string]], opts)

    if not remote_res then
      return nil, nil, remote_err or "unknown error"
    end

    return remote_res, opts and opts[remote_res.name]
  end

  ---@cast remote rissue.ProviderInfo
  return remote, opts
end

--- Gets issues from the url, remote info or provider info
---
--- If the provided remote is a `string` (url) or `rissue.RemoteInfo`,
--- then the `opts` arg requires specifying the provider name inside a table.
---
--- Example:
---
--- ```lua
--- --- Passing opts as `string` or `rissue.RemoteInfo`
--- rissue.get_issues("https://github.com/flamfrosticboio/rissue.git", {
---   github = { max_items = 50 },
---   gitlab = { max_items = 500 },
---   --- gitea and forgejo may use default/user settings
--- })
---
--- --- Passing opts as `rissue.ProviderInfo`
--- local info, err =
---   rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
--- assert(info, err)
--- assert(info.name == "github", "Not a github provider")
--- --- Now we know that info is specifically github
--- rissue.get_issues(info, { max_items = 50 })
--- ```
---@param remote rissue.ProviderInfo | rissue.RemoteInfo | string # See description
---@param opts? table<rissue.ProviderName, table?> | table # See description
---@return rissue.issue[]? issues List of issues. `nil` when it fails.
---@return string? err_msg Error message if operation fails.
function rissue.get_issues(remote, opts)
  local provider_info, new_opts, convert_err = into_provider_info(remote, opts)
  if not provider_info then
    return nil, convert_err or "unknown error"
  end

  local result = {} ---@type rissue.issue[]
  local pusher = table_op.appender(result)

  local run_err = run_blocking(
    ---@async
    function(a)
      local err = get.issues(a, provider_info, new_opts, pusher)
      if err then
        error(err, 0)
      end
    end
  )

  return result, run_err
end

--- Gets merge requests from the remote url, remote info or provider info
---
--- If the provided remote is a `string` (url) or `rissue.RemoteInfo`,
--- then the `opts` arg requires specifying the provider name inside a table.
---
--- Example:
--- ```lua
--- --- Passing opts as `string` or `rissue.RemoteInfo`
--- rissue.get_merge_requests("https://github.com/flamfrosticboio/rissue.git", {
---   github = { max_items = 50 },
---   gitlab = { max_items = 500 },
---   --- gitea and forgejo may use default/user settings
--- })
---
--- --- Passing opts as `rissue.ProviderInfo`
--- local info, err =
---   rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
--- assert(info, err)
--- assert(info.name == "github", "Not a github provider")
--- --- Now we know that info is specifically github
--- rissue.get_merge_requests(info, { max_items = 50 })
--- ```
---
---@param remote rissue.ProviderInfo | rissue.RemoteInfo | string # See description
---@param opts? table<rissue.ProviderName, table?> | table # See description
---@return rissue.pr[]? merge_requests List of merge requests. `nil` when it fails.
---@return string? err_msg Error message if operation fails.
function rissue.get_merge_requests(remote, opts)
  local provider_info, new_opts, convert_err = into_provider_info(remote, opts)
  if not provider_info then
    return nil, convert_err or "unknown error"
  end

  local result = {} ---@type rissue.pr[]
  local pusher = table_op.appender(result)

  local run_err = run_blocking(
    ---@async
    function(a)
      local err = get.merge_requests(a, provider_info, new_opts, pusher)
      if err then
        error(err, 0)
      end
    end
  )

  if run_err then
    return nil, run_err
  end

  return result
end

return rissue
