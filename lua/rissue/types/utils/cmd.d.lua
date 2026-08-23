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

---@class rissue.utils.CmdResult
---@field return_code integer
---@field stdout string
---@field stderr string

---@alias rissue.cmd string[] Command line

---@class rissue.utils.CommandOpts
---@field cmd string
---@field args? string[]
---@field cwd? string Current working directory
---@field env? string[] | table<string, string> Environment variables in a form of `ENV=VALUE` or {ENV = VALUE}
