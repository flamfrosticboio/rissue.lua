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

---@async
---@param remote_url string
---@return rissue.ProviderInfo
local function get_provider_info_unsafe(remote_url)
    -- trim all whitespaces
    remote_url = remote_url:gsub("%s+$", "")

    local protocol = remote_url:match("^http://") and "http" or "https"

    -- known hosted providers — no API call needed
    for provider_name, spec in pairs(config.options.endpoint_shortcuts) do
        for _, pattern in ipairs(spec.patterns) do
            if remote_url:match(pattern) then
                -- get owner, repo in https version
                -- it will be used for fast tracking
                ---@type string?, string?
                local owner, repo = remote_url:match("https?://[^/]+/([^/]+)/([^/]+)$")
                if not owner then
                    -- fallback to git
                    owner, repo = remote_url:match("git@[^:]+:([^/]+)/([^/]+)$")
                end

                if owner and repo then
                    -- IMPORTANT: strip the .git at the end
                    repo = repo:gsub("%.git$", "")
                    return {
                        name = provider_name,
                        domain = spec.domain,
                        owner = owner,
                        repo = repo,
                        protocol = protocol,
                    }
                end
            end
        end
    end

    -- unknown domain — probe the version endpoint
    ---@type string?
    local base_url = remote_url:match("^(https?://[^/]+)")
        or (remote_url:match("^git@([^:]+)") or ""):gsub(":", "/")
    if not base_url then
        error("url method is not https or git")
    end

    for provider_name, provider in pairs(config.providers) do
        if provider.supports(remote_url, fetcher.curl) then
            local extracted = provider.extract(remote_url)
            return {
                name = provider_name,
                domain = base_url,
                owner = extracted.owner,
                repo = extracted.repo,
                protocol = protocol,
            }
        end
    end

    error("No identifiable git provider")
end
--- Gets the provider info based on the remote url.
--- May trigger api requests to the url.
---@async
---@param remote_url string
---@return boolean success
---@return rissue.ProviderInfo | string
function M.get_provider_info(remote_url)
    local ok, provider = pcall(get_provider_info_unsafe, remote_url)
    return ok, provider
end

return M
