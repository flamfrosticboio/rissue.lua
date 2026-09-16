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

local M = {}

---@class __rissue.Github.fetch.Opts<T, K>
---@field token string?
---@field parser fun(raw: any): T
---@field key fun(item: T): K
---@field buffer table<K, T>

---@generic T, K
---@param info rissue.ProviderInfo
---@param queries rissue.Query[]
---@param opts __rissue.Github.fetch.Opts<T, K>
---@return T[]? results
---@return string? error
function M.fetch(info, queries, opts)
  print(info, queries, opts)
end

return M
