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
local fetcher = require("rissue.utils.cmd")
local env = require("rissue.env")

local M = {}

--- Gets the provider info based on the remote url.
--- May trigger api requests to the url.
---@async
---@param remote_url string
---@return boolean success
---@return rissue.ProviderInfo | string
function M.get_provider_info(remote_url)
    -- trim all whitespaces
    remote_url = remote_url:gsub("%s+$", "")

    -- get owner, repo in https version
    ---@type string?, string?
    local owner, repo = remote_url:match("https?://[^/]+/([^/]+)/([^/]+)$")
    if not owner then
        -- fallback to git
        owner, repo = remote_url:match("git@[^:]+:([^/]+)/([^/]+)$")
    end

    if not owner or not repo then
        return false, "owner or repo not in url"
    end

    -- IMPORTANT: strip the .git at the end
    repo = repo:gsub("%.git$", "")

    -- known hosted providers — no API call needed
    for provider_name, spec in pairs(config.options.endpoint_shortcuts) do
        for _, pattern in ipairs(spec.patterns) do
            if remote_url:match(pattern) then
                return true, {
                        name = provider_name,
                        domain = spec.domain,
                        owner = owner,
                        repo = repo
                    }
            end
        end
    end

    -- unknown domain — probe the version endpoint
    ---@type string?
    local base_url = remote_url:match("^(https?://[^/]+)")
        or (remote_url:match("^git@([^:]+)") or ""):gsub(":", "/")
    if not base_url then
        return false, "url method is not https or git"
    end

    for provider_name, provider in pairs(config.providers) do
        if provider.supports(remote_url, function (url, method)
            return fetcher.curl(url, method, provider.curl_headers)
        end) then
            return true, {
                    name = provider_name,
                    domain = base_url,
                    owner = owner,
                    repo = repo
                }
        end
    end

    return false, "No identifiable git provider"
end

return M
