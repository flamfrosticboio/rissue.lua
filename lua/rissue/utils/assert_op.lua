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

local table_op = require("rissue.utils.table_op")

local M = {}

---@param obj  any
---@param list any
---@return boolean
local function _is_instance(obj, list)
    local t = type(obj)
    for _, expected_type in ipairs(list) do
        if t == expected_type then
            return true
        end
    end
    return false
end

---@generic T: type
---@param obj any
---@return TypeGuard<T>
---@overload fun(obj: any, t: T[]): TypeGuard<T>
function M.is_instance(obj, ...)
    local args = { ... }
    if type(args[1]) == "table" then
        return _is_instance(obj, args[1])
    end
    return _is_instance(obj, args)
end

---@alias rissue.utils.check_structure.Structure table<any, type | type[] | rissue.utils.check_structure.Structure>

--- Checks a table's structure to see if it matches
---@generic T: any
---@param _cls      `T`?                                   Used for typehinting
---@param obj       any
---@param structure rissue.utils.check_structure.Structure
---@param name      string                                 Name of the table
---@return TypeGuard<T>, string?
function M.check_structure(_cls, obj, structure, name)
    if type(obj) ~= "table" then
        return false, ("Expecting %s to be a table, got %s"):format(name, type(obj))
    end

    for field_name, expected_type in pairs(structure) do
        local o = obj[field_name]
        local t = type(o)
        if type(expected_type) == "string" then
            if t ~= expected_type then
                return false,
                    ("Expecting %s on field %s, got %s"):format(
                        expected_type, name .. "." .. field_name, t
                    )
            end
        elseif table_op.is_list(expected_type) then
            ---@cast expected_type type[]
            if not _is_instance(o, expected_type) then
                return false,
                    ("Expecting %s on field %s, got %s"):format(
                        table.concat(expected_type, "|"), name .. "." .. field_name, t
                    )
            end
        else
            ---@cast expected_type rissue.utils.check_structure.Structure
            local res, err = M.check_structure(
                nil, o, expected_type, name .. "." .. field_name
            )
            if not res then
                return false, err
            end
        end
    end

    return true
end

return M
