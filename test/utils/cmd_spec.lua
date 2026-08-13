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

      local results = cmd.run_multiple({
        { "sh", "-c", "echo Hello > .tmp" },
        { "sh", "-c", "echo World > .tmp" },
        -- { "sh", "-c", "notify-send $(realpath tmp)" },
      })
      for current_cmd, result in pairs(results) do
        assert(
          result.return_code == 0,
          current_cmd[1] .. " failed with return code " .. tostring(result.return_code)
        )
      end
    end)

    it("at least one fails correctly (linux)", function()
      if is_windows then
        return
      end

      local results = cmd.run_multiple({
        { "echo", "True" },
        { "sh", "-c", "exit -1" },
        { "echo", "should fail" },
      })

      local function check()
        for _, result in pairs(results) do
          if result.return_code ~= 0 then
            return
          end
        end
        error("all returned correctly without issues (should not happen)")
      end
      check()
    end)

    it("error on unknown binary", function()
      local ok = pcall(function()
        cmd.run_multiple({
          { "echo", "ok" }, -- will run normally
          { "someRandomBinary29924", "--flag" }, -- will error
          -- will error also if you don't have notify-send (especially windows)
          { "notify-send", "should not be running" },
        })
      end)
      assert.is_false(ok)
    end)

    it("multiple outputs are correct", function()
      local first = { "echo", "jello" }
      local second = { "echo", "wello" }
      local result = cmd.run_multiple({ first, second })
      assert.same({
        [first] = {
          return_code = 0,
          stderr = { contents = "" },
          stdout = { contents = "jello\n" },
        },
        [second] = {
          return_code = 0,
          stderr = { contents = "" },
          stdout = { contents = "wello\n" },
        },
      } --[[@as rissue.utils.RunMultipleResults]], result)
    end)
  end)

  describe("run", function()
    it("stdout outputs correctly", function()
      local ok, result = cmd.run({ "echo", "true" })
      assert(ok == true, result)
      assert.same({
        return_code = 0,
        stdout = { contents = "true\n" },
        stderr = { contents = "" },
      } --[[@as rissue.utils.CmdResult]], result)
    end)

    it("stderr outputs correctly (linux)", function()
      local ok, result = cmd.run({ "sh", "-c", "echo false 1>&2" })
      assert(ok == true, result)
      assert.same({
        return_code = 0,
        stdout = { contents = "" },
        stderr = { contents = "false\n" },
      } --[[@as rissue.utils.CmdResult]], result)
    end)

    it("switches to M.spawn inside coroutine correctly", function()
      local ok, result
      coroutine.wrap(function()
        ok, result = cmd.run({ "echo", "true" })
      end)()
      require("luv").run()
      assert(ok == true, result)
      assert.same({
        return_code = 0,
        stderr = { contents = "" },
        stdout = { contents = "true\n" },
      } --[[@as rissue.utils.CmdResult]], result)
    end)

    it(
      "switches to M.spawn inside coroutine correctly with error (lua5.1 only)",
      function()
        ---@diagnostic disable-next-line: undefined-global
        if not (_VERSION == "Lua 5.1" and not jit) then
          -- just ignore if not running in pure lua5.1
          return
        end
        local ok = pcall(function()
          local okk, r
          coroutine.wrap(function()
            okk, r = cmd.run({ "echo", "true" })
          end)()
          require("luv").run()
          assert(okk == true, r)
          assert.same({
            return_code = 0,
            stderr = { contents = "" },
            stdout = { contents = "" },
          } --[[@as rissue.utils.CmdResult]], r)
        end)

        assert.is_false(ok)
      end
    )

    it("cwd is correct (linux)", function()
      if is_windows then
        -- not applicable
        return
      end

      local ok, result = cmd.run({ "pwd" }, "/tmp")
      assert(ok == true, result)
      assert.same({
        return_code = 0,
        stderr = { contents = "" },
        stdout = { contents = "/tmp\n" },
      } --[[@as rissue.utils.CmdResult]], result)
    end)

    it("error on unknown binary", function()
      local x = { "someRandomBinary29924", "--flag" }
      local ok = cmd.run(x)
      assert.is_false(ok)
    end)
  end)
end)
