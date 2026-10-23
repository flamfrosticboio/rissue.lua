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

local async_mod = require("rissue.utils.async")
local log = require("rissue.utils.log")
local subprocess = require("rissue.utils.process")
local util = require("util")
local uv = require("luv") ---@type uv

local M = {}

---@diagnostic disable-next-line: deprecated
local unpack = table.unpack or unpack

---@async
---@param async rissue.Async
---@param fn fun(...: any)
local function await(async, fn, ...)
  local n = select("#", ...)
  local args = { ... }
  args[n + 1] = function(...)
    async:resume(...)
  end

  fn(unpack(args, 1, n + 1))
  return async:yield()
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
---@field func async fun(a: rissue.Async): string? Where the return value is err_msg

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
---@param async rissue.Async
---@param command __rissue.pipeline.Run
---@return boolean success
---@return string? err_msg
local function run_command(async, command)
  local process = require("rissue.utils.process")

  util.print_status("Attempting to run command: " .. command.bin)

  local result, err = process.run_async(async, {
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
---@param async rissue.Async
---@param args __rissue.pipeline.Rename
---@return boolean success
---@return string? err_msg
local function rename(async, args)
  util.print_status("Renaming '" .. args.source .. "' to '" .. args.dest .. "'")
  local err = await(async, uv.fs_rename, args.source, args.dest)
  if err then
    return false, err
  end
  return true
end

---@async
---@param async rissue.Async
---@param args __rissue.pipeline.CreateDirectory
---@return boolean success
---@return string? err_msg
local function mkdir(async, args)
  local mode = args.mode or 493
  local path = args.path:gsub("\\", "/")

  local root, rest = path:match("^(%a:/?)(.*)$")
  if not root then
    root, rest = path:match("^(/*)(.*)$")
  end

  local cur = root
  for part in rest:gmatch("[^/]+") do
    cur = cur .. part

    local err = await(async, uv.fs_mkdir, cur, mode)
    if err then
      if not err:match("^EEXIST") then
        return false, err
      end

      local serr, stat = await(async, uv.fs_stat, cur)
      if serr or not stat or stat.type ~= "directory" then
        return false, "not a directory: " .. cur
      end
    end

    cur = cur .. "/"
  end

  util.print_status("Directory created at " .. args.path)

  return true
end

---@param func async fun(a: rissue.Async): boolean, string?
---@return boolean success
---@return string? error
local function into_sync(func)
  local done = false
  local backend, wait = async_mod.default_backend()
  local result_ok, res_err
  async_mod.run(
    backend,
    ---@async
    function(a)
      result_ok, res_err = func(a)
      done = true
    end
  )

  local ok, wait_err = wait(function()
    return done
  end, -1)

  if not ok then
    return false, wait_err
  end

  if not result_ok then
    return false, res_err
  end

  return true
end

---@async
---@param async rissue.Async
---@param args __rissue.pipeline.WriteFile
---@return boolean success
---@return string? err_msg
local function write_file(async, args)
  local mode = args.mode or 493

  if args.ensure_directory then
    local dir = args.filepath:match("^(.*)[/\\]")
    if dir and dir ~= "" then
      local success, err =
        mkdir(async, { path = dir, mode = mode, type = "mkdir" })
      if not success then
        return false, err
      end
    end
  end

  local err, fd = await(async, uv.fs_open, args.filepath, "w", mode)
  if err or not fd then
    return false, err
  end

  local werr = await(async, uv.fs_write, fd, args.contents, 0)
  local cerr = await(async, uv.fs_close, fd)

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
    function(a)
      return mkdir(a, { type = "mkdir", path = path, mode = mode })
    end
  )
end

---@async
---@param async rissue.Async
---@param args __rissue.pipeline.RemoveDirectory
---@return boolean success
---@return string? err_msg
local function rmdir(async, args)
  local err, handle = await(async, uv.fs_scandir, args.path)
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
      local lerr, stat = await(async, uv.fs_lstat, child)
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
      local ok, cerr = rmdir(async, {
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
      local uerr = await(async, uv.fs_unlink, child)
      if uerr then
        if args.skip_when_fail then
          print("Warning: failed to delete file: " .. uerr)
          return true
        end
        return false, uerr
      end
    end
  end

  local rerr = await(async, uv.fs_rmdir, args.path)
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
    function(a)
      return rmdir(a, {
        type = "remove_dir",
        path = path,
        skip_when_fail = opts and opts.skip_when_fail,
      })
    end
  )
end

---@async
---@param async rissue.Async
---@param args __rissue.pipeline.RemoveFile
---@return boolean success
---@return string? err_msg
local function rmfile(async, args)
  local err = await(async, uv.fs_unlink, args.path)
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
    function(a)
      return rmfile(a, {
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
    function(a)
      return write_file(a, {
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
---@param async rissue.Async
---@param pipeline __rissue.Pipeline
---@return string? err_msg Error message if available
function M.run_pipeline(async, pipeline)
  local cleanup = {} ---@type __rissue.pipeline.RegisterCleanup[]
  local err = nil ---@type string?

  for _, item in ipairs(pipeline) do
    if item.type == "run" then
      ---@cast item __rissue.pipeline.Run
      local success, run_err = run_command(async, item)
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
      local success, move_err = rename(async, item)
      if not success then
        err = move_err
        break
      end
    elseif item.type == "mkdir" then
      ---@cast item __rissue.pipeline.CreateDirectory
      local success, mkdir_err = mkdir(async, item)
      if not success then
        err = mkdir_err
        break
      end
    elseif item.type == "write_file" then
      ---@cast item __rissue.pipeline.WriteFile
      local success, write_err = write_file(async, item)
      if not success then
        err = write_err
        break
      end
    elseif item.type == "remove_file" then
      ---@cast item __rissue.pipeline.RemoveFile
      local success, rmfile_err = rmfile(async, item)
      if not success then
        err = rmfile_err
        break
      end
    elseif item.type == "remove_dir" then
      ---@cast item __rissue.pipeline.RemoveDirectory
      local success, rmdir_err = rmdir(async, item)
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
      local errmsg = cleanup_op.func(async)
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

local function pipeline_backend_schedule(fn)
  fn()
end

---@param fn async fun(a: rissue.Async)
---@param on_finish fun(err_msg: string?)
local function async_run(fn, on_finish)
  ---@type __rissue.async.Backend
  local backend = {
    schedule = pipeline_backend_schedule,
    on_error = function(msg, tb)
      log.trace(msg .. "\n" .. tb)
      on_finish(msg)
    end,
  }

  async_mod.run(
    backend,
    ---@async
    function(a)
      fn(a)
      on_finish()
    end
  )
end

---@param pipelines __rissue.Pipeline[]
---@param limit integer
---@return string[]? errors
function M.run_pipelines(pipelines, limit)
  --- there can be only on instance of run_pipelines since its blocking. so reusing the
  --- same backend just works

  local err_msgs = {}

  if #pipelines <= 0 then
    return
  end

  limit = math.max(limit, 1)

  local errors = {} ---@type string[]
  local running = 0

  local next_pipeline = util.iterator(pipelines)

  while true do
    -- Wait for a free slot before starting the next pipeline
    if running >= limit then
      subprocess.wait(function()
        return running <= 0
      end, -1, 1000)
    end

    local pipeline = next_pipeline()
    if not pipeline then
      break
    end

    async_run(
      ---@async
      function(a)
        local pipeline_err = M.run_pipeline(a, pipeline)
        if pipeline_err then
          error(pipeline_err)
        end
      end,
      function(err)
        if err then
          err_msgs[#err_msgs + 1] = err
        end
        running = running - 1
      end
    )

    running = running + 1
  end

  -- Wait for everything still running
  subprocess.wait(function()
    return running <= 0
  end, -1, 1000)

  if #errors > 0 then
    return errors
  end
end

return M
