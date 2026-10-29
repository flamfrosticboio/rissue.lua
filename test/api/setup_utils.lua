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
---@field func async fun(a: rissue.Async, limiters: __rissue.Limiters): string? Where the return value is err_msg

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

---@alias __rissue.pipeline.SwitchMode.mode "io" | "cpu"

---@class __rissue.pipeline.SwitchMode: __rissue.pipeline._base<"switch_mode">
---@field mode __rissue.pipeline.SwitchMode.mode

---@class __rissue.pipeline.AsyncStep: __rissue.pipeline._base<"async_step">
---@field cb fun(done: fun(err_msg?: string), ctx: __rissue.pipeline.context)

---@alias __rissue.PipelineCommands
---| __rissue.pipeline.Run
---| __rissue.pipeline.Rename
---| __rissue.pipeline.RegisterCleanup
---| __rissue.pipeline.CreateDirectory
---| __rissue.pipeline.Operation
---| __rissue.pipeline.WriteFile
---| __rissue.pipeline.RemoveFile
---| __rissue.pipeline.RemoveDirectory
---| __rissue.pipeline.SwitchMode
---| __rissue.pipeline.AsyncStep

---@alias __rissue.Pipeline __rissue.PipelineCommands[]

---@class __rissue.FIFOLimiter
---@field n integer
---@field used integer
---@field waiters fun()[]

---@class __rissue.Limiters
---@field io __rissue.FIFOLimiter
---@field cpu __rissue.FIFOLimiter

---@class __rissue.pipeline.context
---@field print_context __rissue.PrintStatus.Opts?

---@async
---@param async rissue.Async
---@param command __rissue.pipeline.Run
---@param context? __rissue.pipeline.context
---@return boolean success
---@return string? err_msg
local function run_command(async, command, context)
  local process = require("rissue.utils.process")

  util.print_status(
    "Attempting to run command: " .. command.bin,
    context and context.print_context
  )

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
---@param context __rissue.pipeline.context?
---@return boolean success
---@return string? err_msg
local function rename(async, args, context)
  local err = await(async, uv.fs_rename, args.source, args.dest)
  if err then
    return false, err
  end

  util.print_status(
    "Renamed '" .. args.source .. "' to '" .. args.dest .. "'",
    context and context.print_context
  )

  return true
end

---@async
---@param async rissue.Async
---@param args __rissue.pipeline.CreateDirectory
---@param context __rissue.pipeline.context?
---@return boolean success
---@return string? err_msg
local function mkdir(async, args, context)
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

  util.print_status(
    "Directory created at " .. args.path,
    context and context.print_context
  )

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
---@param context? __rissue.pipeline.context
---@return boolean success
---@return string? err_msg
local function write_file(async, args, context)
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

  util.print_status(
    "Wrote contents to " .. args.filepath,
    context and context.print_context
  )
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
---@param context? __rissue.pipeline.context
---@return boolean success
---@return string? err_msg
local function rmdir(async, args, context)
  local err, handle = await(async, uv.fs_scandir, args.path)
  if err or not handle then
    if args.skip_when_fail then
      log.warn("Warning: failed to scan directory: " .. err)
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
          log.warn("Warning: failed to get stat: " .. lerr)
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
          log.warn("Warning: failed to delete directory: " .. cerr)
          return true
        end
        return false, cerr
      end
    else
      local uerr = await(async, uv.fs_unlink, child)
      if uerr then
        if args.skip_when_fail then
          log.warn("Warning: failed to delete file: " .. uerr)
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

  util.print_status(
    "Removed directory: " .. args.path,
    context and context.print_context
  )
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
---@param context? __rissue.pipeline.context
---@return boolean success
---@return string? err_msg
local function rmfile(async, args, context)
  local err = await(async, uv.fs_unlink, args.path)
  if err then
    if args.skip_when_fail then
      return true
    end
    return false, err
  end
  util.print_status(
    "Removed file: " .. args.path,
    context and context.print_context
  )
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

local function new_limiter(n)
  return { n = math.max(n, 1), used = 0, waiters = {} }
end

---@param lim __rissue.FIFOLimiter
local function release(lim)
  local next_cb = table.remove(lim.waiters, 1)
  if next_cb then
    next_cb() -- hand the slot over directly; used stays the same
  else
    lim.used = lim.used - 1
  end
end

