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

local subprocess = require("rissue.utils.process")
local uv = require("luv") ---@type uv

M.cwd = "./.test_setup"

---@class __rissue.SetupConfigOptions.cache
---@field ttl integer
---@field name string
---@field folder string

---@class __rissue.SetupConfigOptions
---@field cache? __rissue.SetupConfigOptions.cache
---@field cwd string

---@alias __rissue.setup.Type __rissue.setup.type.File | __rissue.setup.type.Command

---@alias __rissue.SetupConfig __rissue.setup.Type[] | __rissue.SetupConfigOptions

---@generic T: any, A: any, B: any
---@param list (T | A)[]
---@param from A
---@param to B
---@return (T | B)[]
local function replace_in_list(list, from, to)
  local result = {}
  for i = 1, #list do
    if list[i] == from then
      result[i] = to
    else
      result[i] = list[i]
    end
  end
  return result
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

---@class __rissue._CmdResult: rissue.utils.CmdResult
---@field cmd string[]

---@param cmds rissue.cmd[]
---@return __rissue._CmdResult[], string[]
function M.run_multiple(cmds)
  local errors = {} ---@type string[]
  local results = {} ---@type __rissue._CmdResult[]
  local total = #cmds
  local finished = 0

  ---@type rissue.utils.Process[]
  local processes = {}
  for j, command in ipairs(cmds) do
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
      print(tostring(j) .. "| " .. process:get_last_stdout(true))
    end)
    process:register_event("on_stderr", function()
      print(tostring(j) .. "E " .. process:get_last_stderr(true))
    end)
    process:register_event("on_exit", function()
      finished = finished + 1
      for i = 1, #command do
        command[i] = shell_escape(command[i])
      end
      print(
        tostring(finished)
          .. "/"
          .. tostring(total)
          .. ": "
          .. table.concat(command, " ")
      )

      results[j] = {
        return_code = process:get_code(),
        stdout = process:get_stdout(),
        stderr = process:get_stderr(),
        cmd = command,
      }
    end)
    processes[j] = process
  end

  for _, process in ipairs(processes) do
    process:run()
  end

  subprocess.wait(function()
    return finished >= total
  end, -1)

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

local function mkdir_p(path)
  -- normalize trailing slash
  path = path:gsub("/$", "")

  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return true -- already exists
  end

  local parent = path:match("^(.*)/[^/]+$")
  if parent and parent ~= "" then
    local ok, err = mkdir_p(parent) -- recurse into parent first
    if not ok then
      return nil, err
    end
  end

  local ok, err, errname = uv.fs_mkdir(path, tonumber("755", 8))
  if not ok and errname ~= "EEXIST" then
    return nil, err
  end
  return true
end

local function rmdir_recursive(path)
  local fd, err = uv.fs_scandir(path)
  if not fd then
    return false, err
  end

  while true do
    local name, typ = uv.fs_scandir_next(fd)
    if not name then
      break
    end

    local full_path = path .. "/" .. name
    if typ == "directory" then
      local ok, e = rmdir_recursive(full_path)
      if not ok then
        return false, e
      end
    else
      local ok, e = uv.fs_unlink(full_path)
      if not ok then
        return false, e
      end
    end
  end

  return uv.fs_rmdir(path)
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
  args = replace_in_list(args or {}, true, file)
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

---@param configs __rissue.SetupConfig
local function run_setup_config(configs)
  if configs.cache then
    local marker_path = M.cwd .. "/cache-marker-" .. configs.cache.name
    local f, _ = io.open(marker_path, "r")
    if f then
      local content = f:read("*a")
      f:close()
      content = tonumber(content)
      if content and os.time() - content > configs.cache.ttl then
        local ok, err = rmdir_recursive(configs.cache.folder)
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

  ---@type rissue.cmd[]
  local commands_to_execute = {}
  ---@type __rissue.setup.type.File[]
  local files_to_write = {}

  for _, config in ipairs(configs) do
    if not (config.file and uv.fs_stat(config.file)) then
      if config.type == "command" then
        local args = replace_in_list(config.args, true, config.file)
        commands_to_execute[#commands_to_execute + 1] = { config.bin, unpack(args) }
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
    print("Wrote file: " .. config.file)
  end

  -- just for printing
  for _, file in ipairs(commands_to_execute) do
    local args = {}
    for _, arg in ipairs(file) do
      args[#args + 1] = shell_escape(arg)
    end
    print("$: " .. table.concat(args, " "))
  end

  local _, errors = M.run_multiple(commands_to_execute)
  if #errors > 0 then
    print(table.concat(errors, "\n"))
  end
end

---@param cwd string The current working directory
---@param setup_config __rissue.SetupConfig
function M.run_setup(cwd, setup_config)
  -- run luv without blocking
  uv.run("nowait")
  mkdir_p(cwd)
  run_setup_config(setup_config)
  print("DONE")
end

return M
