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

local cmd = require("rissue.utils.cmd")
---@type uv
local uv = require("luv")

local describe = describe or require("busted").describe
local setup = setup or require("busted").setup
local teardown = teardown or require("busted").teardown

local M = {}

M.host = "127.0.0.1"
M.port = 35880
local timeout = 30000 -- 30 second

---@param pipe_or_handle uv.uv_handle_t
local function safe_close(pipe_or_handle)
  if not pipe_or_handle:is_closing() then
    pipe_or_handle:close()
  end
end

---@param buffer string[]
---@param on_close fun()
---@return uv.uv_pipe_t
local function new_pipe(buffer, on_close)
  local pipe, pipe_err = uv.new_pipe(false)
  if not pipe then
    error(pipe_err)
  end

  pipe:read_start(function(err, data)
    if err then
      pipe:read_stop()
      safe_close(pipe)
      error(err)
    end

    if data then
      buffer[#buffer + 1] = data
    else
      pipe:read_stop()
      safe_close(pipe)
      on_close()
    end
  end)

  return pipe
end

---@param stdout string[]
---@param stderr string[]
---@return string
local function represent(stdout, stderr)
  if #stderr > 0 then
    return table.concat(stderr)
  end
  return table.concat(stdout)
end

--- Spawns a background process without
---@param exe string
---@param args string[]
---@param cwd string?
---@param on_close fun(code: integer, output: string)
---@return fun() close_function
---@return {stdout: string[], stderr: string[]} buffer
local function background(exe, args, cwd, on_close)
  local handle, handle_err
  local ret_code = -1
  local exit_stdout, exit_stderr, exit_handle = false, false, false

  if os.getenv("VERBOSE") then
    print(exe, table.concat(args, " "))
  end

  ---@type string[], string[]
  local stderr, stdout = {}, {}

  local function try_close()
    if exit_handle and exit_stderr and exit_stdout then
      on_close(ret_code, represent(stdout, stderr))
    end
  end

  local stdout_pipe_ok, stdout_pipe = pcall(new_pipe, stdout, function()
    exit_stdout = true
  end)
  if not stdout_pipe_ok then
    error(stdout_pipe)
  end
  local stderr_pipe_ok, stderr_pipe = pcall(new_pipe, stderr, function()
    exit_stderr = true
  end)
  if not stderr_pipe_ok then
    safe_close(stdout_pipe)
    error(stdout_pipe)
  end

  handle, _, handle_err = uv.spawn(
    exe,
    ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
    { args = args, cwd = cwd, stdio = { nil, stdout_pipe, stderr_pipe } },
    function(code)
      ret_code = code
      if not handle:is_closing() then
        safe_close(handle)
        safe_close(stdout_pipe)
        safe_close(stderr_pipe)
        exit_handle = true
        try_close()
      end
    end
  )
  if not handle then
    error("handle error: " .. tostring(handle_err))
  end
  return function()
    if not handle:is_closing() then
      safe_close(handle)
      safe_close(stdout_pipe)
      safe_close(stderr_pipe)
      try_close()
    end
  end, { stdout = stdout, stderr = stderr }
end

---@param filepath string
---@param callback fun()
---@param id integer
---@return fun() start
---@return fun() close
local function run_mock_server(filepath, id, callback)
  ---@type fun()?
  local close
  local buffer
  coroutine.wrap(function()
    local timeout_timer, timeout_timer_err = uv.new_timer()
    if not timeout_timer then
      error(timeout_timer_err)
    end

    local watch_loop, watch_loop_err = uv.new_timer()
    if not watch_loop then
      error(watch_loop_err)
    end

    -- bump the port to separate servers and avoid race conditions
    M.port = M.port + id

    close, buffer = background(
      "stdbuf",
      {
        "-oL",
        "-eL",
        "npx",
        "@stoplight/prism-cli",
        "mock",
        "--host",
        M.host,
        "--port",
        tostring(M.port),
        filepath,
      },
      "test/api",
      function(code, err)
        timeout_timer:stop()
        watch_loop:stop()
        print("Server Closed")

        if code ~= 0 then
          print(err)
          error(err)
        end
      end
    )

    watch_loop:start(1000, 1000, function()
      coroutine.wrap(function()
        local result = cmd.run({
          "timeout",
          "1",
          "bash",
          "-c",
          "</dev/tcp/" .. M.host .. "/" .. M.port,
        })
        if result.return_code == 0 then
          watch_loop:stop()
          timeout_timer:stop()
          local callback_thread = coroutine.create(function()
            callback()
          end)
          local callback_ok, err = coroutine.resume(callback_thread)
          assert(callback_ok, err)
        end
      end)()
    end)

    timeout_timer:start(timeout, 0, function()
      close()
      if buffer then
        print("Stdout:")
        print(table.concat(buffer.stdout))

        print("\n\nStderr:")
        print(table.concat(buffer.stderr))
      end
      error("timeout reached: " .. tostring(timeout) .. "ms")
    end)

    -- wait for stuff
    coroutine.yield()
  end)()

  local function close_func()
    local is_closed = false
    if close then
      local timer, timer_err = uv.new_timer()
      if not timer then
        error(timer_err)
      end
      uv.timer_start(timer, 1000, 0, function()
        close()
        is_closed = true
      end)
      M.wait(function()
        return is_closed
      end)
    end
  end

  local function start()
    uv.run("nowait")
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
      print(("[%s]: Opening server"):format(name))
      run, server_close = run_mock_server("../../" .. spec_filepath, id, function()
        print(("[%s]: Server started"):format(name))
        server_run = true
      end)
      if not (run and server_close) then
        print(("[%s]: Failed to setup server"):format(name))
      end

      M.wait(function()
        return server_run
      end)
    end)

    teardown(function()
      print(("[%s]: Closing server"):format(name))
      server_close()
      print(("[%s]: Server closed"):format(name))
    end)

    func()
  end)
end

---@param cond fun(): boolean
---@param interval integer?
function M.wait(cond, interval)
  interval = interval or 100
  local timer, err = uv.new_timer()
  if not timer then
    error(err)
  end
  timer:start(interval, interval, function() end)

  while not cond() do
    uv.run("once")
  end

  timer:stop()
  timer:close()
  safe_close(timer)
end

return M
