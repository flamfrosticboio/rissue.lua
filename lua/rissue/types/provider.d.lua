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

---@meta

---@alias rissue.ProviderName string The name of provider (e.g. "github", "gitlab", "forgejo", "gitea")

---@class (exact) rissue.provider_spec.called.Opts<T, S>
---@field settings S | table
---@field request? T | table

--- Second return is for errors
---@alias rissue.provider_info.GetIssues<T, S, I>
---| fun(info: rissue.ProviderInfo<I>, token: string|nil, opts: rissue.provider_spec.called.Opts<T, S>): rissue.issue[]?, string?

--- Second return is for errors
---@alias rissue.provider_info.GetMergeRequests<T, S, I>
---| fun(info: rissue.ProviderInfo<I>, token: string|nil, opts: rissue.provider_spec.called.Opts<T, S>): rissue.pr[]?, string?

---@alias rissue.provider_info.Supports<T, S, I>
---| fun(info: rissue.RemoteInfo<I>, token: string|nil, opts: rissue.provider_spec.called.Opts<T, S>): boolean, table?

---@class (exact) rissue.Provider
---@field provider_name  string
---@field version string
---Version code in MMmmmmppp (e.g. 3.14.0 -> 03014000 or 3014000)
---@field version_code integer
---@field get_issues rissue.provider_info.GetIssues<any, any, any>
---@field get_merge_requests rissue.provider_info.GetMergeRequests<any, any, any>
---Runs inside a coroutine (use `mod.run_co()` instead or `mod.run()`)
---The second return is where there are additional information to relay to provider info
---@field supports rissue.provider_info.Supports

---@class rissue.ProviderInfo<T>
---@field domain string
---@field name string
---@field owner string
---@field repo string
---@field protocol "http" | "https"
---@field additional_info? T

---@class (exact) rissue.RemoteInfo
---@field curl_protocol "http" | "https"
---@field repo string
---@field owner string
---@field domain string
---@field full_url string A whitespace stripped version of url

---@class rissue.Query
---@field endpoint string
---@field param table<string, string>
