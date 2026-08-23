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

local cmd = require("rissue.utils.process")
---@type uv
local uv = require("luv")

local describe = describe or require("busted").describe
local setup = setup or require("busted").setup
local teardown = teardown or require("busted").teardown

local M = {}

M.host = "127.0.0.1"
M.port = 55000
local timeout = 60000 -- in milliseconds
local close_timeout = 30000 -- in milliseconds, for close hangs

---@param filepath string
---@param callback fun()
---@param id integer
---@return fun() start
---@return fun() close
local function run_mock_server(filepath, id, callback)
  local watch_loop, watch_loop_err = uv.new_timer()
  if not watch_loop then
    error(watch_loop_err)
  end

  -- bump the port to separate servers and avoid race conditions
  local port = M.port + id

  local p = nil ---@type (rissue.utils.Process | string)?
  local err ---@type string?

  p, err = cmd.spawn({
    cmd = "npx",
    args = {
      "@stoplight/prism-cli",
      "mock",
      "--host",
      M.host,
      "--port",
      tostring(port),
      filepath,
      "--verboseLevel=trace",
    },
    cwd = "test/api",
  })

  assert(p ~= nil, err)

  p:register_event("on_exit", function()
    watch_loop:stop()
  end)

  p:register_event("on_stdout", function()
    local str = p:get_last_stdout():gsub("[\r\n]+$", "")
    print("| " .. str)
  end)

  p:register_event("on_stderr", function()
    local str = p:get_last_stderr():gsub("[\r\n]+$", "")
    print("| " .. str)
  end)

  local function close_func()
    local is_closed = false
    p:close(function()
      is_closed = true
    end)
    local ok = cmd.wait(function()
      return is_closed
    end, close_timeout)
    if not ok then
      print("Warning: Failed to kill process gracefully. Attempting to force kill...")
      p:close(nil, "sigkill")
      cmd.wait(function()
        return is_closed
      end, 5000)
    end
  end

  local function start()
    p:run()

    watch_loop:start(1000, 1000, function()
      local watch_err = coroutine.wrap(function()
        print("Checking...")
        local result, co_err = cmd.run_co({
          cmd = "timeout",
          args = {
            "1",
            "bash",
            "-c",
            "</dev/tcp/" .. M.host .. "/" .. port,
          },
        })
        if not result then
          error(co_err)
        end
        if result.return_code == 0 then
          watch_loop:stop()
          local callback_thread = coroutine.create(function()
            callback()
          end)
          local callback_ok, co_watch_err = coroutine.resume(callback_thread)
          assert(callback_ok, co_watch_err)
        end
      end)()
      assert(not watch_err, watch_err)
    end)
  end

  return start, close_func
end

---@param name string
---@param spec_filepath string
---@param id integer
---@param func fun()
function M.with_server(name, id, spec_filepath, func)
  describe(name, function()
    ---@type fun(), fun()
    local run, server_close
    local server_run = false

    setup(function()
      uv.run("nowait")
      print(("[%s]: Opening server"):format(name))
      run, server_close = run_mock_server("../../" .. spec_filepath, id, function()
        print(("[%s]: Server is up"):format(name))
        server_run = true
      end)
      if not (run and server_close) then
        print(("[%s]: Failed to setup server"):format(name))
      end

      run()

      local successful = cmd.wait(function()
        return server_run
      end, timeout)
      if not successful then
        server_close()
        error("Timeout reached")
      end
    end)

    teardown(function()
      print(("[%s]: Closing server"):format(name))
      server_close()
      print(("[%s]: Server closed"):format(name))
    end)

    func()
  end)
end

--- setup logging
local logger = require("rissue.utils.log")
logger.log_level = logger.levels.trace

return M
