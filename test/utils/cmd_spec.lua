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

describe("cmd", function()
  local cmd = require("rissue.utils.cmd")
  local is_windows = package.config:sub(1, 1) == "\\"

  describe("run_multiple", function()
    it("working (linux)", function()
      -- Hard return since the commands below are not applicable for windows
      if is_windows then
        return
      end

      assert.is_true(cmd.run_multiple({
        { "sh", "-c", "echo Hello > .tmp" },
        { "sh", "-c", "echo World > .tmp" },
        -- { "sh", "-c", "notify-send $(realpath tmp)" },
      }))
    end)

    it("at least one correctly fails (linux)", function()
      if is_windows then
        return
      end
      assert.is_false(cmd.run_multiple({
        { "echo", "True" },
        { "sh", "-c", "exit -1" }, -- failing point condition
        { "echo", "should fail" },
      }))
    end)
  end)
end)
