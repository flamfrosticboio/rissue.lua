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

local version_module = {}

---@class rissue.Version
---@field major integer
---@field minor integer
---@field patch integer

--- Returns **true** when:
--- - required major version is equal to provided major version
--- - provided minor number is at least the required minor number
---
--- Otherwise, it returns false.
---@param required rissue.Version
---@param provided rissue.Version
---@return boolean
function version_module.is_compatible(required, provided)
  if required.major ~= provided.major then
    return false
  end

  return provided.minor >= required.minor
end

--- Represent a version
---@param version rissue.Version
---@return string
function version_module.represent(version)
  return string.format("%d.%d.%d", version.major, version.minor, version.patch)
end

return version_module
