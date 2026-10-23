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

local table_op = require("rissue.utils.table_op")

--- Log levels
---@type rissue.log.levels
local levels = {
  trace = 0,
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
  off = 5,
}

---@type table<integer, string>
local log_name = {
  [levels.trace] = "TRACE",
  [levels.debug] = "DEBUG",
  [levels.error] = "ERROR",
  [levels.info] = " INFO",
  [levels.warn] = " WARN",
  [levels.off] = " USER",
}

local ansi_colors = {
  [levels.error] = "\27[31m", -- Red
  [levels.warn] = "\27[33m", -- Yellow
  [levels.info] = "\27[34m", -- Blue
  [levels.debug] = "\27[37m", -- White
  [levels.trace] = "\27[90m", -- Gray (Bright Black)
  [levels.off] = "\27[36m", -- cyan (for user)
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

---@param ... any
---@return string
local function join(...)
  local n = select("#", ...)
  if n == 1 then
    return tostring((...))
  elseif n == 2 then
    local a, b = ...
    return tostring(a) .. " " .. tostring(b)
  end
  -- general case
  local t = { ... }
  for i = 1, n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, " ")
end

---@param opts rissue.log.new.Opts
local function new_logger(opts)
  local context_info = {
    context = opts.context,
  }

  ---@type rissue.logger
  local logger = {
    _level = 2,
    _logger = opts.logger or log_no_color,
    levels = levels,

    --- will be set later
    log = nil, ---@diagnostic disable-line: assign-type-mismatch
    info = nil, ---@diagnostic disable-line: assign-type-mismatch
    warn = nil, ---@diagnostic disable-line: assign-type-mismatch
    error = nil, ---@diagnostic disable-line: assign-type-mismatch
    trace = nil, ---@diagnostic disable-line: assign-type-mismatch
    debug = nil, ---@diagnostic disable-line: assign-type-mismatch
    level_enabled = nil, ---@diagnostic disable-line: assign-type-mismatch
    get_log_level = nil, ---@diagnostic disable-line: assign-type-mismatch
    set_log_level = nil, ---@diagnostic disable-line: assign-type-mismatch
    set_logger = nil, ---@diagnostic disable-line: assign-type-mismatch
  }

  if table_op.count(context_info) > 0 then
    logger.log = function(msg, level)
      ---@diagnostic disable-next-line: invisible
      logger._logger(msg, level, context_info)
    end
  else
    logger.log = function(msg, level)
      ---@diagnostic disable-next-line: invisible
      logger._logger(msg, level)
    end
  end

  logger.level_enabled = function(level)
    ---@diagnostic disable-next-line: invisible
    return level >= logger._level
  end
  logger.get_log_level = function()
    ---@diagnostic disable-next-line: invisible
    return logger._level
  end

  logger.set_log_level = function(level)
    if type(level) == "string" then
      local level_transformed = levels[level]
      if not level_transformed then
        error("Invalid level: " .. tostring(level), 2)
      end
      ---@diagnostic disable-next-line: invisible
      logger._level = level_transformed
    else
      ---@diagnostic disable-next-line: invisible
      logger._level = level
    end
  end

  logger.set_logger = function(_logger)
    ---@diagnostic disable-next-line: invisible
    logger._logger = _logger
  end

  for name, lvl in pairs(levels) do
    if name ~= "off" then
      logger[name] = function(...)
        if logger.level_enabled(lvl) then
          logger.log(join(...), lvl)
        end
      end
    end
  end

  return logger
end

local logger_mod = new_logger({})
---@cast logger_mod rissue.mod.logger

---@param opts? rissue.log.new.Opts
---@diagnostic disable-next-line: inject-field
logger_mod.new = function(opts)
  if not opts then
    opts = {}
  end

  if not opts.logger then
    --- logger_mod._logger may change, so we dynamically access it every time
    opts.logger = function(msg, level, info)
      ---@diagnostic disable-next-line: invisible
      logger_mod._logger(msg, level, info)
    end
  end

  return new_logger(opts)
end

---@diagnostic disable-next-line: inject-field
logger_mod.setup = function(opts)
  if opts.log_level ~= nil then
    logger_mod.set_log_level(opts.log_level)
  end

  if opts.logger ~= nil then
    logger_mod.set_logger(opts.logger)
  else
    local builtin_logger_color_enabled = false

    if opts.builtin_logger_color_enabled ~= nil then
      builtin_logger_color_enabled = opts.builtin_logger_color_enabled
    else
      local env_no_color = os.getenv("NO_COLOR")
      local env_is_term = os.getenv("TERM")
      local has_colors = env_is_term ~= nil and env_is_term ~= ""
      if env_no_color and env_no_color ~= "" or env_is_term == "dumb" then
        has_colors = false
      end
      builtin_logger_color_enabled = has_colors
    end

    if builtin_logger_color_enabled then
      logger_mod.set_logger(log_color)
    else
      logger_mod.set_logger(log_no_color)
    end
  end
end

---@type rissue.mod.logger
return logger_mod