---@async
---@param async rissue.Async
local function acquire_async(async, lim)
  if lim.used < lim.n then
    lim.used = lim.used + 1
    return
  end
  -- no free slot: queue a resume callback and suspend
  async:wrap(function(resume) -- placeholder name for your suspend primitive
    lim.waiters[#lim.waiters + 1] = resume
  end)

  -- when resumed, release() has already handed us the slot
end

---@async
---@param async rissue.Async
---@param pipeline __rissue.Pipeline
---@param limiters __rissue.Limiters
---@return string? err_msg Error message if available
function M.run_pipeline(async, pipeline, limiters)
  local cleanup = {} ---@type __rissue.pipeline.RegisterCleanup[]
  local err = nil ---@type string?
  local current_limiter = limiters.io ---@type __rissue.FIFOLimiter
  acquire_async(async, current_limiter)

  local metadata = getmetatable(pipeline)
  local name = metadata and metadata.name or "??"
  local color = metadata and metadata.color

  ---@type __rissue.pipeline.context
  local context = {
    print_context = {
      name = name, -- note: modified on every step in pipeline below
      color = color,
    },
  }

  for __step, item in ipairs(pipeline) do
    local step_name = name .. ":" .. tostring(__step)
    context.print_context.name = step_name

    if item.type == "run" then
      ---@cast item __rissue.pipeline.Run
      local success, run_err = run_command(async, item, context)
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
      local success, move_err = rename(async, item, context)
      if not success then
        err = move_err
        break
      end
    elseif item.type == "mkdir" then
      ---@cast item __rissue.pipeline.CreateDirectory
      local success, mkdir_err = mkdir(async, item, context)
      if not success then
        err = mkdir_err
        break
      end
    elseif item.type == "write_file" then
      ---@cast item __rissue.pipeline.WriteFile
      local success, write_err = write_file(async, item, context)
      if not success then
        err = write_err
        break
      end
    elseif item.type == "remove_file" then
      ---@cast item __rissue.pipeline.RemoveFile
      local success, rmfile_err = rmfile(async, item, context)
      if not success then
        err = rmfile_err
        break
      end
    elseif item.type == "remove_dir" then
      ---@cast item __rissue.pipeline.RemoveDirectory
      local success, rmdir_err = rmdir(async, item, context)
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
        util.print_status("Stopping pipeline...", context.print_context)
        break
      end
    elseif item.type == "async_step" then
      local async_step_err = async:wrap(function(cb)
        item.cb(cb, context)
      end)
      if async_step_err then
        err = tostring(async_step_err)
        break
      end
    elseif item.type == "switch_mode" then
      local limiter = limiters[item.mode]
      if not limiter then
        err = "Invalid mode: " .. tostring(item.mode)
        break
      end

      if limiter ~= current_limiter then
        release(current_limiter) -- release first, to avoid deadlock
        acquire_async(async, limiter)
        current_limiter = limiter
      end
    else
      err = "Unknown type: " .. tostring(item.type)
      break
    end
  end

  release(current_limiter)

  if #cleanup > 0 then
    context.print_context.name = name .. ":cleanup"
    util.print_status("Running cleanup", context.print_context)
    for cleanup_id, cleanup_op in ipairs(cleanup) do
      local errmsg = cleanup_op.func(async, limiters)
      if errmsg then
        log.error("Failed when running cleanup: " .. errmsg)
        err = (err and (err .. "\n") or "")
          .. "["
          .. tostring(cleanup_id)
          .. "]"
          .. errmsg
      end
    end
    util.print_status("Cleanup complete!", context.print_context)
  end

  if err then
    log.error("Pipeline failed: " .. err)
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
      msg = tostring(msg)
      log.trace(msg .. "\n" .. tostring(tb))
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

---@class __rissue.RunPipelines.Opts
---@field io_limit integer
---@field cpu_limit integer

---@param pipelines __rissue.Pipeline[]
---@param opts __rissue.RunPipelines.Opts
---@return string[]? errors
function M.run_pipelines(pipelines, opts)
  --- there can be only on instance of run_pipelines since its blocking. so reusing the
  --- same backend just works

  if #pipelines <= 0 then
    return
  end

  local io_limit = math.max(opts.io_limit, 1)
  local cpu_limit = math.max(opts.cpu_limit, 1)
  local inflight_limit = io_limit + cpu_limit

  local limiters = {
    io = new_limiter(io_limit),
    cpu = new_limiter(cpu_limit),
  }

  local errors = {} ---@type string[]
  local running = 0

  local next_pipeline = util.iterator(pipelines)

  while true do
    -- Wait for a free slot before starting the next pipeline
    if running >= inflight_limit then
      subprocess.wait(function()
        return running < inflight_limit
      end, -1, 1000)
    end

    local pipeline = next_pipeline()
    if not pipeline then
      break
    end

    running = running + 1
    async_run(
      ---@async
      function(a)
        local pipeline_err = M.run_pipeline(a, pipeline, limiters)
        if pipeline_err then
          error(pipeline_err)
        end
      end,
      function(err)
        if err then
          local metadata = getmetatable(pipeline)
          local name = metadata and metadata.name or "??"
          local color = metadata and metadata.color or ""

          errors[#errors + 1] = ("%s[%s]: %s%s"):format(
            color,
            name,
            err,
            util.ANSI_RESET
          )
        end
        running = running - 1
      end
    )
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
