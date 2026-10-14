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

require("luv")

---@param arg any
local function write(arg)
  local inspect = require("inspect")
  if type(arg) == "string" then
    io.write(arg)
  else
    io.write(inspect(arg))
  end
end

--- rebind print with inspect print for debugging purposes
function print(...)
  local args = { ... }
  local len = select("#", ...)

  if len <= 0 then
    return
  end
  write(args[1])

  for i = 2, len do
    io.write("\t")
    write(args[i])
  end

  io.write("\n")
  io.flush()
end

--- add package paths
package.path = "./test/?.lua;./test/?/init.lua;./lua/?.lua;./lua/?/init.lua;"
  .. package.path

--- setup logging
local logger = require("rissue.utils.log")
local use_trace = os.getenv("TRACE")
if use_trace and use_trace:lower() == "true" then
  logger.log_level = logger.levels.trace
else
  logger.log_level = logger.levels.debug
end
