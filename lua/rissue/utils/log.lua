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

---@class rissue.log
local M = {
  --- Current log level. Default: info
  log_level = 2,
  --- Read only variable.
  builtin_logger_color_enabled = false,
}

---@class __rissue.log._levels<T>
---@field trace T
---@field debug T
---@field info T
---@field warn T
---@field error T
---@field off T

---@class rissue.log.levels: __rissue.log._levels<integer>

---@alias rissue.log.level
---| 0 trace
---| 1 debug
---| 2 info
---| 3 warn
---| 4 error
---| 5 off

--- Log levels
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
  [M.levels.off] = " USER",
}

local ansi_colors = {
  [M.levels.error] = "\27[31m", -- Red
  [M.levels.warn] = "\27[33m", -- Yellow
  [M.levels.info] = "\27[34m", -- Blue
  [M.levels.debug] = "\27[37m", -- White
  [M.levels.trace] = "\27[90m", -- Gray (Bright Black)
  [M.levels.off] = "\27[36m", -- cyan (for user)
}

local function log_no_color(msg, level)
  local time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time())
  print(("[%s][%s]: %s"):format(time, log_name[level], msg))
end

local function log_color(msg, level)
  local time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time())
  print(
    ("[%s][%s%s\27[0m]: %s"):format(
      time,
      ansi_colors[level],
      log_name[level],
      msg
    )
  )
end

--- The default logger
M.default_logger = log_no_color

---@class rissue.log.Opts
---@field log_level? rissue.log.level
--- Replaces the current built-in logger.
---@field logger? rissue.log.logger
---Enables/Disables color on the built-in logger.
---@field builtin_logger_color_enabled? boolean

--- Runs the logger setup
---@param opts rissue.log.Opts
function M.setup(opts)
  if opts.log_level ~= nil then
    M.log_level = opts.log_level
  end

  if opts.logger ~= nil then
    M._logger = opts.logger
  else
    if opts.builtin_logger_color_enabled ~= nil then
      M.builtin_logger_color_enabled = opts.builtin_logger_color_enabled
    else
      local env_no_color = os.getenv("NO_COLOR")
      local env_is_term = os.getenv("TERM")
      local has_colors = env_is_term ~= nil and env_is_term ~= ""
      if env_no_color and env_no_color ~= "" or env_is_term == "dumb" then
        has_colors = false
      end
      M.builtin_logger_color_enabled = has_colors
    end

    if M.builtin_logger_color_enabled then
      M._logger = log_color
    else
      M._logger = log_no_color
    end
  end
end

---@alias rissue.log.logger fun(msg: string, level: integer)

--- Sets the current logger
---@param logger rissue.log.logger
function M.set_logger(logger)
  M._logger = logger
end

--- Sets the current log level
---@param level rissue.log.level
function M.set_log_level(level)
  M.log_level = level
end

M._logger = M.default_logger

--- Logs to logger.
---
--- Warning: Does not filter logging based on current log level.
---          Wrap it with `log.level_enabled()` instead.
---@param msg string
---@param level rissue.log.level
function M.log(msg, level)
  M._logger(msg, level)
end

--- Checks if the specified level is enabled
---@param level rissue.log.level
---@return boolean
function M.level_enabled(level)
  return level >= M.log_level
end

--- Print a message with log level of `log` to the logger
---@param msg string
function M.info(msg)
  if not M.level_enabled(M.levels.info) then
    return
  end
  M.log(msg, M.levels.info)
end

--- Print a message with log level of `warning` to the logger
---@param msg string
function M.warn(msg)
  if not M.level_enabled(M.levels.warn) then
    return
  end
  M.log(msg, M.levels.warn)
end

--- Print a message with log level of `error` to the logger
---@param msg string
function M.error(msg)
  if not M.level_enabled(M.levels.error) then
    return
  end
  M.log(msg, M.levels.error)
end

--- Print a message with log level of `trace` to the logger
---@param msg string
function M.trace(msg)
  if not M.level_enabled(M.levels.trace) then
    return
  end
  M.log(msg, M.levels.trace)
end

--- Print a message with log level of `debug` to the logger
---@param msg string
function M.debug(msg)
  if not M.level_enabled(M.levels.debug) then
    return
  end
  M.log(msg, M.levels.debug)
end

---@class rissue.utils.log.log_func.Opts
---@field prefix string?
---@field suffix string?

--- Returns a fixed logger function. Usually used on xpcalls.
---
--- Example:
---
--- ```lua
--- local log = require("rissue.utils.log")
---
--- local ok = xpcall(function()
---   error("something went wrong")
--- end, log.log_func("error", { prefix = "[sync] " }))
--- ```
---@param level rissue.log.level
---@param opts rissue.utils.log.log_func.Opts?
---@return fun(err: string)
function M.log_func(level, opts)
  return function(err)
    -- there might be cases where the level is changed,
    -- so we just evaluate every call instead
    if M.level_enabled(level) then
      local message = err
      if opts then
        if opts.prefix then
          message = opts.prefix .. message
        end
        if opts.suffix then
          message = message .. opts.suffix
        end
      end

      M.log(message, level)
    end
  end
end

return M
