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
  describe("#interactive_only", function()
    local original_log = 0
    local original_logger = nil
    lazy_setup(function()
      original_log = log.get_log_level()
      original_logger = log._logger ---@diagnostic disable-line: invisible
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
      log.info("This is printed", "with a lot", "of", "arguments")
      log.warn("This is printed", "with a lot", "of", "arguments")
      log.error("This is printed", "with a lot", "of", "arguments")
      log.debug("This is printed", "with a lot", "of", "arguments")
      log.trace("This is printed", "with a lot", "of", "arguments")
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
      log.info("This is printed", "with a lot", "of", "arguments")
      log.warn("This is printed", "with a lot", "of", "arguments")
      log.error("This is printed", "with a lot", "of", "arguments")
      log.debug("This is printed", "with a lot", "of", "arguments")
      log.trace("This is printed", "with a lot", "of", "arguments")
    end)

    it("Levels enabled ok", function()
      log.setup({
        builtin_logger_color_enabled = false,
        log_level = log.levels.error,
      })

      assert.is_false(log.level_enabled(log.levels.warn))
      assert.is_true(log.level_enabled(log.levels.error))
    end)

    it("Get and set level ok", function()
      log.setup({
        builtin_logger_color_enabled = false,
        log_level = log.levels.off,
      })

      assert.same(log.get_log_level(), log.levels.off)

      log.set_log_level(log.levels.trace)

      assert.same(log.get_log_level(), log.levels.trace)
    end)

    it("Set logger ok", function()
      local s = spy.new(function() end)
      log.setup({
        builtin_logger_color_enabled = false,
        log_level = log.levels.trace,
        logger = s --[[@as fun()]],
      })

      log.info("Hello world")

      assert.spy(s).called_with("Hello world", log.levels.info)
    end)

    it("New logger ok", function()
      local s = spy.new(function() end)
      local logger = log.new({
        context = "My logger",
        logger = s --[[@as fun()]],
      })

      logger.info("Hello world")

      assert
        .spy(s)
        .called_with("Hello world", log.levels.info, match.same({ context = "My logger" }))
    end)

    lazy_teardown(function()
      log.set_log_level(original_log)
      if original_logger then
        log.set_logger(original_logger)
      end
    end)
  end)
end)
