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

---@type uv
local uv = require("luv")

---@class rissue.utils.CmdModule
local M = {}

---@param handle uv.uv_handle_t
---@param callback fun()?
local function safe_close(handle, callback)
  if handle and not handle:is_closing() then
    handle:close(callback)
  end
end

---@param buffer rissue.utils.ReadResult.raw
---@param pipe uv.uv_pipe_t
---@param on_complete? fun()
local function handle_read_pipe(pipe, buffer, on_complete)
  pipe:read_start(function(err, data)
    if err then
      buffer.failed = true
      pipe:read_stop()
      safe_close(pipe)
      if on_complete then
        on_complete()
      end
      return
    end

    if data then
      buffer.contents[#buffer.contents + 1] = data
    else
      pipe:read_stop()
      safe_close(pipe)
      if on_complete then
        on_complete()
      end
    end
  end)
end

--- A wrapper that raises an error when the pipe failed to create
--- @return uv.uv_pipe_t
local function create_pipe_with_error()
  local pipe, err, err_name = uv.new_pipe()
  if not pipe then
    error(
      "Failed to create pipe: "
        .. (err or "unknown error")
        .. (err_name and " [" .. err_name .. "]")
    )
  end
  return pipe
end

---@param raw rissue.utils.ReadResult.raw
---@return rissue.utils.ReadResult
local function into_read_result(raw)
  ---@type rissue.utils.ReadResult
  return {
    failed = raw.failed,
    contents = table.concat(raw.contents),
  }
end

--- Creates the process without running `uv.run()`.
--- Use `cmd.run()` to run in one-shot instead
---
--- Warning: May raise an error
---
--- Note: Requires to be placed on a coroutine.
---
--- The cmd result may return an exit code `-1` to signify that the process did not
--- run correctly.
---@async
---@param cmd string[]
---@param opts rissue.utils.CommandOpts?
---@return rissue.utils.CmdResult result
function M.spawn(cmd, opts)
  local co = coroutine.running()
  if not co then
    error("not inside an coroutine")
  end

  local exe = cmd[1]
  if not exe then
    error("no binary provided")
  end
  ---@type string[]
  local args = {}
  for i = 2, #cmd do
    args[#args + 1] = cmd[i]
  end

  local stdout = create_pipe_with_error()
  local stderr_ok, stderr = pcall(create_pipe_with_error)
  if not stderr_ok then
    safe_close(stdout)
    error(stderr)
  end

  ---@type rissue.utils.ReadResult.raw
  local result_stdout = { contents = {} }
  ---@type rissue.utils.ReadResult.raw
  local result_stderr = { contents = {} }
  local exit_code = -1

  -- track completion state
  local exited = false
  local stdout_done = false
  local stderr_done = false

  local function maybe_resume()
    if exited and stdout_done and stderr_done then
      local ok, err = coroutine.resume(co, exit_code)
      if not ok then
        error(err)
      end
    end
  end

  ---@type uv.spawn.options
  ---@diagnostic disable-next-line: missing-fields
  local options = {
    args = args,
    stdio = { nil, stdout, stderr },
    ---@diagnostic disable-next-line: assign-type-mismatch
    cwd = opts and opts.cwd,
    ---@diagnostic disable-next-line: assign-type-mismatch
    env = opts and opts.env,
    detached = false,
    hide = false,
    verbatim = false,
  }

  local handle
  handle = uv.spawn(exe, options, function(code)
    exited = true
    exit_code = code
    safe_close(handle)
    maybe_resume()
  end)

  if not handle then
    safe_close(stdout)
    safe_close(stderr)
    error("Failed to spawn process: " .. exe)
  end

  handle_read_pipe(stdout, result_stdout, function()
    stdout_done = true
    maybe_resume()
  end)

  handle_read_pipe(stderr, result_stderr, function()
    stderr_done = true
    maybe_resume()
  end)

  -- wait for the entire thing to finish
  coroutine.yield()

  ---@type rissue.utils.CmdResult
  local result = {
    return_code = exit_code,
    stdout = into_read_result(result_stdout),
    stderr = into_read_result(result_stderr),
  }

  return result
end

--- Creates the process and waits for it to finish running.
---
--- Warning: May raise an error
---
--- The cmd result may return an exit code `-1` to signify that the process did not
--- run correctly.
---@param cmd string[]
---@param opts rissue.utils.CommandOpts? current working directory
---@return rissue.utils.CmdResult
function M.run(cmd, opts)
  local co = coroutine.running()
  if co then
    -- coroutine attach mode
    return M.spawn(cmd, opts)
  else
    local final_result
    co = coroutine.create(function()
      final_result = M.spawn(cmd, opts)
    end)

    local okk, err = coroutine.resume(co)
    if not okk then
      error(err)
    end
    uv.run()
    return final_result
  end
end

--- Runs multiple commands in parallel and waits for all processes to exit.
---
--- Warning: May raise an error
---@param cmds rissue.cmd[]
---@param on_a_process_complete fun(cmd: rissue.cmd)? Runs when a command finishes (e.g. counters)
---@return rissue.utils.RunMultipleResults results
function M.run_multiple(cmds, on_a_process_complete)
  ---@type rissue.utils.RunMultipleResults
  local results = {}

  for _, cmd in ipairs(cmds) do
    local co = coroutine.create(function()
      results[cmd] = M.spawn(cmd)
      if on_a_process_complete then
        on_a_process_complete(cmd)
      end
    end)
    local ok, err = coroutine.resume(co)
    if not ok then
      error(err)
    end
  end

  uv.run()

  return results
end

--- Wraps the `cmd.run()` with basic curl.
---@param url string
---@param method rissue.utils.HttpMethod
---@param headers string[]
---@param opts rissue.utils.CommandOpts?
---@return boolean success
---@return string result_or_error
function M.curl(url, method, headers, opts)
  local cmd = { "curl", "-sS", "-f", url, "-X", method }
  local i = #cmd
  for _, header in ipairs(headers) do
    i = i + 2
    cmd[i - 1] = "-H"
    cmd[i] = header
  end
  local result = M.run(cmd, opts)
  ---@cast result rissue.utils.CmdResult
  if result.return_code ~= 0 then
    if result.stderr.contents ~= "" then
      return false, result.stderr.contents
    end
    -- fallback to stdout when it errors
    return false, result.stdout.contents
  end
  return true, result.stdout.contents
end

---@param cond fun(): boolean
---@param timeout integer
---@param interval integer?
---@return boolean successful
function M.blocking_wait(cond, timeout, interval)
  interval = interval or 100
  local timer, err = uv.new_timer()
  if not timer then
    error(err)
  end
  timer:start(interval, interval, function() end)

  local start = uv.now()
  local ok = true
  while not cond() do
    if uv.now() - start >= timeout then
      ok = false
      break
    end
    uv.run("once")
  end

  timer:stop()
  safe_close(timer)
  return ok
end

return M
