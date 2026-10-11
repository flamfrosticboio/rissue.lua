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

local viewer = {}
local luv = require("luv") ---@type uv

---@async
---@param state string
local function handle_coroutine(state)
  local hook = viewer.on_coroutine_hook
  viewer.on_coroutine = state
  if type(hook) == "function" then
    hook()
  end

  local co = coroutine.running()
  local timer, timer_err = luv.new_timer()
  if not timer then
    error("Could not create timer: " .. (timer_err or "unknown error"))
  end
  timer:start(200, 0, function()
    timer:stop()
    timer:close()
    if coroutine.status(co) == "suspended" then
      local ok, err = coroutine.resume(co)
      if not ok then
        error(debug.traceback(err))
      end
    end
  end)

  coroutine.yield()

  viewer.on_coroutine = nil
  if type(hook) == "function" then
    hook()
  end
end

---@type rissue.Provider
return {
  name = "custom",
  version = "0.1",
  version_code = 1000,
  ---@async
  supports = function(info, token, opts)
    viewer.supports = { info, token, opts }
    if opts.enable_coroutine then
      handle_coroutine("supports")
    end
    return true
  end,
  ---@async
  get_issues = function(info, token, opts)
    viewer.get_issues = { info, token, opts }
    if opts.enable_coroutine then
      handle_coroutine("get_issues")
    end
    return {}
  end,
  ---@async
  get_merge_requests = function(info, token, opts)
    viewer.get_merge_requests = { info, token, opts }
    if opts.enable_coroutine then
      handle_coroutine("get_merge_requests")
    end
    return {}
  end,
  settings = {
    my_setting = false,
  },
  viewer = viewer,
}
