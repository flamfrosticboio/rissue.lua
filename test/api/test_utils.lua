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

local describe = require("busted").describe or describe
local lazy_setup = require("busted").lazy_setup or lazy_setup
local lazy_teardown = require("busted").lazy_teardown or lazy_teardown

--- Mask real credentials from being leaked on output when testing.
--- Prism will accept any value for authentication so this is fine.
local env = require("rissue.env")
---@param provider string
---@diagnostic disable-next-line: duplicate-set-field
env.get_token = function(provider)
  return "$GIT_TK_" .. provider:upper()
end

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

---@class __rissue.ProxyHandle
---@field cleanup fun()

---@class __rissue.with_server.Opts
---@field name string
---@field specfile string
---@field proxy __rissue.ProxyHandle?

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
---@return fun()? start
---@return fun()? close
---@return string? err_msg
local function run_mock_server(filepath, port_offset, id, callback)
  local watch_loop, watch_loop_err = uv.new_timer()
  if not watch_loop then
    return nil, nil, watch_loop_err
  end

  -- bump the port to separate servers and avoid race conditions
  local port = M.port + port_offset

  local p = nil ---@type (rissue.utils.Process | string)?
  local err ---@type string?

  p, err = cmd.spawn({
    cmd = "./test/api/node_modules/.bin/prism",
    args = {
      "mock",
      filepath,
      "--host",
      M.host,
      "--port",
      tostring(port),
      log.level_enabled(log.levels.trace) and "--verboseLevel=trace"
        or "--verboseLevel=warn",
    },
  })

  if p == nil then
    return nil, nil, err
  end

  p:register_event("on_exit", function()
    watch_loop:stop()
    if p:get_code() ~= 0 then
      local exit_err = p:get_stderr()
      if exit_err == "" then
        exit_err = p:get_stdout()
      end
      callback(exit_err)
    end
  end)

  ---@type rissue.utils.Process.last_output.Opts
  local opts = { newline_on_multiline_output = true, strip_newlines = true }
  p:register_event("on_stdout", function()
    print(utils.ccolor("| " .. p:get_last_stdout(opts):gsub("\n", "\n| "), id))
  end)

  p:register_event("on_stderr", function()
    print(utils.ccolor("@ " .. p:get_last_stderr(opts):gsub("\n", "\n@ "), id))
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
        --- it is very safe to return here
        log.debug("Watch loop spawn error:", spawn_err)
        return
      end

      watch_process:register_event("on_exit", function()
        if watch_process:get_code() == 0 then
          watch_loop:stop()
          callback()
        end
      end)

      local run_err = watch_process:run()
      if run_err then
        return
      end
    end)
  end

  return start, close_func
end

---@param opts __rissue.with_proxy.Opts
---@return rissue.utils.Process?
---@return string? error
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

  --- when spawning is error
  if not p then
    return nil, err
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

  local run_err = p:run()
  if run_err then
    return nil, run_err
  end

  local ok, wait_err = cmd.wait(function()
    return is_running
  end, timeout)

  if not ok then
    return nil, wait_err
  end

  return p
end

---@param opts __rissue.with_proxy.Opts
---@param func fun(handle: __rissue.ProxyHandle)
function M.with_proxy(opts, func)
  ---@type rissue.utils.Process?
  local process
  describe(opts.name, function()
    local function cleanup()
      if process then
        log.info("Closing proxy...")
        local is_closed = false
        process:close(function()
          is_closed = true
        end)
        local has_not_timeouted = cmd.wait(function()
          return is_closed
        end, close_timeout)
        if not has_not_timeouted then
          log.warn(
            "Failed to safely close proxy. Attempting to close forcefully."
          )
          process:close(nil, "sigkill")
          local has_not_timeouted_forced = cmd.wait(function()
            return is_closed
          end, close_timeout)
          if not has_not_timeouted_forced then
            log.warn("Failed to close proxy forcefully. Skipping...")
          end
        end
        process = nil
        log.info("Proxy is closed")
      end
    end

    lazy_setup(function()
      uv.run("nowait")
      local err
      log.info("Running proxy...")
      process, err = run_proxy(opts)

      if err then
        log.error("Failed to setup proxy:", err)
        cleanup()
        error(err, 0)
      end

      log.info("Proxy is running")
    end)

    lazy_teardown(cleanup)

    func({ cleanup = cleanup })
  end)
end

---@param opts __rissue.with_server.Opts
---@param func fun(id: integer, port: integer)
function M.with_server(opts, func)
  local id = M.new_id()
  describe(opts.name, function()
    ---@type fun()?, fun()?
    local run, server_close
    ---@type boolean, string?
    local server_run, server_error = false, nil

    local port_offset = opts.proxy and 1 or 0

    local function cleanup()
      if server_close then
        print(("[%s]: Closing server"):format(opts.name))
        server_close()
        print(("[%s]: Server closed"):format(opts.name))
      end
    end

    local function cleanup_error()
      cleanup()

      if opts.proxy then
        opts.proxy.cleanup()
      end
    end

    lazy_setup(function()
      uv.run("nowait")

      print(("[%s]: Opening server at port:%d"):format(opts.name, M.port))
      local err
      run, server_close, err = run_mock_server(
        opts.specfile,
        port_offset,
        id,
        function(err_msg)
          if err_msg then
            server_error = err_msg
          else
            print(("[%s]: Server is up"):format(opts.name))
          end

          server_run = true
        end
      )
      if not (run and server_close) then
        cleanup_error()
        print(("[%s]: Failed to setup server: %s"):format(opts.name, err))
        error(err, 0)
      end

      run()

      local successful, wait_err = cmd.wait(function()
        return server_run
      end, timeout)

      if not successful or server_error ~= nil then
        cleanup_error()
        error(
          string.format(
            "[%s] Error while waiting for server availability: %s",
            opts.name,
            wait_err or server_error or "unknown error"
          ),
          0
        )
      end
    end)

    lazy_teardown(cleanup)

    func(id, M.port)
  end)
end

return M
