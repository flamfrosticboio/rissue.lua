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

---@alias rissue.provider string A type of provider (e.g. "github", "gitlab", "forgejo", "gitea")

---@class (exact) rissue.provider_spec
---@field map_into_issue fun(fetch_result: any): rissue.issue[]
---@field map_into_pr    fun(fetch_result: any): rissue.pr[]
---@field provider_name  string
---@field supports       fun(info: rissue.RemoteInfo, cmd: rissue.utils.CmdModule, token: string?): boolean Async function

---@class rissue.provider_spec.extract
---@field owner string
---@field repo  string

---@class rissue.ProviderInfo
---@field domain   string
---@field name     string
---@field owner    string
---@field repo     string
---@field protocol "http" | "https"

---@class (exact) rissue.RemoteInfo
---@field curl_protocol "http" | "https"
---@field repo string
---@field owner string
---@field domain string
---@field full_url string A whitespace stripped version of url
