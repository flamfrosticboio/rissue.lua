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

local M = {}

local fn = require("api.setup_utils_fn")
local subprocess = require("rissue.utils.process")
local uv = require("luv") ---@type uv

M.cwd = "./.test_setup"

local CPU_COUNT = tonumber(os.getenv("CORES"))
if not CPU_COUNT then
  local cpus = uv.cpu_info()
  CPU_COUNT = cpus and #cpus or 1
end

local log = require("rissue.utils.log")
log.log_level = log.levels.debug

---@class __rissue._CmdResult: rissue.utils.CmdResult
---@field cmd string[]

---@param pipelines __rissue.Pipeline[]
---@param limit integer
---@return string[]? errors
local function run_pipelines(pipelines, limit)
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

  local next_pipeline = fn.iterator(pipelines)

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
        result.err = fn.run_pipeline(pipeline)
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

---@param id string
---@param folder string folder path
---@param duration number duration in seconds
---@return boolean cache_is_valid
function M.handle_caching(id, folder, duration)
  local marker_path = M.cwd .. "/cache-marker-" .. id
  local folder_path = M.cwd .. "/" .. folder
  local f, _ = io.open(marker_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    content = tonumber(content)
    if content and os.time() - content <= duration then
      return true
    end

    local folder_stat = uv.fs_stat(folder_path)
    if folder_stat and folder_stat.type == "directory" then
      local ok, errmsg = fn.rmdir(folder_path)
      if not ok then
        error(("Failed to delete folder %s: %s"):format(folder_path, errmsg), 0)
      end
      print("Removed old setup folder: " .. folder_path)
    end
  end

  print("Warning: No cache file found. Running full setup...")
  local ok, err_msg = fn.mkdir(M.cwd)
  if not ok then
    error("Failed to make directory: " .. err_msg, 0)
  end

  ok, err_msg = fn.write_file(marker_path, tostring(os.time()))
  if not ok then
    error("Failed to write cache marker path: " .. err_msg, 0)
  end

  return false
end

---@param pipelines __rissue.Pipeline[]
---@param cwd string The current working directory
function M.run_setup(cwd, pipelines)
  -- run luv without blocking
  uv.run("nowait")
  local ok, err = fn.mkdir(cwd)
  if not ok then
    error(err, 0)
  end

  local err_msg = run_pipelines(pipelines, CPU_COUNT)
  if err_msg then
    print(
      "\n\nError: An error occurred while running pipelines:\n\t"
        .. table.concat(err_msg, "\n\t")
    )
  end

  print("Done")
end

---@param path string
---@return __rissue.pipeline.CreateDirectory
function M.p_new_dir(path)
  ---@type __rissue.pipeline.CreateDirectory
  return { type = "mkdir", path = path }
end

---@class __rissue.pipeline.run.Opts
--- If `skip_when_file_exists` is passed, the `true` will be replaced
--- with the value of `skip_when_file_exists`
---@field args? (string|true)[]
---@field cwd? string
---@field env? table<string, string?>
--- Skips when file exists in the specified directory
--- Default: none
---@field skip_when_file_exists? string

---@param bin string
---@param opts __rissue.pipeline.run.Opts
---@return __rissue.pipeline.Run | __rissue.pipeline.Operation
function M.p_run(bin, opts)
  if opts then
    local filepath = opts.skip_when_file_exists
    if filepath then
      local stat = uv.fs_stat(filepath)
      if stat and stat.type == "file" then
        print("Skipping file: " .. filepath)
        ---@type __rissue.pipeline.Operation
        return { type = "op", should_continue = false }
      end
    end
  end
  ---@type __rissue.pipeline.Run
  return {
    type = "run",
    bin = bin,
    args = opts and opts.args,
    cwd = opts and opts.cwd,
    env = opts and opts.env,
  }
end

---@param source string
---@param dest string
---@return __rissue.pipeline.Rename
function M.p_rename(source, dest)
  ---@type __rissue.pipeline.Rename
  return { type = "rename", source = source, dest = dest }
end

---@param func async fun(): string? Where the return of the function is error message
---@return __rissue.pipeline.RegisterCleanup
function M.p_register_cleanup(func)
  ---@type __rissue.pipeline.RegisterCleanup
  return { type = "reg_cleanup", func = func }
end

---@param path string
---@param opts? { skip_when_fail: boolean? }
---@return __rissue.pipeline.RemoveDirectory
function M.p_rmdir(path, opts)
  ---@type __rissue.pipeline.RemoveDirectory
  return {
    type = "remove_dir",
    path = path,
    skip_when_fail = opts and opts.skip_when_fail,
  }
end

---@param path string
---@param opts? { skip_when_fail: boolean? }
---@return __rissue.pipeline.RemoveFile
function M.p_rmfile(path, opts)
  ---@type __rissue.pipeline.RemoveFile
  return {
    type = "remove_file",
    path = path,
    skip_when_fail = opts and opts.skip_when_fail,
  }
end

---@param condition fun(): boolean
---@return __rissue.pipeline.Operation
function M.p_op(condition)
  ---@type __rissue.pipeline.Operation
  return { type = "op", should_continue = condition }
end

---@param filepath string
---@param contents string
---@return __rissue.pipeline.WriteFile
function M.p_write_f(filepath, contents)
  ---@type __rissue.pipeline.WriteFile
  return { type = "write_file", filepath = filepath, contents = contents }
end

return M
