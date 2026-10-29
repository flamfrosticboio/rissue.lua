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

M.config = {
  tmp = "./.tmp/",
  api = "./.tmp/test-api",
}

---@param folder string Folder name
---@return string path
function M.get_test_api_path(folder)
  return M.config.api .. "/" .. folder
end

---@param msg string
function M.print_status(msg)
  print(">>> " .. msg)
end

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
}
local ansi_colors_len = #ansi_colors

M.ANSI_RESET = "\27[0m"

--- Colors the text with a cyclic colors based on id
---@param str string
---@param id integer
function M.ccolor(str, id)
  id = (id % ansi_colors_len) + 1
  return ansi_colors[id] .. str .. M.ANSI_RESET
end

local l = 0
function M.assign_color()
  l = (l % ansi_colors_len) + 1
  return ansi_colors[l]
end

---@generic T
---@param list T[]
---@return fun(): T|nil
function M.iterator(list)
  local n = 0
  return function()
    n = n + 1
    return list[n]
  end
end

return M
