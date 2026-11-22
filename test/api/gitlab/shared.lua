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

local log = require("rissue.utils.log")

local shared = {}

--- Ignore tests due to incompatibility
---@param passed string
---@param names string[]
---@param fn fun()
function shared.ignore_on(names, passed, fn)
  for _, name in ipairs(names) do
    if name == passed then
      log.warn(
        'Some test cases are ignored for "'
          .. passed
          .. '" due to incompatibility'
      )
      return
    end
  end

  fn()
end

return shared
