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

---@meta

---@module "rissue.types.pr.d"
---@module "rissue.types.issue.d"

---@alias rissue.ProviderName string The name of provider (e.g. "github", "gitlab", "forgejo", "gitea")

--- Specific requirements for a provider
---@class rissue.Provider
---@field name rissue.ProviderName The provider name.
--- Current version of the provider.
---
--- **Bumping rules:**
---
--- - Major version **should only be bumped** when the specifications contains breaking
--- changes.
--- - Minor versions **should only be bumped** when the specifications contains new
--- features but does not break any current changes.
--- - The patch version is bumped when there are **changes within the provider itself
--- without affecting the results**
---@field version { major: integer, minor: integer, patch: integer }
--- Default settings of the provider. Used for merging settings at `get.issue()`
--- and other related operations.
---@field settings table<string, any>
--- Gets issues using the provided `info`.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---@field get_issues rissue.provider.GetIssues<any, any>
--- Gets merge requests using the provided `info`.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---@field get_merge_requests rissue.provider.GetMergeRequests<any, any>
--- Checks if the remote information given is supported by the provider.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---@field supports rissue.provider.Supports<any, any>

---@class rissue.provider.d
local provider = {}

--- Gets issues using the provided `info`.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---
---@see rissue.provider.d
---@alias rissue.provider.GetIssues<I, S>
---| async fun(async: rissue.Async, info: rissue.ProviderInfo<I>, token: string|nil, opts: S, cb: fun(issue: rissue.Issue)): string?

--- Gets issues using the provided `info`.
---
--- Note: `cb` is used to construct issues. This is useful when showing partial results
--- while fetching more items (e.g. snacks picker).
---@generic I, S: table
---@async
---@param async rissue.Async Async handler
---@param info rissue.RemoteInfo<I> Information on the remote url
---@param token string|nil Auth token
---@param opts S Provider options
---@param cb fun(issue: rissue.Issue) Builder function
---@return string? err_msg error message
function provider.get_issues(async, info, token, opts, cb) end

--- Gets merge requests using the provided `info`.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---
---@see rissue.provider.d
---@alias rissue.provider.GetMergeRequests<I, S>
---| async fun(async: rissue.Async, info: rissue.ProviderInfo<I>, token: string|nil, opts: S, cb: fun(pr: rissue.MergeRequest)): string?

--- Gets merge requests using the provided `info`.
---
--- Note: `cb` is used to construct issues. This is useful when showing partial results
--- while fetching more items (e.g. snacks picker).
---@generic I, S: table
---@async
---@param async rissue.Async Async handler
---@param info rissue.RemoteInfo<I> Information on the remote url
---@param token string|nil Auth token
---@param opts S Provider options
---@param cb fun(issue: rissue.Issue) Builder function
---@return string? err_msg error message
function provider.get_merge_requests(async, info, token, opts, cb) end

--- Checks if the remote information given is supported by the provider.
---
--- Read more from [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)
---
---@see rissue.provider.d
---@alias rissue.provider.Supports<I, S>
---| async fun(async: rissue.Async, info: rissue.RemoteInfo<I>, token: string|nil, opts: S): boolean, table?

--- Checks if the remote information given is supported by the provider.
---
--- In some cases, the provider will try to query the server to look for clues such as
--- querying `/meta` to check ghes version for github.
---
--- The second return `additional_info` is used to give additional information about
--- the provider such as ghes version (github enterprise server) in github.
---@generic I, S: table
---@async
---@param async rissue.Async
---@param info rissue.RemoteInfo<I>
---@param token string|nil
---@param opts S
---@return boolean is_supported Status check
---@return table? additional_info Additional information about the provider.
function provider.supports(async, info, token, opts) end

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
