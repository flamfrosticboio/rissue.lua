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

local uv = require("luv") ---@type uv

local M = {}

--- Opens and reads all contents in the file
--- Warning: Raises errors when reading the file fails
---@param file string
---@return string? result
---@return string? error
function M.read_file(file)
  local fd, err = uv.fs_open(file, "r", 438)
  if not fd then
    return nil, err
  end

  local ok, result = pcall(function()
    local stat, stat_err = uv.fs_fstat(fd)
    if not stat then
      error(stat_err, 0)
    end
    local data, read_err = uv.fs_read(fd, stat.size, 0)
    if not data then
      error(read_err, 0)
    end
    return data
  end)

  uv.fs_close(fd)

  if not ok then
    return nil, result
  end

  return result, nil
end

--- Warning: Raises errors when delete fails
---@param file string Filepath to delete
---@return boolean success
---@return string?  error
function M.delete_file(file)
  local ok, err = uv.fs_unlink(file)
  return ok or false, err
end

return M
