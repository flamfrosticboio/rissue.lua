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

---@diagnostic disable: undefined-global

local M = {}

---@param t any
---@return boolean is_list
function M.is_list(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for k in pairs(t) do
        i = i + 1
        if k ~= i then return false end
    end
    return true
end

---@param ... table
---@return table
function M.force_deep_extend(...)
    local tables = { ... }
    local result = {}

    local function merge(dst, src)
        for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" and not M.is_list(v) then
                merge(dst[k], v)
            else
                if type(v) == "table" then
                    if M.is_list(v) then
                        dst[k] = v
                    else
                        local copy = {}
                        merge(copy, v)
                        dst[k] = copy
                    end
                else
                    dst[k] = v
                end
            end
        end
    end

    for _, t in ipairs(tables) do
        merge(result, t)
    end

    return result
end

--- Returns the number of items of the table
---@param tbl table
---@return integer
function M.count(tbl)
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

return M
