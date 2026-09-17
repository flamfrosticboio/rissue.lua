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

---@class rissue.utils.ProcessModule
local M = {}

local log = require("rissue.utils.log")
local table_op = require("rissue.utils.table_op")
local uv = require("luv") ---@type uv

---@alias rissue.utils.process.Event
---| "on_exit" When the entire process is finished
---| "on_stdout" When the process writes to stdout
---| "on_stderr" When the process writes to stderr
---| "on_output" When the process writes to stdout or stderr

---@class rissue.utils.process._FinishedTracker
---@field handle boolean
---@field stdout boolean
---@field stderr boolean

---@class rissue.utils.process._EventsTable
---@field on_exit fun()[]
---@field on_stdout fun()[]
---@field on_stderr fun()[]
---@field on_output fun()[]

---@class rissue.utils.Process
---@field package _events rissue.utils.process._EventsTable List of events
---@field package _handle uv.uv_process_t?
---@field package _stdout_pipe uv.uv_pipe_t?
---@field package _stderr_pipe uv.uv_pipe_t?
---@field package _exit_code integer -1 means not finished
---@field package _stdout_raw string[]
---@field package _stderr_raw string[]
---@field package _finished rissue.utils.process._FinishedTracker
---@field package _complete boolean
---@field package _opts rissue.utils.CommandOpts
---@field package __index table? Stub to avoid listing in IDE
local Process = {}
Process.__index = Process

---@param events fun()[]
local function run_all_events(events)
  for _, event in ipairs(events) do
    event()
  end
end

--- Tries to fully exit
---@package
function Process:try_exit()
  if not self._complete and table_op.all(self._finished) then
    self._complete = true
    run_all_events(self._events.on_exit)
  end
end

--- Registers an event
---@param event_name rissue.utils.process.Event
---@param callback fun()
function Process:register_event(event_name, callback)
  local event_table = self._events[event_name]
  if event_table then
    table.insert(event_table, callback)
  else
    error("unknown event:  " .. event_name)
  end
end

--- Warning: Does not run callback if the handle is closing
---
--- Will become a race condition bug if I try to run callback while the handle is closing
---@param h uv.uv_handle_t?
---@param callback fun(...: any)?
---@param ... any args
local function close_handle(h, callback, ...)
  if not h then
    return
  end

  if not h:is_closing() then
    local args = { ... }
    h:close(callback and function()
      callback(unpack(args))
    end)
  end
end

--- Closes the process by killing it. Requires waiting for the process to finish
---@param callback fun()?
---@param signal string | integer | nil
function Process:close(callback, signal)
  -- skip if the process was finished
  if self._complete then
    if callback then
      callback()
    end
    return
  end

  if callback then
    self:register_event("on_exit", callback)
  end

  if not self._handle:is_closing() then
    local success, err = self._handle:kill(signal or "sigterm")
    if not success then
      require("rissue.utils.log").warn(err or "failed to kill process")
    end
  end
end

---@return boolean success
---@return uv.uv_pipe_t | string
local function new_pipe()
  local pipe, pipe_err = uv.new_pipe()
  if not pipe then
    return false, pipe_err or "unknown error"
  end

  return true, pipe
end

---@param pipe uv.uv_pipe_t
---@param buffer string[]
---@param on_close fun()
---@param on_read fun()
local function read_pipe(pipe, buffer, on_close, on_read)
  pipe:read_start(function(err, data)
    if err then
      pipe:read_stop()
      if err then
        table.insert(buffer, ("<!Error reading pipe: %s>"):format(err))
      end
      close_handle(pipe, on_close)
      return
    end

    if data then
      table.insert(buffer, data)
      on_read()
    else
      pipe:read_stop()
      close_handle(pipe, on_close)
    end
  end)
end

