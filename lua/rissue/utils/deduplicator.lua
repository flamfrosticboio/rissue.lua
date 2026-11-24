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

--- returns a deduplicator function
---@param output fun(item: any) receives each constructed item
---@param constructor fun(item: any): any
---@param accessor fun(item: any): string|integer|number|nil
---@return fun(res: any) cb new callback function
return function(output, constructor, accessor)
  local seen = {} ---@type table<string|integer|number, true>
  return function(res)
    local id = accessor(res)
    if id == nil or seen[id] then
      return
    end
    seen[id] = true

    output(constructor(res))
  end
end
