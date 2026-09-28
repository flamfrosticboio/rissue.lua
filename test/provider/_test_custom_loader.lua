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

local viewer = {}

---@type rissue.Provider
return {
  name = "custom",
  version = "0.1",
  version_code = 1000,
  supports = function(info, token, opts)
    viewer.supports = { info, token, opts }
    return true
  end,
  get_merge_requests = function(info, token, opts)
    viewer.get_merge_requests = { info, token, opts }
    return {}
  end,
  get_issues = function(info, token, opts)
    viewer.get_issues = { info, token, opts }
    return {}
  end,
  settings = {
    my_setting = false,
  },
  viewer = viewer,
}
