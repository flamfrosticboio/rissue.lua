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

local cmd = require("rissue.utils.process")

describe("cmd", function()
  --
  -- describe("run_multiple", function()
  --   it("working (linux)", function()
  --     -- Hard return since the commands below are not applicable for windows
  --     assert(not is_windows, "Available in linux")
  --
  --     local results = cmd.run_multiple({
  --       { "sh", "-c", "echo Hello > .tmp" },
  --       { "sh", "-c", "echo World > .tmp" },
  --       -- { "sh", "-c", "notify-send $(realpath tmp)" },
  --     })
  --     for current_cmd, result in pairs(results) do
  --       assert(
  --         result.return_code == 0,
  --         current_cmd[1] .. " failed with return code " .. tostring(result.return_code)
  --       )
  --     end
  --   end)
  --
  --   it("at least one fails correctly (linux)", function()
  --     if is_windows then
  --       return
  --     end
  --
  --     local results = cmd.run_multiple({
  --       { "echo", "True" },
  --       { "sh", "-c", "exit -1" },
  --       { "echo", "should fail" },
  --     })
  --
  --     local function check()
  --       for _, result in pairs(results) do
  --         if result.return_code ~= 0 then
  --           return
  --         end
  --       end
  --       assert(false, "all returned correctly without issues (should not happen)")
  --     end
  --     check()
  --   end)
  --
  --   it("disable on unknown binary", function()
  --     local ok = pcall(function()
  --       cmd.run_multiple({
  --         { "echo", "ok" }, -- will run normally
  --         { "someRandomBinary29924", "--flag" }, -- will disable
  --         -- will disable also if you don't have notify-send (especially windows)
  --         { "notify-send", "should not be running" },
  --       })
  --     end)
  --     assert.is_false(ok)
  --   end)
  --
  --   it("multiple outputs are correct", function()
  --     local first = { "echo", "jello" }
  --     local second = { "echo", "wello" }
  --     local result = cmd.run_multiple({ first, second })
  --     assert.same({
  --       [first] = {
  --         return_code = 0,
  --         stderr = { contents = "" },
  --         stdout = { contents = "jello\n" },
  --       },
  --       [second] = {
  --         return_code = 0,
  --         stderr = { contents = "" },
  --         stdout = { contents = "wello\n" },
  --       },
  --     } --[[@as rissue.utils.RunMultipleResults]], result)
  --   end)
  -- end)

  describe("spawn", function()
    it("stdout ok", function()
      local contents = nil
      local co
      co = coroutine.create(
        ---@async
        function()
          local p, spawn_err =
            cmd.spawn({ cmd = "echo", args = { "Hello World" } })
          assert(p ~= nil, spawn_err)
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          contents = p:get_stdout()
        end
      )

      local ok, err = coroutine.resume(co)
      assert(ok == true, err)

      require("luv").run()
      assert.equal("Hello World\n", contents)
    end)

    it("stderr ok (with sh) #unix", function()
      local contents = nil
      local co
      co = coroutine.create(
        ---@async
        function()
          local p, spawn_err =
            cmd.spawn({ cmd = "sh", args = { "-c", "echo Hello World 1>&2" } })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          contents = p:get_stderr()
        end
      )

      local ok, err = coroutine.resume(co)
      assert(ok == true, err)

      require("luv").run()
      assert.equal("Hello World\n", contents)
    end)

    it("return code ok", function()
      local contents = nil
      local p, spawn_err =
        cmd.spawn({ cmd = "sh", args = { "-c", "echo Hello World 1>&2" } })
      assert(p ~= nil, spawn_err)
      local co
      co = coroutine.create(
        ---@async
        function()
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          contents = p:get_code()
        end
      )

      local ok, err = coroutine.resume(co)
      assert(ok == true, err)

      require("luv").run()
      assert.equal(0, contents)
    end)

    it("cwd is correct #unix", function()
      local contents = nil
      local co
      co = coroutine.create(
        ---@async
        function()
          local p, spawn_err =
            cmd.spawn({ cmd = "pwd", args = {}, cwd = "/tmp" })
          assert(p ~= nil, spawn_err)
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          contents = p:get_stdout()
        end
      )
      coroutine.resume(co)
      require("luv").run()
      assert.equal("/tmp\n", contents)
    end)

    it("env tableform is correct #unix #cmd:printenv", function()
      local contents = nil
      local code = -1
      local stderr = ""
      local co
      co = coroutine.create(
        ---@async
        function()
          local p, spawn_err = cmd.spawn({
            cmd = "printenv",
            args = { "HELLO" },
            env = { HELLO = "YES" },
          })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          code = p:get_code()
          contents = p:get_stdout()
          stderr = p:get_stderr()
        end
      )
      coroutine.resume(co)
      require("luv").run()
      assert(
        code == 0,
        "Program exited with code "
          .. tostring(code)
          .. (stderr ~= "" and (": " .. stderr) or "")
      )
      assert.equal("YES\n", contents)
    end)

    it("env listform is correct #unix #cmd:printenv", function()
      local contents = nil
      local code = -1
      local stderr = ""
      local co
      co = coroutine.create(
        ---@async
        function()
          local p, spawn_err = cmd.spawn({
            cmd = "printenv",
            args = { "HELLO" },
            env = { "HELLO=YES" },
          })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            coroutine.resume(co)
          end)
          p:run()
          coroutine.yield()
          code = p:get_code()
          contents = p:get_stdout()
          stderr = p:get_stderr()
        end
      )
      local ok, err = coroutine.resume(co)
      assert(ok == true, err)
      require("luv").run()
      assert(
        code == 0,
        "Program exited with code "
          .. tostring(code)
          .. (stderr ~= "" and (": " .. stderr) or "")
      )
      assert.equal("YES\n", contents)
    end)

    it("disable on unknown binary", function()
      local p, spawn_err =
        cmd.spawn({ cmd = "someRandomBinary29924", args = {} })
      assert(p ~= nil, spawn_err)
      ---@cast p rissue.utils.Process
      local run_ok, msg = pcall(function()
        p:run()
      end)
      assert.equal(false, run_ok)
      assert(
        msg and msg:match("Failed to spawn process: someRandomBinary29924"),
        "Expected message to have: 'Failed to spawn process: someRandomBinary29924'"
      )
    end)
  end)

  describe("run_co", function()
    it("outputs are correct", function()
      local result ---@type rissue.utils.CmdResult?
      local co = coroutine.create(function()
        local err
        result, err = cmd.run_co({
          cmd = "sh",
          args = { "-c", 'echo "stdout line"; echo "stderr line" >&2; exit 0' },
        })
        assert(result ~= nil, err)
      end)
      local ok, err = coroutine.resume(co)
      assert(ok == true, err)
      require("luv").run()
      assert.same(
        { return_code = 0, stdout = "stdout line\n", stderr = "stderr line\n" } --[[@as rissue.utils.CmdResult]],
        result
      )
    end)
  end)
end)
