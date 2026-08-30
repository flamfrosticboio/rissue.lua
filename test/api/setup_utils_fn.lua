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

--- A bunch of functions that is used frequently in `setup_utils.lua`

local uv = require("luv") ---@type uv

local M = {}

--- Replaces an value in the list
---@generic T: any, A: any, B: any
---@param list (T | A)[]
---@param from A
---@param to B
---@return (T | B)[]
function M.replace_in_list(list, from, to)
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

--- Shells escapes a string. Used for displaying.
---@param arg string
---@return string
function M.shell_escape(arg)
  local needs_escape = arg == "" or arg:find("[^%w%-%._/]") ~= nil
  if needs_escape then
    return "'" .. arg:gsub("'", "'\\''") .. "'"
  end
  return arg
end

--- Prints the shell command to console
---@param shell_command rissue.cmd
---@param prefix string
---@param output_on_stderr? boolean
function M.print_shell(shell_command, prefix, output_on_stderr)
  local out = output_on_stderr and io.stderr or io.stdout
  local shell_length = #shell_command
  out:write(prefix)
  if shell_length > 0 then
    out:write(shell_command[1])
  end
  if shell_length > 1 then
    for i = 2, shell_length do
      out:write(" ")
      out:write(shell_command[i])
    end
  end
  out:write("\n")
  out:flush()
end

--- Performs recursive mkdir on the path
---@param path string
function M.mkdir(path)
  -- normalize trailing slash
  path = path:gsub("/$", "")

  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return true -- already exists
  end

  local parent = path:match("^(.*)/[^/]+$")
  if parent and parent ~= "" then
    local ok, err = M.mkdir(parent) -- recurse into parent first
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

--- Performs recursive rmdir on path
---@param path string
function M.rmdir(path)
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
      local ok, e = M.rmdir(full_path)
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

local ansi_colors = {
  "\27[31m",
  "\27[32m",
  "\27[33m",
  "\27[34m",
  "\27[35m",
  "\27[36m",
  "\27[37m",
  "\27[90m",
  "\27[91m",
  "\27[92m",
  "\27[93m",
  "\27[94m",
  "\27[95m",
  "\27[96m",
  "\27[0m",
}
local ansi_colors_len = #ansi_colors

local RESET = "\27[0m"

--- Colors the text with a cyclic colors based on id
---@param str string
---@param id integer
function M.ccolor(str, id)
  id = (id % ansi_colors_len) + 1
  return ansi_colors[id] .. str .. RESET
end

return M
