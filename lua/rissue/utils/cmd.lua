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

---@param buffer rissue.utils.ReadResult.raw
---@param pipe uv.uv_pipe_t
---@param on_complete? fun()
local function handle_read_pipe(pipe, buffer, on_complete)
  pipe:read_start(function(err, data)
    if err then
      buffer.failed = true
      pipe:read_stop()
      pipe:close()
      if on_complete then
        on_complete()
      end
      return
    end

    if data then
      buffer.contents[#buffer.contents + 1] = data
    else
      pipe:read_stop()
      pipe:close()
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
---@param cwd string? Current working directory
---@return rissue.utils.CmdResult
function M.spawn(cmd, cwd)
  local co = coroutine.running()
  if not co then
    error("not inside an coroutine")
  end

  local exe = cmd[1]
  if not exe then
    error("no binary provided")
  end
  local args = {}
  for i = 2, #cmd do
    args[#args + 1] = cmd[i]
  end

  local stdout = create_pipe_with_error()
  local stderr = create_pipe_with_error()

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
      coroutine.resume(co, exit_code)
    end
  end

  ---@type uv.spawn.options
  ---@diagnostic disable-next-line: missing-fields, assign-type-mismatch
  local options = { args = args, stdio = { nil, stdout, stderr }, cwd = cwd }

  local handle
  handle = uv.spawn(exe, options, function(code)
    exited = true
    exit_code = code
    handle:close()
    maybe_resume()
  end)

  if not handle then
    stdout:close()
    stderr:close()
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
  return {
    return_code = exit_code,
    stdout = into_read_result(result_stdout),
    stderr = into_read_result(result_stderr),
  }
end

--- Creates the process and waits for it to finish running.
---
--- If wrapped inside a coroutine, it will run with `async` through `cmd.spawn()`
--- but may raise **errors** instead of wrapped safely inside a pcall (limitation from lua5.1 only).
---
--- The cmd result may return an exit code `-1` to signify that the process did not
--- run correctly.
---@param cmd string[]
---@param cwd string? current working directory
---@return boolean success
---@return rissue.utils.CmdResult | string
function M.run(cmd, cwd)
  local co = coroutine.running()
  if co then
    -- coroutine attach mode
    ---@diagnostic disable-next-line: undefined-global
    if _VERSION == "Lua 5.1" and not jit then
      -- hardwire to M.spawn with errors since pcall wont work
      return true, M.spawn(cmd, cwd)
    end
    local ok, result = pcall(function()
      return M.spawn(cmd, cwd)
    end)
    if not ok then
      return false, result
    end
    return ok, result
  else
    -- blocking mode
    local ok, result = pcall(function()
      local final_result
      co = coroutine.create(function()
        final_result = M.spawn(cmd, cwd)
      end)
      local okk, err = coroutine.resume(co)
      if not okk then
        error(err)
      end
      uv.run()
      return final_result
    end)
    return ok, result
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
---@param cwd string?
---@return boolean success
---@return string result_or_error
function M.curl(url, method, headers, cwd)
  local cmd = { "curl", "-sS", "-f", url, "-X", method }
  local i = #cmd
  for _, header in ipairs(headers) do
    i = i + 2
    cmd[i - 1] = "-H"
    cmd[i] = header
  end
  local ok, result = M.run(cmd, cwd)
  if not ok then
    ---@cast result string
    return false, result
  end
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

return M
