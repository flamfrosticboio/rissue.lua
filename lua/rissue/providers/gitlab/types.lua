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

---@class rissue.Gitlab.AdditionalInfo
---@field version string
--- Checks if the gitlab instance uses an enterprise edition.
---
--- Note: This does not mean your account uses enterprise features
---     (e.g. gitlab.com runs as enterprise but your account is free).
---@field is_enterprise boolean

---@class rissue.Gitlab.Endpoints
---@field issues rissue.Query[]
---@field merge_requests rissue.Query[]

--- Partial version of rissue.Gitlab.Config.
---
--- This class is mainly used to type an option.
---
--- Example:
--- ```lua
--- rissue.setup({
---     provider_options = {
---         ---@type rissue.Gitlab.Opts
---         gitlab = { ... }
---     }
--- })
--- ```
---@class (partial) rissue.Gitlab.Opts: rissue.Gitlab.Config

--- The exact config for gitlab provider.
---
--- Note: To use it as config options, use `rissue.Gitlab.Opts` instead
---@class rissue.Gitlab.Config
---@field max integer Max number of items to be fetched
---@field endpoints rissue.Gitlab.Endpoints Config for fetch endpoints
--- Max number of items fetched on each per page
---
--- Recommended to be set to `100`
---@field per_page integer
--- Option to pass raw response to issues and merge requests
---@field should_pass_raw boolean
--- Delay between each fetch in milliseconds.
---
--- Default: 1000 (1 second)
---@field delay integer

---@class rissue.Gitlab.UserBasic
---@field username string?
---@field name string?
---@field web_url string?
---@field public_email string?

---@class rissue.Gitlab.SharedResponse
---@field description string?
---@field title string?
---@field web_url string?
---@field created_at string?
---@field project_id integer? Not available on older git providers
---@field labels string[]
---@field author rissue.Gitlab.UserBasic
---@field iid integer
---@field id integer

---@class rissue.Gitlab.IssueResponse: rissue.Gitlab.SharedResponse
---@field state "opened" | "closed"
---@field _links ({ self: string? })?

---@class rissue.Gitlab.MergeRequestResponse: rissue.Gitlab.SharedResponse
---@field state "opened" | "closed" | "locked" | "merged"
