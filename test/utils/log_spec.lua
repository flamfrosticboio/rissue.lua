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

describe("log", function()
  local log = require("rissue.utils.log")
  local original_log = 0
  lazy_setup(function()
    original_log = log.log_level
  end)
  it("Colors ok #interactive_only", function()
    log.setup({
      builtin_logger_color_enabled = true,
      log_level = log.levels.trace,
    })

    log.warn("This is a warning")
    log.error("This is an error")
    log.info("This is an info")
    log.debug("This is a debug")
    log.trace("This is a trace")
  end)

  it("No colors ok #interactive_only", function()
    log.setup({
      builtin_logger_color_enabled = false,
      log_level = log.levels.trace,
    })

    log.warn("This is a warning")
    log.error("This is an error")
    log.info("This is an info")
    log.debug("This is a debug")
    log.trace("This is a trace")
  end)

  lazy_teardown(function()
    log.setup({
      log_level = original_log,
    })
  end)
end)
