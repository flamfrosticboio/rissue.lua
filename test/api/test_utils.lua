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
local log = require("rissue.utils.log")
local utils = require("util")
local uv = require("luv") ---@type uv

local describe = describe or require("busted").describe
local before_each = before_each or require("busted").before_each
local teardown = teardown or require("busted").teardown

local M = {}

M.host = "127.0.0.1"
M.port = 55000
local timeout = 60000 -- in milliseconds
local close_timeout = 5000 -- in milliseconds, for close hangs

local _id_counter = 0
---@return integer
function M.new_id()
  _id_counter = _id_counter + 1
  return _id_counter
end

---@class __rissue.with_server.Opts
---@field name string
---@field specfile string
---@field is_proxy boolean

---@class __rissue.with_proxy.Opts
---@field prefix string
---@field port integer
---@field target_port integer
---@field name string
---@field accept_rewrite string

---@param filepath string
---@param callback fun(err_msg: string|nil)
---@param port_offset integer
---@param id integer
---@return fun() start
---@return fun() close
local function run_mock_server(filepath, port_offset, id, callback)
  local watch_loop, watch_loop_err = uv.new_timer()
  if not watch_loop then
    error(watch_loop_err)
  end

  -- bump the port to separate servers and avoid race conditions
  local port = M.port + port_offset

  local p = nil ---@type (rissue.utils.Process | string)?
  local err ---@type string?

  p, err = cmd.spawn({
    cmd = "./node_modules/.bin/prism",
    args = {
      "mock",
      filepath,
      "--host",
      M.host,
      "--port",
      tostring(port),
      "--verboseLevel=trace",
    },
    cwd = "test/api",
  })

  assert(p ~= nil, err)

  p:register_event("on_exit", function()
    watch_loop:stop()
    if p:get_code() ~= 0 then
      local exit_err = p:get_stderr()
      if exit_err == "" then
        exit_err = p:get_stdout()
      end
      callback(exit_err)
      error(exit_err)
    end
  end)

  if log.level_enabled(log.levels.trace) then
    ---@type rissue.utils.Process.last_output.Opts
    local opts = { newline_on_multiline_output = true, strip_newlines = true }
    p:register_event("on_stdout", function()
      print(
        utils.ccolor("| " .. p:get_last_stdout(opts):gsub("\n", "\n| "), id)
      )
    end)

    p:register_event("on_stderr", function()
      print(
        utils.ccolor("@ " .. p:get_last_stderr(opts):gsub("\n", "\n@ "), id)
      )
    end)
  end

  local function close_func()
    local is_closed = false
    p:close(function()
      is_closed = true
    end)
    local ok = cmd.wait(function()
      return is_closed
    end, close_timeout)
    if not ok then
      print(
        "Warning: Failed to kill process gracefully. Attempting to force kill..."
      )
      p:close(nil, "sigkill")
      if not cmd.wait(function()
        return is_closed
      end, 5000) then
        print(
          "Warning: Failed to force kill application (not responding). Proceeding..."
        )
      end
    end
  end

  local function start()
    p:run()

    watch_loop:start(250, 250, function()
      log.trace("Waiting for mock server to be up...")
      local watch_process, spawn_err = cmd.spawn({
        cmd = "timeout",
        args = {
          "1",
          "bash", -- sh supports this feature
          "-c",
          "</dev/tcp/" .. M.host .. "/" .. port,
        },
      })
      if not watch_process then
        error(spawn_err)
      end

      watch_process:register_event("on_exit", function()
        if watch_process:get_code() == 0 then
          watch_loop:stop()
          callback()
        end
      end)

      local run_err = watch_process:run()
      if run_err then
        error(run_err)
      end
    end)
  end

  return start, close_func
end

---@param opts __rissue.with_proxy.Opts
---@return rissue.utils.Process
local function run_proxy(opts)
  local p, err = cmd.spawn({
    cmd = "node",
    args = {
      "test/api/proxy.cjs",
    },
    env = {
      PORT = tostring(opts.port),
      TARGET_PORT = tostring(opts.target_port),
      PREFIX = tostring(opts.prefix),
      PATH = os.getenv("PATH"),
      ACCEPT_REWRITE = opts.accept_rewrite,
    },
  })

  if not p then
    error(err)
  end

  local is_running = false
  p:register_event("on_stdout", function()
    if p:get_stdout():match("Proxy ready") then
      is_running = true
    end
  end)

  p:register_event("on_exit", function()
    if p:get_code() ~= 0 then
      error(p:get_stderr(), 0)
    end
  end)

  p:run()

  local ok, wait_err = cmd.wait(function()
    return is_running
  end, timeout)

  if not ok then
    error(wait_err)
  end

  return p
end

---@param opts __rissue.with_proxy.Opts
---@param func fun()
function M.with_proxy(opts, func)
  ---@type rissue.utils.Process?
  local process
  describe(opts.name, function()
    before_each(function()
      if process then
        return
      end

      uv.run("nowait")
      process = run_proxy(opts)
    end)

    teardown(function()
      if process then
        local is_closed = false
        process:close(function()
          is_closed = true
        end)
        local has_not_timeouted = cmd.wait(function()
          return is_closed
        end, close_timeout)
        if not has_not_timeouted then
          print(
            "Warning: Failed to safely close proxy. Attempting to close forcefully."
          )
          process:close(nil, "sigkill")
          local has_not_timeouted_forced = cmd.wait(function()
            return is_closed
          end, close_timeout)
          if not has_not_timeouted_forced then
            print("Warning: Failed to close proxy forcefully. Skipping...")
          end
        end
      end
    end)

    func()
  end)
end

---@param opts __rissue.with_server.Opts
---@param func fun(id: integer, port: integer)
function M.with_server(opts, func)
  local id = M.new_id()
  describe(opts.name, function()
    ---@type fun(), fun()
    local run, server_close
    local server_run = false

    local port_offset = opts.is_proxy and 1 or 0

    before_each(function()
      if server_run then
        return
      end

      uv.run("nowait")
      print(("[%s]: Opening server at port:%d"):format(opts.name, M.port))
      run, server_close = run_mock_server(
        "../../" .. opts.specfile,
        port_offset,
        id,
        function()
          print(("[%s]: Server is up"):format(opts.name))
          server_run = true
        end
      )
      if not (run and server_close) then
        print(("[%s]: Failed to setup server"):format(opts.name))
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
      if server_close then
        print(("[%s]: Closing server"):format(opts.name))
        server_close()
        print(("[%s]: Server closed"):format(opts.name))
      end
    end)

    func(id, M.port)
  end)
end

return M
