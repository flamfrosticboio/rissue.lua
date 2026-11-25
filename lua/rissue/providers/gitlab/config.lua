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

local config = {}

--- ### gitlab.config ### ---

--- Default settings for Gitlab provider
---@type rissue.Gitlab.Config
config.defaults = {
  max = 20,
  endpoints = {
    issues = {
      {
        endpoint = "projects/{repo}/issues",
        param = {
          order_by = "priority",
          sort = "asc",
          state = "opened",
        },
      },
    },
    merge_requests = {
      {
        endpoint = "projects/{repo}/merge_requests",
        param = {
          order_by = "priority",
          sort = "asc",
          state = "opened",
        },
      },
    },
  },
  per_page = 100,
  should_pass_raw = false,
  delay = 1000,
}

--- ### gitlab.config ### ---

return config
