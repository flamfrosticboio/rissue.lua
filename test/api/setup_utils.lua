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

--- A bunch of functions that is used frequently in `setup_utils.lua`

local subprocess = require("rissue.utils.process")
local util = require("util")
local uv = require("luv") ---@type uv

local M = {}

---@diagnostic disable-next-line: deprecated
local unpack = table.unpack or unpack

---@async
local function await(fn, ...)
  local co = coroutine.running()
  local n = select("#", ...)
  local args = { ... }
  args[n + 1] = function(...)
    local status = coroutine.status(co)
    if status == "suspended" then
      local ok, err = coroutine.resume(co, ...)
      if not ok then
        error(debug.traceback(co, err), 0)
      end
    else
      print("Warning: Coroutine is not suspended, but " .. status)
    end
  end

  fn(unpack(args, 1, n + 1))
  return coroutine.yield()
end

---@class __rissue.pipeline._base<T>
---@field type T

---@class __rissue.pipeline.Run: __rissue.pipeline._base<"run">
---@field bin string
---@field args? string[]
---@field env? table<string, string?>
---@field cwd? string

---@class __rissue.pipeline.Operation: __rissue.pipeline._base<"op">
---@field should_continue boolean | fun(): boolean

---@class __rissue.pipeline.RegisterCleanup: __rissue.pipeline._base<"reg_cleanup">
---@field func async fun(): string? Where the return value is err_msg

---@class __rissue.pipeline.Rename: __rissue.pipeline._base<"rename">
---@field source string
---@field dest string

---@class __rissue.pipeline.CreateDirectory: __rissue.pipeline._base<"mkdir">
---@field path string
---@field mode? integer in decimal (e.g. 0755 octal = 493 decimal)

---@class __rissue.pipeline.WriteFile: __rissue.pipeline._base<"write_file">
---@field filepath string
---@field contents string
---@field ensure_directory? boolean
---@field mode integer?

---@class __rissue.pipeline.RemoveFile: __rissue.pipeline._base<"remove_file">
---@field path string
---@field skip_when_fail? boolean

---@class __rissue.pipeline.RemoveDirectory: __rissue.pipeline._base<"remove_dir">
---@field path string
---@field skip_when_fail? boolean

---@alias __rissue.PipelineCommands
---| __rissue.pipeline.Run
---| __rissue.pipeline.Rename
---| __rissue.pipeline.RegisterCleanup
---| __rissue.pipeline.CreateDirectory
---| __rissue.pipeline.Operation
---| __rissue.pipeline.WriteFile
---| __rissue.pipeline.RemoveFile
---| __rissue.pipeline.RemoveDirectory

---@alias __rissue.Pipeline __rissue.PipelineCommands[]

---@async
---@param command __rissue.pipeline.Run
---@return boolean success
---@return string? err_msg
local function run_command(command)
  local process = require("rissue.utils.process")

  util.print_status("Attempting to run command: " .. command.bin)

  local result, err = process.run_co({
    cmd = command.bin,
    args = command.args,
    env = command.env,
    cwd = command.cwd,
  }, {
    print_output = true,
  })

  if not result then
    return false, err
  end

  if result.return_code ~= 0 then
    return false,
      table.concat({
        "Failed to run: Process exited with code ",
        result.return_code,
        "\nStderr: \n",
        result.stderr,
        "\nStdout: \n",
        result.stdout,
      })
  end

  return true
end

---@async
---@param args __rissue.pipeline.Rename
---@return boolean success
---@return string? err_msg
local function rename(args)
  util.print_status("Renaming '" .. args.source .. "' to '" .. args.dest .. "'")
  local err = await(uv.fs_rename, args.source, args.dest)
  if err then
    return false, err
  end
  return true
end

---@async
---@param args __rissue.pipeline.CreateDirectory
---@return boolean success
---@return string? err_msg
local function mkdir(args)
  local mode = args.mode or 493
  local path = args.path:gsub("\\", "/")

  local root, rest = path:match("^(%a:/?)(.*)$")
  if not root then
    root, rest = path:match("^(/*)(.*)$")
  end

  local cur = root
  for part in rest:gmatch("[^/]+") do
    cur = cur .. part

    local err = await(uv.fs_mkdir, cur, mode)
    if err then
      if not err:match("^EEXIST") then
        return false, err
      end

      local serr, stat = await(uv.fs_stat, cur)
      if serr or not stat or stat.type ~= "directory" then
        return false, "not a directory: " .. cur
      end
    end

    cur = cur .. "/"
  end

  util.print_status("Directory created at " .. args.path)

  return true
