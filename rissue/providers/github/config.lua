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

local M = {}

--- !SETTINGS

--- Default settings
---@type rissue.Github.Settings
M.default = {
  endpoints = {
    issues = {
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open label:security,critical",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open label:blocker,P0",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open",
          sort = "interactions",
          order = "desc",
        },
      },
    },
    merge_requests = {},
  },
  parallel_fetching = 50,
  max_items = 100,
  items_per_page = 100,
  media_type = "raw",
}

--- /!SETTINGS

--- !TECHNICAL:GITHUB_GHES_RANGE

M.ghes_latest_version_code = 03022

--- Api version will be chosen by the table below
--- uses (abbb scheme) (a = major; b = minor)
---@type {[1]: integer, [2]: integer, [3]: string}[]
M.ghes_api_version_range = {
  { 03009, 03020, "2022-11-28" }, -- ghes 3.9-3.20
  { 03021, M.ghes_latest_version_code, "2026-03-10" }, -- ghes 3.21+
}

--- /!TECHNICAL:GITHUB_GHES_RANGE

--- To be concatenated with api version from `rissue.Github.SupportedApiVersions`
--- Example:
--- ```lua
--- if opts.api_version then
---     curl_headers[#curl_headers + 1] = settings.api_ver_template .. opts.api_version
--- end
--- ````
M.api_ver_template = "X-GitHub-Api-Version: "

return M
