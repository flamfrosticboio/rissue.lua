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

---@alias rissue.ProviderName string The name of provider (e.g. "github", "gitlab", "forgejo", "gitea")

--- Second return is for errors
---@alias rissue.provider.GetIssues<I, S>
---| fun(info: rissue.ProviderInfo<I>, token: string|nil, opts: S): rissue.issue[]?, string?

--- Second return is for errors
---@alias rissue.provider.GetMergeRequests<I, S>
---| fun(info: rissue.ProviderInfo<I>, token: string|nil, opts: S): rissue.pr[]?, string?

---@alias rissue.provider.Supports<I, S>
---| fun(info: rissue.RemoteInfo<I>, token: string|nil, opts: S): boolean, table?

--- Specific requirements for a provider
---@class (exact) rissue.Provider
---@field name rissue.ProviderName The provider name
---@field version string
---Version code in MMmmmmppp (e.g. 3.14.0 -> 03014000 or 3014000)
---@field version_code integer
---@field get_issues rissue.provider.GetIssues<any, any, any>
---@field get_merge_requests rissue.provider.GetMergeRequests<any, any, any>
---Runs inside a coroutine (use `mod.run_co()` instead or `mod.run()`)
---The second return is where there are additional information to relay to provider info
---@field supports rissue.provider.Supports
--- Default settings of the provider. Used for merging settings at `get.issue()`
--- and other related operations.
---@field settings table<any, any>

--- The full provider information that will be used for `rissue.get_issues()`
--- and `rissue.get_merge_requests()`.
---
--- Depending on the provider, the provider may perform curl requests to the
--- servers to confirm and write their additional information required for that
--- repository.
---@class (exact) rissue.ProviderInfo<T>
---@field domain string The api endpoint
---@field name string The name of the provider
---@field owner string The owner of the repository
---@field repo string The repository name
---@field protocol "http" | "https" The curl protocol
---Additional provider information used for specific provider (e.g. github ghes)
---@field additional_info? T

--- The remote information extracted from a url.
---@class (exact) rissue.RemoteInfo
---@field curl_protocol "http" | "https" Protocol
---@field repo string The repository name
---@field owner string The owner of the repository
---@field domain string The api domain of the provider
---@field full_url string The clean url

---@class rissue.Query
--- The endpoint url appended after the api endpoint from `rissue.ProviderInfo`
---@field endpoint string
--- The query parameters. Behavior differs between each provider.
---@field param table<string, string>
