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

--- Process result
---@class rissue.utils.process.Result
---@field return_code integer
---@field stdout string
---@field stderr string

---@alias rissue.cmd string[] Command line arguments

--- Process options
---@class rissue.utils.process.Opts
---@field cmd string Binary
---@field args? string[] Arguments passed
---@field cwd? string Current working directory
---Environment variables in a form of `ENV=VALUE` or {ENV = VALUE}
---@field env? string[] | table<string, string|nil> --- Process run options

---@class rissue.utils.run_process.Opts
---@field print_output boolean Print process's stdout and stderr to logger
