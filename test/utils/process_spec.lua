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

---@diagnostic disable: redundant-parameter

local async = require("rissue.utils.async")
local async_test_backend = require("async_test_backend")
local process = require("rissue.utils.process")

---@param cb async fun(a: rissue.Async)
local function run_blocking(cb)
  local done = false

  async_test_backend.reset()

  async.run(
    async_test_backend,
    ---@async
    function(a)
      cb(a)
      done = true
    end
  )

  async_test_backend.wait(function()
    return done
  end)
end

---@param opts rissue.utils.CommandOpts
---@return rissue.utils.Process
local function spawn(opts)
  local p, err = process.spawn(opts)
  assert(p, err or "unknown error")
  return p
end

describe("cmd", function()
  describe("spawn", function()
    it("get running ok #blocking", function()
      run_blocking(
        ---@async
        function(a)
          local p = spawn({ cmd = "echo", args = { "Hello world" } })
          assert.is_false(p:is_running(), "not false before run")
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          assert.is_true(p:is_running(), "not true after run")
          a:yield()
          -- should be returned once on_exit was exited
          assert.is_false(p:is_running(), "not false after close")
        end
      )
    end)

    it("stdout ok", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err =
            process.spawn({ cmd = "echo", args = { "Hello World" } })
          assert(p ~= nil, spawn_err)
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local contents = p:get_stdout()
          assert.equal("Hello World\n", contents)
        end
      )
    end)

    it("stderr ok (with sh) #unix", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err = process.spawn({
            cmd = "sh",
            args = { "-c", "echo Hello World 1>&2" },
          })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local contents = p:get_stderr()
          assert.equal("Hello World\n", contents)
        end
      )
    end)

    it("return code ok", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err = process.spawn({
            cmd = "sh",
            args = { "-c", "echo Hello World 1>&2" },
          })
          assert(p ~= nil, spawn_err)
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local contents = p:get_code()
          assert.equal(0, contents)
        end
      )
    end)

    it("cwd is correct #unix", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err =
            process.spawn({ cmd = "pwd", args = {}, cwd = "/tmp" })
          assert(p ~= nil, spawn_err)
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local contents = p:get_stdout()
          assert.equal("/tmp\n", contents)
        end
      )
    end)

    it("env tableform is correct #unix #cmd:printenv", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err = process.spawn({
            cmd = "printenv",
            args = { "HELLO" },
            env = { HELLO = "YES" },
          })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local code = p:get_code()
          local contents = p:get_stdout()
          local stderr = p:get_stderr()
          assert(
            code == 0,
            "Program exited with code "
              .. tostring(code)
              .. (stderr ~= "" and (": " .. stderr) or "")
          )
          assert.equal("YES\n", contents)
        end
      )
    end)

    it("env listform is correct #unix #cmd:printenv", function()
      run_blocking(
        ---@async
        function(a)
          local p, spawn_err = process.spawn({
            cmd = "printenv",
            args = { "HELLO" },
            env = { "HELLO=YES" },
          })
          assert(p ~= nil, spawn_err)
          assert(type(p) ~= "string", "cmd.spawn returned a string")
          p:register_event("on_exit", function()
            a:resume()
          end)
          p:run()
          a:yield()
          local code = p:get_code()
          local contents = p:get_stdout()
          local stderr = p:get_stderr()
          assert(
            code == 0,
            "Program exited with code "
              .. tostring(code)
              .. (stderr ~= "" and (": " .. stderr) or "")
          )
          assert.equal("YES\n", contents)
        end
      )
    end)

    it("disable on unknown binary", function()
      local p, spawn_err =
        process.spawn({ cmd = "someRandomBinary29924", args = {} })
      assert(p ~= nil, spawn_err)
      ---@cast p rissue.utils.Process
      local msg = p:run()
      assert(
        msg and msg:match("Failed to spawn process: someRandomBinary29924"),
        "Expected message to have: 'Failed to spawn process: someRandomBinary29924'"
      )
    end)
  end)

  describe("run_async", function()
    it("outputs are correct", function()
      run_blocking(
        ---@async
        function(a)
          local result, err = process.run_async(a, {

            cmd = "sh",
            args = {
              "-c",
              'echo "stdout line"; echo "stderr line" >&2; exit 0',
            },
          })
          assert.is_not_nil(result, err)
          assert.same({
            return_code = 0,
            stdout = "stdout line\n",
            stderr = "stderr line\n",
          } --[[@as rissue.utils.CmdResult]], result)
        end
      )
    end)
  end)
end)
