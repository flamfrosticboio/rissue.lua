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

local rissue = {}

local config = require("rissue.config")
local env = require("rissue.env")
local get = require("rissue.get")
local provider = require("rissue.provider")

--- Throws an error as string when it failed to setup
---@param opts rissue.Opts?
---@param cwd  string?
---@return string?
function rissue.setup(opts, cwd)
  local err = config.setup(opts)
  if err then
    return err
  end

  env.setup(config.options.env_file, cwd)
end

rissue.get_remote_info = provider.remote_info

--- Gets the provider info from a remote
---@param remote rissue.RemoteInfo Where string is remote url
---@param opts? table<rissue.ProviderName, table?> Additional options passed to providers
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

  ---@cast remote rissue.RemoteInfo
  return provider.provider_info(remote, opts)
end

---@param remote string | rissue.RemoteInfo | rissue.ProviderInfo
---@return rissue.ProviderInfo?
---@return string? error
local function into_provider_info(remote)
  local remote_t = type(remote)
  if remote_t ~= "string" and remote_t ~= "table" then
    return nil, "Argument 1 is not string|rissue.ProviderInfo|rissue.RemoteInfo"
  end

  if
    remote_t == "string" or (remote --[[@as rissue.RemoteInfo]]).full_url
  then
    local remote_res, remote_err =
      rissue.get_provider_info(remote --[[@as string]])

    if not remote_res then
      return nil, remote_err or "unknown error"
    end

    remote = remote_res
  end

  ---@cast remote rissue.ProviderInfo
  return remote
end

--- Gets issues from the remote url or provider info
---@param remote string | rissue.ProviderInfo | rissue.RemoteInfo Where string is remote url
---@param opts any
function rissue.get_issues(remote, opts)
  local _remote, err = into_provider_info(remote)
  if not _remote then
    return nil, err or "unknown error"
  end
  return get.issues(_remote, opts)
end

--- Gets issues from the remote url or provider info
---@param remote string | rissue.ProviderInfo | rissue.RemoteInfo Where string is remote url
---@param opts any
function rissue.get_merge_requests(remote, opts)
  local _remote, err = into_provider_info(remote)
  if not _remote then
    return nil, err or "unknown error"
  end
  return get.issues(_remote, opts)
end

return rissue
