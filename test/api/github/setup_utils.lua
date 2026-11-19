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

local M = {}

---@generic T
---@param min integer
---@param max integer
---@param builder fun(i: integer): T
---@param filter? fun(i: integer): boolean
---@return T[]
local function populate_range(min, max, builder, filter)
  local range = {}
  if min > max then
    return range
  end
  for i = min, max do
    if not filter or filter(i) then
      range[#range + 1] = builder(i)
    end
  end
  return range
end

---@param i integer
---@return string
local function constructor(i)
  return "3." .. tostring(i)
end

local TEST_ALL = os.getenv("TEST_ALL") == "true"

local ghes_min = 0
local ghes_max = 22
local recent_count = 3 -- how many versions before the latest to also test

--- Whether a minor version is tested: everything with TEST_ALL,
--- otherwise 3.0 plus the latest and the `recent_count` before it
---@param i integer
---@return boolean
local function is_tested(i)
  if TEST_ALL then
    return true
  end
  return i == 0 or i >= ghes_max - recent_count
end

--- List of ghes versions to test (not used on testing)
M.ghes_versions = populate_range(ghes_min, ghes_max, constructor, is_tested)

local ghes_2022_min = math.max(9, ghes_min)
local ghes_2022_max = ghes_max
--- GHES Versions to test against
M.ghes_2022_versions =
  populate_range(ghes_2022_min, ghes_2022_max, constructor, is_tested)

local ghes_2026_min = math.max(21, ghes_min)
local ghes_2026_max = ghes_max
--- Versions with 2026 api variant
M.ghes_2026_versions =
  populate_range(ghes_2026_min, ghes_2026_max, constructor, is_tested)

local ghes_non_dated_min = ghes_min
local ghes_non_dated_max = 8 -- last version to not have a versioned api
--- Versions without any specific api date
M.ghes_non_dated_versions =
  populate_range(ghes_non_dated_min, ghes_non_dated_max, constructor, is_tested)

M.ghes_code_mapped = {}
for i = ghes_min, ghes_max do
  if is_tested(i) then
    M.ghes_code_mapped["3." .. i] = 3000 + i
  end
end

--- For downloading specs on tests
--- spec is still updating on ghes 3.17
local ghes_tests_updating_min = math.max(17, ghes_min)
local ghes_tests_updating_max = ghes_max
M.ghes_versions_tests_updating = populate_range(
  ghes_tests_updating_min,
  ghes_tests_updating_max,
  constructor,
  is_tested
)

local ghes_tests_updating_2022_min =
  math.max(ghes_tests_updating_min, ghes_2022_min)
local ghes_tests_updating_2022_max =
  math.min(ghes_tests_updating_max, ghes_2022_max)
--- Updating versions that have the 2022 api variant
M.ghes_2022_versions_tests_updating = populate_range(
  ghes_tests_updating_2022_min,
  ghes_tests_updating_2022_max,
  constructor,
  is_tested
)

local ghes_tests_updating_2026_min =
  math.max(ghes_tests_updating_min, ghes_2026_min)
local ghes_tests_updating_2026_max =
  math.min(ghes_tests_updating_max, ghes_2026_max)
--- Updating versions that have the 2026 api variant
M.ghes_2026_versions_tests_updating = populate_range(
  ghes_tests_updating_2026_min,
  ghes_tests_updating_2026_max,
  constructor,
  is_tested
)

--- For using local specs from .assets/
--- ghes 3.16 is the last spec update support
local ghes_tests_local_min = 0
local ghes_tests_local_max = 16
M.ghes_versions_tests_local = populate_range(
  ghes_tests_local_min,
  ghes_tests_local_max,
  constructor,
  is_tested
)

local ghes_tests_local_2022_min = math.max(ghes_tests_local_min, ghes_2022_min)
local ghes_tests_local_2022_max = math.min(ghes_tests_local_max, ghes_2022_max)
--- Local spec versions that have the 2022 api variant
M.ghes_2022_versions_tests_local = populate_range(
  ghes_tests_local_2022_min,
  ghes_tests_local_2022_max,
  constructor,
  is_tested
)

local ghes_tests_local_non_dated_min =
  math.max(ghes_tests_local_min, ghes_non_dated_min)
local ghes_tests_local_non_dated_max =
  math.min(ghes_tests_local_max, ghes_non_dated_max)
--- Local spec versions without any specific api date
M.ghes_non_dated_versions_tests_local = populate_range(
  ghes_tests_local_non_dated_min,
  ghes_tests_local_non_dated_max,
  constructor,
  is_tested
)

return M