end

---@param func async fun(): boolean, string?
---@return boolean success
---@return string? error
local function into_sync(func)
  local done = false
  local co = coroutine.create(
    ---@async
    function()
      local success, err = func()
      done = true
      if not success then
        error(err)
      end
    end
  )

  if coroutine.status(co) == "suspended" then
    local ok, err = coroutine.resume(co)
    if not ok then
      return false, err
    end
  end

  local ok, err = subprocess.wait(function()
    return done
  end, -1)

  if not ok then
    return false, err
  end

  return true
end

---@async
---@param args __rissue.pipeline.WriteFile
---@return boolean success
---@return string? err_msg
local function write_file(args)
  local mode = args.mode or 493

  if args.ensure_directory then
    local dir = args.filepath:match("^(.*)[/\\]")
    if dir and dir ~= "" then
      local success, err = mkdir({ path = dir, mode = mode, type = "mkdir" })
      if not success then
        return false, err
      end
    end
  end

  local err, fd = await(uv.fs_open, args.filepath, "w", mode)
  if err or not fd then
    return false, err
  end

  local werr = await(uv.fs_write, fd, args.contents, 0)
  local cerr = await(uv.fs_close, fd)

  if werr then
    return false, werr
  end
  if cerr then
    return false, cerr
  end

  util.print_status("Wrote contents to " .. args.filepath)
  return true
end

---@param path string
---@param mode integer?
---@return boolean success
---@return string? err_msg
function M.mkdir(path, mode)
  return into_sync(
    ---@async
    function()
      return mkdir({ type = "mkdir", path = path, mode = mode })
    end
  )
end

---@async
---@param args __rissue.pipeline.RemoveDirectory
---@return boolean success
---@return string? err_msg
local function rmdir(args)
  local err, handle = await(uv.fs_scandir, args.path)
  if err or not handle then
    if args.skip_when_fail then
      print("Warning: failed to scan directory: " .. err)
      return true
    end
    return false, err
  end

  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local child = args.path .. "/" .. name

    if not typ then
      local lerr, stat = await(uv.fs_lstat, child)
      if lerr or not stat then
        if args.skip_when_fail then
          print("Warning: failed to get stat: " .. lerr)
          return true
        end
        return false, lerr
      end
      typ = stat.type
    end

    if typ == "directory" then
      local ok, cerr = rmdir({
        type = "remove_dir",
        path = child,
        skip_when_fail = args.skip_when_fail,
      })
      if not ok then
        if args.skip_when_fail then
          print("Warning: failed to delete directory: " .. cerr)
          return true
        end
        return false, cerr
      end
    else
      local uerr = await(uv.fs_unlink, child)
      if uerr then
        if args.skip_when_fail then
          print("Warning: failed to delete file: " .. uerr)
          return true
        end
        return false, uerr
      end
    end
  end

  local rerr = await(uv.fs_rmdir, args.path)
  if rerr then
    return false, rerr
  end

  util.print_status("Removed directory: " .. args.path)
  return true
end

---@param path string
---@param opts? {skip_when_fail:  boolean?}
---@return boolean success
---@return string? err_msg
function M.rmdir(path, opts)
  return into_sync(
    ---@async
    function()
      return rmdir({
        type = "remove_dir",
        path = path,
        skip_when_fail = opts and opts.skip_when_fail,
      })
    end
  )
end

---@async
---@param args __rissue.pipeline.RemoveFile
---@return boolean success
---@return string? err_msg
local function rmfile(args)
  local err = await(uv.fs_unlink, args.path)
  if err then
    if args.skip_when_fail then
      return true
    end
    return false, err
  end
  util.print_status("Removed file: " .. args.path)
  return true
end

---@param path string
---@param opts? {skip_when_fail: boolean?}
---@return boolean success
---@return string? err_msg
function M.rmfile(path, opts)
  return into_sync(
    ---@async
    function()
      return rmfile({
        type = "remove_file",
        path = path,
        skip_when_fail = opts and opts.skip_when_fail,
      })
    end
  )
end

