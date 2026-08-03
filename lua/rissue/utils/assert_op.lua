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

--- Assert extensions but doesnt affect the assert itself

local M = {}

---@generic T: type
---@param name  string
---@param obj   any
---@param t     T
---@param level integer Default: 2
---@return TypeGuard<T>
function M.is_type_named(name, obj, t, level)
    if type(obj) ~= t then
        error(
            ("Expecting %s to be '%s', got: '%s'"):format(name, t, type(obj)),
            level or 2
        )
    end
    return true
end

return M
