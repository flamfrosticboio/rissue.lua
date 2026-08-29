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

local M = {}

local fn = require("api.setup_utils_fn")
local subprocess = require("rissue.utils.process")
local uv = require("luv") ---@type uv

M.cwd = "./.test_setup"

local CPU_COUNT = tonumber(os.getenv("CPU"))
if not CPU_COUNT then
  local cpus = uv.cpu_info()
  CPU_COUNT = cpus and #cpus or 1
end

---@class __rissue.SetupConfigOptions.cache
---@field ttl integer
---@field name string
---@field folder string

---@class __rissue.SetupConfigOptions
---@field cache? __rissue.SetupConfigOptions.cache
---@field cwd string

---@alias __rissue.setup.Type __rissue.setup.type.File | __rissue.setup.type.Command

---@alias __rissue.SetupConfig __rissue.setup.Type[] | __rissue.SetupConfigOptions

---@class __rissue._CmdResult: rissue.utils.CmdResult
---@field cmd string[]

---@param cmds rissue.cmd[]
---@param process_limit integer
---@return __rissue._CmdResult[], string[]
function M.run_multiple(cmds, process_limit)
  if #cmds <= 0 then
    return {}, {}
  end

  local errors = {} ---@type string[]
  local results = {} ---@type __rissue._CmdResult[]
  local total = #cmds
  local finished = 0
  local running = 0
  local pointer = 0

  while finished < total do
    while pointer < total do
      --- Get next cmd to run
      pointer = pointer + 1
      local command = cmds[pointer]
      local id = pointer

      assert(command[1], "No binary passed")

      local args = {}
      for i = 2, #command do
        args[#args + 1] = command[i]
      end

      local process, err = subprocess.spawn({ cmd = command[1], args = args })
      if not process then
        error(err)
      end

      process:register_event("on_stdout", function()
        print(
          fn.ccolor(("[%03d] | "):format(id), id)
            .. process:get_last_stdout(true):gsub("\n", fn.ccolor("\n^| ", id))
        )
      end)
      process:register_event("on_stderr", function()
        print(
          fn.ccolor(("[%03d] @ "):format(id), id)
            .. process:get_last_stderr(true):gsub("\n", fn.ccolor("\n^@ ", id))
        )
      end)
      process:register_event("on_exit", function()
        finished = finished + 1
        running = running - 1

        results[id] = {
          return_code = process:get_code(),
          stdout = process:get_stdout(),
          stderr = process:get_stderr(),
          cmd = command,
        }

        fn.print_shell(command, ("[%d/%d][DONE]: "):format(finished, total), true)
      end)

      process:run()
      running = running + 1

      subprocess.wait(function()
        return running < process_limit
      end, -1, 100)
    end

    -- final wait
    subprocess.wait(function()
      return finished >= total
    end, -1, 100)
  end

  for _, result in ipairs(results) do
    if result.return_code ~= 0 then
      local contents = result.stderr ~= "" and result.stderr or result.stdout
      errors[#errors + 1] = (
        "failed to run '"
        .. table.concat(result.cmd, " ")
        .. "':\n"
        .. contents
      )
    end
  end

  return results, errors
end

---@class __rissue.setup.type.Command
---@field type "command"
---@field file string
---@field bin string
---@field args string[]

---@param file string? File to check (caching). Pass nil if this is not applicable
---@param binary string
---@param args (string | true)[]?
---@return __rissue.setup.type.Command
function M.setup_command(file, binary, args)
  args = fn.replace_in_list(args or {}, true, file)
  return { file = file, bin = binary, args = args, type = "command" }
end

---@class __rissue.setup.type.File
---@field file string
---@field contents string
---@field type "file"

---@param file string File to write. Note that it will not write if the file exists
---@param contents string
---@return __rissue.setup.type.File
function M.setup_file(file, contents)
  return { file = file, contents = contents, type = "file" }
end

---@param cache __rissue.SetupConfigOptions.cache
local function handle_cache(cache)
  local marker_path = M.cwd .. "/cache-marker-" .. cache.name
  local f, _ = io.open(marker_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    content = tonumber(content)
    if content and os.time() - content > cache.ttl then
      local ok, err = fn.rmdir(cache.folder)
      if not ok then
        print("Warning: failed to delete expired cached folder: " .. err)
      end
      os.remove(marker_path)
    end
  else
    print("WARNING: No cache file found")
    local err
    f, err = io.open(marker_path, "w")
    if not f then
      -- if I can't write cache, then there is a problem
      error(err)
    end

    local _, ferr = f:write(tostring(os.time()))
    f:close()
    if ferr then
      print("Warning: failed to write to cache file: " .. ferr)
    end
  end
end

---@class __rissue.run_setup_config.Result
---@field files_processed string[]
---@field files_failed string[]

---@param configs __rissue.SetupConfig
---@return __rissue.run_setup_config.Result
local function run_setup_config(configs)
  if configs.cache then
    handle_cache(configs.cache)
  end

  local files_affected = {} ---@type string[]
  local files_failed = {} ---@type string
  local commands_to_execute = {} ---@type rissue.cmd[]
  local command_file_map = {} ---@type table<rissue.cmd[], string>
  local files_to_write = {} ---@type __rissue.setup.type.File[]

  for _, config in ipairs(configs) do
    if not (config.file and uv.fs_stat(config.file)) then
      if config.type == "command" then
        local args = fn.replace_in_list(config.args, true, config.file)
        local cmd = { config.bin, unpack(args) }
        commands_to_execute[#commands_to_execute + 1] = cmd
        command_file_map[cmd] = config.file
      elseif config.type == "file" then
        files_to_write[#files_to_write + 1] = config
      else
        error("unknown config")
      end
    else
      print("Skipping file: " .. config.file)
    end
  end

  for _, config in ipairs(files_to_write) do
    local fd = uv.fs_open(config.file, "w", tonumber("644", 8))
    if fd then
      uv.fs_write(fd, config.contents)
      uv.fs_close(fd)
    end
    files_affected[#files_affected + 1] = config.file
    print("Wrote file: " .. config.file)
  end

  local results, errors = M.run_multiple(commands_to_execute, CPU_COUNT)

  if #errors > 0 then
    print(table.concat(errors, "\n"))
  end

  for _, result in ipairs(results) do
    local cmd = command_file_map[result.cmd]
    if result.return_code ~= 0 then
      files_affected[#files_affected + 1] = cmd
    else
      files_failed[#files_failed + 1] = cmd
    end
  end

  return files_affected
end

---@param cwd string The current working directory
---@param setup_config __rissue.SetupConfig
---@return __rissue.run_setup_config.Result
function M.run_setup(cwd, setup_config)
  -- run luv without blocking
  uv.run("nowait")
  fn.mkdir(cwd)
  local files_affected = run_setup_config(setup_config)
  print("Done")
  return files_affected
end

return M
