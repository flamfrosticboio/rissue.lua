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

---@class rissue.mod.Time
local M = {}

--- Days since 1970-01-01 for a proleptic Gregorian date.
--- (Howard Hinnant's days_from_civil algorithm.)
---@param year integer
---@param month integer
---@param day integer
---@return integer
local function days_from_civil(year, month, day)
  if month <= 2 then
    year = year - 1
  end
  local era = math.floor(year / 400)
  local yoe = year - era * 400
  local mp = (month + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + day - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

--- Parses a timezone suffix into seconds east of UTC.
--- Accepts: "" (treated as UTC), "Z", "z", "+HH:MM", "+HHMM", "+HH"
---@param zone string
---@return integer? seconds
local function parse_zone(zone)
  if zone == "" or zone == "Z" or zone == "z" then
    return 0
  end

  local sign, hh, mm = zone:match("^([+-])(%d%d):?(%d%d)$")
  if not sign then
    sign, hh = zone:match("^([+-])(%d%d)$")
    mm = "00"
  end
  if not sign then
    return nil
  end

  hh, mm = tonumber(hh), tonumber(mm)
  if hh > 23 or mm > 59 then
    return nil
  end

  local seconds = hh * 3600 + mm * 60
  return sign == "-" and -seconds or seconds
end

--- Splits an ISO string into numeric parts plus the zone offset.
--- Accepts "T", "t" or a space between date and time, and optional
--- fractional seconds (".243" or ",243").
---@param iso string
---@return table? parts
local function parse(iso)
  local date, time = iso:match("^(%d%d%d%d%-%d%d%-%d%d)[Tt ](.+)$")
  if not date then
    return nil
  end

  local year, month, day = date:match("^(%d+)-(%d+)-(%d+)$")
  local hour, min, sec, rest = time:match("^(%d%d):(%d%d):(%d%d)(.*)$")
  if not hour then
    return nil
  end

  -- Drop fractional seconds
  rest = (rest:gsub("^[%.,]%d+", ""))

  local offset = parse_zone(rest)
  if not offset then
    return nil
  end

  local parts = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    offset = offset,
  }

  -- Basic range checks (60 allowed for leap seconds)
  if
    parts.month < 1
    or parts.month > 12
    or parts.day < 1
    or parts.day > 31
    or parts.hour > 23
    or parts.min > 59
    or parts.sec > 60
  then
    return nil
  end

  return parts
end

--- Converts an ISO 8601 timestamp into a unix timestamp (seconds, UTC).
---
--- Notes: To view timestamp as local time, use `os.date("*t", ts)`
--- Alternatively, to view it UTC, use `os.date("!*t", ts)`
---@param iso string
---@return integer
function M.iso_to_timestamp_utc(iso)
  local p = parse(iso)
  if not p then
    error("invalid ISO 8601 timestamp: " .. tostring(iso))
  end

  local days = days_from_civil(p.year, p.month, p.day)
  return days * 86400 + p.hour * 3600 + p.min * 60 + p.sec - p.offset
end

return M