--- Runs the process
--- May raise errors! Recommended to wrap in pcall!
function Process:run()
  local ok_stdout, pipe_stdout = new_pipe()

  if not ok_stdout then
    error(pipe_stdout)
  end

  ---@cast pipe_stdout uv.uv_pipe_t

  local ok_stderr, pipe_stderr = new_pipe()

  if not ok_stderr then
    close_handle(pipe_stdout)
    error(pipe_stderr)
  end

  local function on_stdout_pipe_close()
    log.trace("Stdout pipe closed")
    self._finished.stdout = true
    self:try_exit()
  end

  local function on_stderr_pipe_close()
    log.trace("Stderr pipe closed")
    self._finished.stderr = true
    self:try_exit()
  end

  ---@cast pipe_stderr uv.uv_pipe_t

  ---@type uv.spawn.options
  ---@diagnostic disable-next-line: missing-fields
  local options = {
    args = self._opts.args,
    cwd = self._opts.cwd,
    env = self._opts.env --[=[@type string[]]=],
    stdio = { nil, pipe_stdout, pipe_stderr },
  }
  local handle = uv.spawn(self._opts.cmd, options, function(code)
    -- for now we don't handle signal code
    self._exit_code = code
    log.trace("Program exited with code " .. tostring(code))
    close_handle(self._handle, function()
      self._finished.handle = true
      self:try_exit()
    end)

    close_handle(pipe_stdout, on_stdout_pipe_close)
    close_handle(pipe_stderr, on_stderr_pipe_close)
  end)

  if not handle then
    close_handle(pipe_stdout)
    close_handle(pipe_stderr)
    error("Failed to spawn process: " .. self._opts.cmd)
  end

  -- unknown reason why read_pipe must happen after uv.spawn

  read_pipe(pipe_stdout, self._stdout_raw, on_stdout_pipe_close, function()
    run_all_events(self._events.on_stdout)
    run_all_events(self._events.on_output)
  end)

  read_pipe(pipe_stderr, self._stderr_raw, on_stderr_pipe_close, function()
    run_all_events(self._events.on_stderr)
    run_all_events(self._events.on_output)
  end)

  self._handle = handle
  self._stderr_pipe = pipe_stderr
  self._stdout_pipe = pipe_stdout

  if log.level_enabled(log.levels.debug) then
    log.log(
      "\nRunning process: "
        .. M.construct_command_line_string(self._opts.cmd, self._opts.args)
        .. (self._opts.cwd and ("\n\tOn cwd: " .. self._opts.cwd) or "")
        .. (
          self._opts.env and ("\n\tWith env: " .. table.concat(self._opts.env, " "))
          or ""
        ),
      log.levels.debug
    )
  end
end

function Process:get_code()
  return self._exit_code
end

---@return string
function Process:get_stdout()
  return table.concat(self._stdout_raw)
end

---@return string
function Process:get_stderr()
  return table.concat(self._stderr_raw)
end

