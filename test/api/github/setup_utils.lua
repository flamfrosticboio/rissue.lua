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

---@generic T
---@param min integer
---@param max integer
---@param builder fun(i: integer): T
---@return T[]
local function populate_range(min, max, builder)
  local range = {}
  if min > max then
    return range
  end
  for i = min, max do
    range[#range + 1] = builder(i)
  end
  return range
end

---@param i integer
---@return string
local function constructor(i)
  return "3." .. tostring(i)
end

local ghes_min = os.getenv("TEST_ALL") and 0 or 16
local ghes_max = 22
M.ghes_versions = populate_range(ghes_min, ghes_max, constructor)

local ghes_2022_min = 9
local ghes_2022_max = ghes_max
--- GHES Versions to test against
M.ghes_2022_versions = populate_range(ghes_2022_min, ghes_2022_max, constructor)

local ghes_2026_min = 21
local ghes_2026_max = ghes_max
--- Versions with 2026 api variant
M.ghes_2026_versions = populate_range(ghes_2026_min, ghes_2026_max, constructor)

local ghes_non_dated_min = ghes_min
local ghes_non_dated_max = 8 -- last version to not have a versioned api
--- Versions without any specific api date
M.ghes_non_dated_versions =
  populate_range(ghes_non_dated_min, ghes_non_dated_max, constructor)

return M
