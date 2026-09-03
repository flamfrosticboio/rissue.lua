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

---@class rissue.log
local M = {
  log_level = 2, -- info
}

---@alias rissue.log.logger fun(msg: string, level: integer)

---@param logger rissue.log.logger
function M.set_logger(logger)
  M._logger = logger
end

function M.set_log_level(level)
  M.log_level = level
end

M._logger = function(msg)
  print(msg)
end

---@class __rissue.log._levels<T>
---@field trace T
---@field debug T
---@field info T
---@field warn T
---@field error T
---@field off T

---@class rissue.log.levels: __rissue.log._levels<integer>

---@type rissue.log.levels
M.levels = {
  trace = 0,
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
  off = 5,
}

---@type table<integer, string>
local log_name = {
  [M.levels.trace] = "TRACE",
  [M.levels.debug] = "DEBUG",
  [M.levels.error] = "ERROR",
  [M.levels.info] = " INFO",
  [M.levels.warn] = " WARN",
  [M.levels.off] = "",
}

---@param msg string
---@param level 0 | 1 | 2 | 3 | 4 | 5
function M.log(msg, level)
  if level < M.log_level then
    return
  end
  local time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time())
  M._logger(("[%s][%s]: %s"):format(time, log_name[level], msg), level)
end

---@param level 0 | 1 | 2 | 3 | 4 | 5
function M.level_enabled(level)
  return level >= M.log_level
end

---@param msg string
function M.info(msg)
  M.log(msg, M.levels.info)
end

---@param msg string
function M.warn(msg)
  M.log(msg, M.levels.warn)
end

---@param msg string
function M.error(msg)
  M.log(msg, M.levels.error)
end

---@param msg string
function M.trace(msg)
  M.log(msg, M.levels.trace)
end

---@param msg string
function M.debug(msg)
  M.log(msg, M.levels.debug)
end

return M
