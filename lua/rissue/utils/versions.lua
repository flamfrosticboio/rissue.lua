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

local ver = {}

--- The version code is returned as MMMMmmmmpppp where: M - major; m - minor; p - patch
---
--- ## Bumping rules:
---
--- Major version **should only be bumped** when the specifications contains breaking
--- changes.
---
--- Minor versions **should only be bumped** when the specifications contains new
--- features but does not break any current changes.
---
--- The patch version is bumped when there are **changes within the provider itself**
---@param major integer
---@param minor integer
---@param patch integer
---@return string version_string
---@return integer version_code
function ver.version(major, minor, patch)
  assert(
    major >= 0
      and minor >= 0
      and patch >= 0
      and major <= 9999
      and minor <= 9999
      and patch <= 9999,
    "version fields must be between 0 and 9999"
  )
  local code = major * 100000000 + minor * 10000 + patch
  local str_repr = string.format("%d.%d.%d", major, minor, patch)
  return str_repr, code
end

return ver
