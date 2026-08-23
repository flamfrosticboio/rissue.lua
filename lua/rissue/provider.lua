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
local env = require("rissue.env")
local log = require("rissue.utils.log")
local process = require("rissue.utils.process")

local M = {}

--- Extracts the remote url to `rissue.RemoteInfo`
---@param remote_url string
---@return rissue.RemoteInfo?
function M.remote_info(remote_url)
  remote_url = remote_url:gsub("%s+$", "")
  -- all protocols must go to https except then the url is on http mode
  local protocol = remote_url:match("^http://") and "http" or "https"
  local domain = remote_url:match("^https?://([^/]+)")
    or remote_url:match("^git@([^:]+):")
    or remote_url:match("^ssh://git@([^/]+)")

  local path = remote_url:match("^https?://[^/]+/(.+)$")
    or remote_url:match("^git@[^:]+:(.+)$")
    or remote_url:match("^ssh://git@[^/]+/(.+)$")

  local owner, repo
  if path then
    path = path:gsub("%.git$", "")
    repo = path:match("([^/]+)$")
    owner = path:match("^(.+)/[^/]+$")

    ---@type rissue.RemoteInfo
    return {
      curl_protocol = protocol,
      domain = domain,
      repo = repo,
      owner = owner,
      full_url = remote_url,
    }
  end
end

---@async
---@param remote_url string
---@param level integer
---@return rissue.ProviderInfo
---@return string? warnings
local function get_provider_info_unsafe(remote_url, level)
  level = level or 0
  local remote_info = M.remote_info(remote_url)
  if not remote_info then
    error("Could not parse remote url", 2 + level)
  end
  remote_url = remote_info.full_url

  -- known public hosting providers - no API call needed
  for provider_name, spec in pairs(config.options.endpoint_shortcuts) do
    for _, pattern in ipairs(spec.patterns) do
      if remote_url:match(pattern) then
        ---@type rissue.ProviderInfo
        local info = {
          domain = spec.domain,
          name = provider_name,
          owner = remote_info.owner,
          repo = remote_info.repo,
          protocol = remote_info.curl_protocol,
        }
        return info
      end
    end
  end

  for provider_name, provider in pairs(config.providers) do
    -- async calling blocking pattern
    local supported
    local finished = false

    local token = env.get_token(provider_name)
    local thread = coroutine.create(function()
      supported = provider.supports(remote_info, process, token)
      finished = true
    end)
    local co_ok, co_error = coroutine.resume(thread)
    if not co_ok then
      error(co_error)
    end

    -- todo: make this compatible inside coroutine

    local success = process.wait(function()
      return finished
    end, 60000) -- todo: add timeout in settings
    if not success then
      log.warn("provider check timeout on " .. provider)
    end

    if supported then
      local info = {
        name = provider_name,
        domain = remote_info.domain,
        owner = remote_info.owner,
        repo = remote_info.repo,
        protocol = remote_info.curl_protocol,
      }
      return info
    end
  end

  error("No identifiable git provider", 0)
end

--- Gets the provider info based on the remote url.
--- May trigger api requests to the url.
---@async
---@param remote_url string
---@return boolean success
---@return rissue.ProviderInfo | string
function M.get_provider_info(remote_url)
  local ok, info = pcall(get_provider_info_unsafe, remote_url)
  return ok, info
end

return M
