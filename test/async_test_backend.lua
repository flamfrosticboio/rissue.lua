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

---@type __rissue.async.Backend
local backend

backend = {
  schedule = function(cb)
    cb()
  end,
  err_msg = nil,
  on_error = function(err, tb)
    local log = require("rissue.utils.log")
    log.error(err)
    log.trace(tb)
    backend.err_msg = err ---@diagnostic disable-line: inject-field
  end,
  ---@param cond fun(): boolean
  wait = function(cond)
    require("rissue.utils.process").wait(function()
      if backend.err_msg then
        error(backend.err_msg)
      end
      return cond()
    end, 10000)
  end,
  reset = function()
    ---@diagnostic disable-next-line: inject-field
    backend.err_msg = nil
  end,
}

return backend