--- Gets the latest stdout output
--- Used with relation to `on_stdout` or `on_output` event (e.g. print output)
--- @param strip_newline boolean? No by default
function Process:get_last_stdout(strip_newline)
  local line = self._stdout_raw[#self._stdout_raw]
  if strip_newline then
    line = line:gsub("[\r\n]+$", "")
  end
  return line
end

--- Gets the latest stderr output
--- Used with relation to `on_stderr` or `on_output` event (e.g. print output)
--- @param strip_newline boolean? No by default
function Process:get_last_stderr(strip_newline)
  local line = self._stderr_raw[#self._stderr_raw]
  if strip_newline then
    line = line:gsub("[\r\n]+$", "")
  end
  return line
end

---Spawns a process (without running)
---@param opts rissue.utils.CommandOpts
---@return rissue.utils.Process? spawned_process
---@return string? error
function M.spawn(opts)
  if not opts.cmd then
    return nil, "Cmd is not provided"
  end

  if opts.env then
    local new_env = {}
    for k, v in pairs(opts.env) do
      if type(k) == "number" then
        new_env[#new_env + 1] = v
      else
        new_env[#new_env + 1] = tostring(k) .. "=" .. v
      end
    end
    opts.env = new_env
  end

  ---@type rissue.utils.Process
  local process = {
    _events = {
      on_exit = {},
      on_stdout = {},
      on_output = {},
      on_stderr = {},
    },
    _handle = nil,
    _exit_code = -1,
    _stderr_raw = {},
    _stdout_raw = {},
    _finished = {
      handle = false,
      stderr = false,
      stdout = false,
    },
    _stdout_pipe = nil,
    _stderr_pipe = nil,
    _opts = opts,
    _complete = false,
  }

  return setmetatable(process, Process), nil
end

--- A lightweight wrapper that calls `error()` on error
---@param opts rissue.utils.CommandOpts
---@return rissue.utils.Process
function M.spawn_err(opts)
  local p, err = M.spawn(opts)
  if not p then
    error(err)
  end
  return p
end

--- Wrapper to M.spawn with `uv.spawn()` that blocks for exit inside coroutines.
--- Use `process.spawn()` if manually implementing instead.
---
--- Warning: May raise errors
--- @param command_opts rissue.utils.CommandOpts
--- @param opts rissue.utils.run.Opts?
--- @return rissue.utils.CmdResult? result
--- @return string? error
function M.run_co(command_opts, opts)
  local co, is_main = coroutine.running()
  if is_main or not co then
    error("must be inside a coroutine")
  end

  local p, err = M.spawn(command_opts)
  if not p then
    return nil, err
  end

  p:register_event("on_exit", function()
    local ok, resume_err = coroutine.resume(co)
    if not ok then
      error(debug.traceback(co, resume_err), 0)
    end
  end)

  if opts and opts.print_output then
    p:register_event("on_stdout", function()
      log.info("| " .. p:get_last_stdout(true))
    end)
    p:register_event("on_stderr", function()
      log.info("@ " .. p:get_last_stderr(true))
    end)
  end

  p:run()
  coroutine.yield()
  return {
    return_code = p:get_code(),
    stdout = p:get_stdout(),
    stderr = p:get_stderr(),
  } --[[@as rissue.utils.CmdResult]]
end

--- Blocks the main thread until the process exists.
--- Recommended on one shot commands such as `mkdir` and `touch`.
--- Warning: May raise errors! Recommended to wrap in `pcall()`
---
--- Use `process.run_co()` to run blocking on coroutine instead.
--- Use `os.execute()` for simplicity instead.
--- @param command_opts rissue.utils.CommandOpts
--- @param timeout integer Pass -1 to disable timeout
--- @param opts rissue.utils.run.Opts?
--- @return rissue.utils.CmdResult? result
--- @return string? error
function M.run(command_opts, timeout, opts)
  local finished = false
  local p, err = M.spawn(command_opts)
  if not p then
    return nil, err
  end
  p:register_event("on_exit", function()
    finished = true
  end)
  if opts and opts.print_output then
    p:register_event("on_stdout", function()
      log.info("| " .. p:get_last_stdout(true))
    end)
    p:register_event("on_stderr", function()
      log.info("@ " .. p:get_last_stderr(true))
    end)
  end
  p:run()
  local wait_ok = M.wait(function()
    return finished
  end, timeout)

  if not wait_ok then
    return nil, "timeout reached"
  end

  return {
    return_code = p:get_code(),
    stderr = p:get_stderr(),
    stdout = p:get_stdout(),
  } --[[@as rissue.utils.CmdResult]]
end

---@param timer uv.uv_timer_t?
local function try_stop_timer(timer)
  if timer then
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

--- Delays the coroutine/main thread execution by number of milliseconds
---
--- If not in coroutine mode, it uses `process.wait()` instead
---@param milliseconds integer
---@return boolean success
---@return string? error
function M.try_delay(milliseconds)
  local timer, timer_err = uv.new_timer()
  if not timer then
    return false, timer_err
  end

  local co, is_main = coroutine.running()

  if not is_main and co then
    local start_ok, start_err = timer:start(milliseconds, 0, function()
      coroutine.resume(co)
    end)
    if not start_ok then
      close_handle(timer)
      return false, start_err
    end
    coroutine.yield()
  else
    local done = false
    local start_ok, start_err = timer:start(milliseconds, 0, function()
      done = true
    end)
    if not start_ok then
      close_handle(timer)
      return false, start_err
    end
    M.wait(function()
      return done
    end, -1)
  end

  return true
end

local waiting = false
local force_stop_waiting = false

--- Stops the current `process.wait`
--- @return boolean success
--- @return string? error
function M.try_stop_current_wait()
  if waiting then
    force_stop_waiting = true
    local timer, err = uv.new_timer()
    if not timer then
      return false, err
    end
    timer:start(0, 0, function()
      try_stop_timer(timer)
    end)
    return true
  end
  return false
end

---@param condition fun(): boolean
---@param timeout integer  Pass -1 to disable timeout
---@param interval integer?
---@return boolean success Returns false when timeout is reached
function M.wait(condition, timeout, interval)
  local function wait()
    if condition() then
      return true
    end

    ---@type uv.uv_timer_t?
    local timeout_timer
    ---@type uv.uv_timer_t?
    local interval_timer

    local timed_out = false
    if timeout and timeout > 0 then
      local timeout_timer_err
      timeout_timer, timeout_timer_err = uv.new_timer()
      if not timeout_timer then
        error(timeout_timer_err)
      end
      timeout_timer:start(timeout, 0, function()
        timed_out = true
      end)
    end

    if interval then
      -- to trigger and escape uv.run('once')
      local interval_timer_err
      interval_timer, interval_timer_err = uv.new_timer()
      if not interval_timer then
        error(interval_timer_err)
      end
      interval_timer:start(interval, interval, function() end)
    end

    while not condition() do
      if timed_out or force_stop_waiting then
        try_stop_timer(timeout_timer)
        try_stop_timer(interval_timer)
        return false
      end
      uv.run("once")
    end

    try_stop_timer(timeout_timer)
    try_stop_timer(interval_timer)

    return true
  end

  waiting = true
  local res = wait()
  waiting = false
  force_stop_waiting = false
  return res
end

---@param arg string
---@return string
local function shell_escape(arg)
  local needs_escape = arg == "" or arg:find("[^%w%-%._/]") ~= nil
  if needs_escape then
    return "'" .. arg:gsub("'", "'\\''") .. "'"
  end
  return arg
end

--- A utility function that constructs a command line string that can be used to print
--- into console for debugging purposes
---@param cmd string
---@param args string[]
---@return string
function M.construct_command_line_string(cmd, args)
  local str_tbl = {}
  str_tbl[#str_tbl + 1] = shell_escape(cmd)
  for i, arg in ipairs(args) do
    str_tbl[i + 1] = shell_escape(arg)
  end
  return table.concat(str_tbl, " ")
end

return M
