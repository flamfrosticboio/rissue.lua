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

M = {}

---@diagnostic disable: undefined-global

---@param ... table
---@return table
function M.force_extend(...)
    if vim then
        return vim.tbl_extend("force", ...)
    end

    ---@type table | nil
    local current = nil
    --- fallback implementation
    for _, tbl in ipairs({ ... }) do
        if current == nil then
            current = tbl
        else
            for k, v in pairs(tbl) do
                current[k] = v
            end
        end
    end

    assert(current ~= nil)
    return current
end

return M
