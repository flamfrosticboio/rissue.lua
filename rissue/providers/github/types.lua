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

--- !TYPES

---@alias rissue.Github.SupportedApiVersions "2026-03-10" | "2022-11-28"

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.SupportedApiVersions?

---@class rissue.Github.opts.Endpoints
---@field issues rissue.Query[]
---@field merge_requests rissue.Query[]

---@class rissue.Github.Settings
--- Required field on param in each query: `q`
--- `q` can be used as template string.
---
--- Supported template strings for `q`:
--- - `{owner}` - Repository owner
--- - `{repo}` - Repository name
---
--- See default settings for examples.
---@field endpoints rissue.Github.opts.Endpoints
--- Override the api version to be used.
--- Most commonly used when doing requests like `get.issues()` or `get.merge_requests()`
---
--- Setting it to false removes the api_version header to be sent to the server.
---
--- **Warning: NOT RECOMMENDED TO BE SET ON USER SETTINGS**
---@field api_version? rissue.Github.SupportedApiVersions | false
--- Limits how many items will be fetched and rendered.
--- Note: This does not guarantee the output size of the result to be exactly `max_items`
---       and may have more items than requested
---@field max_items integer
--- Defines how many items are fetched per page when performing pagination requests in github. Limit=100
---@field items_per_page integer
--- Settings on the parallel fetching.
--- When this option is `true`, it will be always enabled
--- When this option is `false`, it will be always disabled (fallback to fetching sequentially).
--- When this option is an integer, it will act as a threshold comparing `max_items` ``(max_items >= threshold)``
---@field parallel_fetching boolean | integer

--- Partial version of rissue.Github.Settings
---@class (partial) rissue.Github.Opts: rissue.Github.Settings

--- /!TYPES
