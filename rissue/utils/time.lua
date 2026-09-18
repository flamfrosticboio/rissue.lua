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

--- Converts a iso utc into unix timestamp
--- Notes:
--- - To view timestamp as local time, just use `os.date("*t", ts)`
---   Alternatively, to view it UTC, just use `os.date("!*t", ts)`
---@param iso string
function M.iso_to_timestamp_utc(iso)
  local year, month, day, hour, min, sec =
    iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")

  if not year then
    error("invalid ISO 8601 timestamp: " .. tostring(iso))
  end

  local t = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
  }

  local now = os.time()
  local diff = os.difftime(
    os.time(os.date("*t", now) --[[@as osdate]]),
    os.time(os.date("!*t", now) --[[@as osdate]])
  )

  return os.time(t) + diff
end

return M
