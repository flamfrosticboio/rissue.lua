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

---@param buffer rissue.utils.ReadResult
---@param pipe uv.uv_pipe_t
---@param on_complete? fun()
local function handle_read_pipe(pipe, buffer, on_complete)
  pipe:read_start(function(err, data)
    if err then
      buffer.failed = true
    end

    if data then
      buffer.contents = buffer.contents + data
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

--- Creates the process without running `uv.run()`.
--- Use `cmd.run()` to run in one-shot instead
---@async
---@param cmd  string[]
---@return boolean success
---@return string stdout_or_error
function M.spawn(cmd)
  local co = coroutine.running()
  if not co then
    return false, "not inside a coroutine"
  end

  local stdout = create_pipe_with_error()
  local stderr = create_pipe_with_error()

  local result = ""
  local stderr_output = nil
  local read_error_stdout = nil
  local read_error_stderr = nil

  -- track completion state
  local exited = false
  local exit_code = nil
  local stdout_done = false
  local stderr_done = false

  local function maybe_resume()
    if exited and stdout_done and stderr_done then
      coroutine.resume(co, exit_code)
    end
  end

  local exe = cmd[1]
  if not exe then
    error("no binary provided")
  end
  local args = {}
  for i = 2, #cmd do
    args[#args + 1] = cmd[i]
  end

  local options = { args = args, stdio = { nil, stdout, stderr } }

  local handle, _, process_error = uv.spawn(exe, options, function(code)
    exited = true
    exit_code = code
    maybe_resume()
  end)

  if not handle then
    stdout:close()
    stderr:close()
    return false, ("cannot spawn process '%s': %s"):format(cmd, process_error)
  end

  stdout:read_start(function(err, data)
    ---@cast err string?
    if err then
      read_error_stdout = err
      stdout:read_stop()
      stdout:close()
      stdout_done = true
      maybe_resume()
    elseif data then
      result = result .. data
    else
      -- EOF
      stdout:read_stop()
      stdout:close()
      stdout_done = true
      maybe_resume()
    end
  end)

  stderr:read_start(function(err, data)
    ---@cast err string?
    if err then
      read_error_stderr = err
      stderr:read_stop()
      stderr:close()
      stderr_done = true
      maybe_resume()
    elseif data then
      stderr_output = (stderr_output or "") .. data
    else
      -- EOF
      stderr:read_stop()
      stderr:close()
      stderr_done = true
      maybe_resume()
    end
  end)

  local code = coroutine.yield()
  if code ~= 0 then
    return false, stderr_output or read_error_stdout or read_error_stderr or "unknown"
  end
  return true, result
end

--- Runs multiple commands in parallel.
---
--- Returns `true` if all processes exited with return code 0
---
--- Note: Blocking operation
--- Note: This does not capture the output of any of the cmd
--- Note: Handles `uv.run()` automatically
--- Note: Returns an `Error` (recommended to put in a pcall)
---@param cmds string[][]
---@return boolean success, rissue.utils.RunMultipleResults results
function M.run_multiple(cmds)
  ---@type rissue.utils.RunMultipleResults
  local results = {}

  for _, cmd in ipairs(cmds) do
    local exe = cmd[1]
    if not exe then
      error("no binary provided")
    end
    local args = {}
    for j = 2, #cmd do
      args[#args + 1] = cmd[j]
    end

    ---@type rissue.utils.CmdResult
    local result = {
      return_code = -1,
      stdout = { contents = "" },
      stderr = { contents = "" },
    }

    results[cmd] = result

    local stdout = create_pipe_with_error()
    local stderr = create_pipe_with_error()

    handle_read_pipe(stdout, result.stdout)
    handle_read_pipe(stderr, result.stderr)

    local handle
    handle = uv.spawn(
      exe,
      ---@diagnostic disable-next-line: missing-fields
      { args = args, stdio = { nil, stdout, stderr } },
      function(code)
        result.return_code = code
        handle:close()

        if not stdout:is_closing() then
          stdout:close()
        end
        if not stderr:is_closing() then
          stderr:close()
        end
      end
    )

    if not handle then
      error("Failed to spawn process: " .. exe)
    end
  end

  uv.run()

  for _, res in pairs(results) do
    if res.return_code ~= 0 then
      return false, results
    end
  end

  return true, results
end

---@async
---@param url     string
---@param method  rissue.utils.HttpMethod
---@param headers string[]
---@return boolean success
---@return string result_or_error
function M.curl(url, method, headers)
  local cmd = { "curl", "-sS", "-f", url, "-X", method }
  local i = #cmd
  for _, header in ipairs(headers) do
    i = i + 2
    cmd[i - 1] = "-H"
    cmd[i] = header
  end
  return M.spawn(cmd)
end

return M