---@param path string
---@param contents string
---@param opts? {ensure_directory: boolean?, mode: integer?}
---@return boolean success
---@return string? err_msg
function M.write_file(path, contents, opts)
  return into_sync(
    ---@async
    function()
      return write_file({
        type = "write_file",
        contents = contents,
        filepath = path,
        ensure_directory = opts and opts.ensure_directory,
        mode = opts and opts.mode,
      })
    end
  )
end

---@async
---@param pipeline __rissue.Pipeline
---@return string? err_msg Error message if available
function M.run_pipeline(pipeline)
  local cleanup = {} ---@type __rissue.pipeline.RegisterCleanup[]
  local err = nil ---@type string?

  for _, item in ipairs(pipeline) do
    if item.type == "run" then
      ---@cast item __rissue.pipeline.Run
      local success, run_err = run_command(item)
      if not success then
        err = run_err
        break
      end
    elseif item.type == "reg_cleanup" then
      ---@cast item __rissue.pipeline.RegisterCleanup
      table.insert(cleanup, item)
      util.print_status("Added cleanup item")
    elseif item.type == "rename" then
      ---@cast item __rissue.pipeline.Rename
      local success, move_err = rename(item)
      if not success then
        err = move_err
        break
      end
    elseif item.type == "mkdir" then
      ---@cast item __rissue.pipeline.CreateDirectory
      local success, mkdir_err = mkdir(item)
      if not success then
        err = mkdir_err
        break
      end
    elseif item.type == "write_file" then
      ---@cast item __rissue.pipeline.WriteFile
      local success, write_err = write_file(item)
      if not success then
        err = write_err
        break
      end
    elseif item.type == "remove_file" then
      ---@cast item __rissue.pipeline.RemoveFile
      local success, rmfile_err = rmfile(item)
      if not success then
        err = rmfile_err
        break
      end
    elseif item.type == "remove_dir" then
      ---@cast item __rissue.pipeline.RemoveDirectory
      local success, rmdir_err = rmdir(item)
      if not success then
        err = rmdir_err
        break
      end
    elseif item.type == "op" then
      local should_continue = item.should_continue
      if type(should_continue) == "function" then
        should_continue = should_continue()
      end

      if not should_continue then
        util.print_status("Stopping pipeline...")
        break
      end
    else
      error("Unknown type: " .. tostring(item.type), 0)
    end
  end

  if #cleanup > 0 then
    util.print_status("Running cleanup")
    for _, cleanup_op in ipairs(cleanup) do
      local errmsg = cleanup_op.func()
      if errmsg then
        print("Failed when running cleanup: " .. errmsg)
        if not err then
          err = ""
        end
        err = err .. "\n\t" .. errmsg
      end
    end
    util.print_status("Cleanup complete!")
  end

  if err then
    print("!!! " .. err)
  end

  return err
end

---@param pipelines __rissue.Pipeline[]
---@param limit integer
---@return string[]? errors
function M.run_pipelines(pipelines, limit)
  if #pipelines <= 0 then
    return
  end

  limit = math.max(limit, 1)

  local errors = {} ---@type string[]
  local running = {} ---@type {co: thread, result: {done: boolean, err: string?}}[]

  --- Removes finished tasks and collects their errors
  local function reap()
    for i = #running, 1, -1 do
      local task = running[i]
      if task.result.done or coroutine.status(task.co) == "dead" then
        if task.result.err then
          table.insert(errors, task.result.err)
        end
        table.remove(running, i)
      end
    end
  end

  local next_pipeline = util.iterator(pipelines)

  while true do
    -- Wait for a free slot before starting the next pipeline
    if #running >= limit then
      subprocess.wait(function()
        reap()
        return #running < limit
      end, -1)
    end

    local pipeline = next_pipeline()
    if not pipeline then
      break
    end

    local result = { done = false } ---@type {done: boolean, err: string?}
    local co = coroutine.create(
      ---@async
      function()
        result.err = M.run_pipeline(pipeline)
        result.done = true
      end
    )

    local ok, err = coroutine.resume(co)
    if not ok then
      result.err = tostring(err)
      result.done = true
    end

    table.insert(running, { co = co, result = result })
    reap()
  end

  -- Wait for everything still running
  subprocess.wait(function()
    reap()
    return #running == 0
  end, -1)

  if #errors > 0 then
    return errors
  end
end

return M
