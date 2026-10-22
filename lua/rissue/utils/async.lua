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

local process = require("rissue.utils.process")
---@alias __rissue.Pack { n: integer, [integer]: any }

---@type table
local RESUME = {}
---@type table
local YIELD = {}

---@class __rissue.async.Backend
---@field schedule fun(fn: fun()) must defer; never run fn synchronously
---@field on_error fun(err: any, tb: string)
---@field wait fun(cond: (fun(): boolean), timeout: integer, interval: integer?)

---@class rissue.Async
---@field co thread
---@field inbox __rissue.Pack values passed resumer -> coroutine
---@field outbox __rissue.Pack values passed coroutine -> resumer
---@field backend __rissue.async.Backend
local Async = {}
Async.__index = Async

--- Schedules a resume of the async process on the backend.
---@param ... any values returned by the pending yield()
function Async:resume(...)
  local args = { n = select("#", ...), ... }
  self.backend.schedule(function()
    self:_step(unpack(args, 1, args.n))
  end)
end

---@async
---@param ... any values passed to the resumer
---@return any ... values passed to the next resume()
function Async:yield(...)
  self.outbox = { n = select("#", ...), ... }
  while true do
    if coroutine.yield(YIELD) == RESUME then
      local inb = self.inbox
      return unpack(inb, 1, inb.n)
    end
  end
end

--- Internal: the only place that calls coroutine.resume.
---@package
---@param ... any
function Async:_step(...)
  local status = coroutine.status(self.co)
  if status ~= "suspended" then
    return self.backend.on_error(
      "cannot resume " .. status .. " coroutine",
      debug.traceback()
    )
  end

  self.inbox = { n = select("#", ...), ... }
  local ok, tok = coroutine.resume(self.co, RESUME)

  if not ok then
    return self.backend.on_error(tok, debug.traceback(self.co, tostring(tok)))
  end

  -- stray coroutine.yield() from outside Async:yield
  if coroutine.status(self.co) ~= "dead" and tok ~= YIELD then
    return self.backend.on_error(
      "coroutine yielded outside Async:yield",
      debug.traceback(self.co)
    )
  end
end

--- Wrap an callback style async operation
---@async
---@param fn fun(cb: fun(...: any))
---@return any ...
function Async:wrap(fn)
  local done = false

  fn(function(...)
    if done then
      self.backend.on_error("callback called more than once", debug.traceback())
      return
    end
    done = true
    self:resume(...)
  end)

  return self:yield()
end

---@class rissue.mod.Async
local async = {}

---@param backend __rissue.async.Backend
---@param cb async fun(a: rissue.Async)
---@return rissue.Async
function async.run(backend, cb)
  ---@type rissue.Async
  local a = setmetatable({
    backend = backend,
    inbox = { n = 0 },
    outbox = { n = 0 },
  }, Async)
  a.co = coroutine.create(
    ---@async
    function()
      cb(a)
    end
  )
  a:_step()
  return a
end

local function report(err, tb)
  local log = require("rissue.utils.log")
  log.error(err)
  log.trace(tb)
end

---@return __rissue.async.Backend
function async.default_backend()
  local err_msg = nil

  ---@type __rissue.async.Backend
  return {
    schedule = function(fn)
      fn()
    end,
    on_error = function(err, tb)
      err_msg = err
      report(err, tb)
    end,
    wait = function(cond, timeout, interval)
      if err_msg ~= nil then
        error(err_msg, 2)
      else
        process.wait(cond, timeout, interval)
      end
    end,
  }
end

return async
