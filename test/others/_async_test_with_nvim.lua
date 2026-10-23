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

-- Developed by: Claude Sonnet 5
--
-- Meant to test nvim async compatibility before running
--
-- Run from the project root:
--   nvim --headless -u NONE -l test/others/_async_test_with_nvim.lua
-- Adjust package.path below if your module lives elsewhere.

---@diagnostic disable: undefined-global, await-in-sync, unused-local

package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  package.path,
}, ";")

local async = require("rissue.utils.async")
local uv = vim.uv or vim.loop

-- ---------------------------------------------------------------
-- backend (neovim)
-- ---------------------------------------------------------------
local function make_backend()
  local errors = {}
  return {
    schedule = vim.schedule, -- always defers, never inline
    on_error = function(err, tb)
      errors[#errors + 1] = tostring(err)
    end,
  },
    errors
end

-- ---------------------------------------------------------------
-- tiny test harness
-- ---------------------------------------------------------------
local passed, failed = 0, 0
local out = {}

local function log(s)
  out[#out + 1] = s
  print(s)
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    log("PASS  " .. name)
  else
    failed = failed + 1
    log("FAIL  " .. name .. "\n      " .. tostring(err))
  end
end

local function eq(got, want, msg)
  if got ~= want then
    error(
      string.format(
        "%s: expected %s, got %s",
        msg or "eq",
        vim.inspect(want),
        vim.inspect(got)
      ),
      2
    )
  end
end

local function wait_for(cond)
  assert(vim.wait(2000, cond, 5), "timed out waiting for condition")
end

-- ---------------------------------------------------------------
-- tests
-- ---------------------------------------------------------------
test("wrap resumes with value after vim.defer_fn", function()
  local be, errors = make_backend()
  local steps, done = {}, false

  async.run(be, function(a)
    steps[#steps + 1] = "start"
    local v = a:wrap(function(cb)
      vim.defer_fn(function()
        cb("hi")
      end, 10)
    end)
    steps[#steps + 1] = v
    done = true
  end)

  eq(steps[1], "start", "ran synchronously until first yield")
  eq(steps[2], nil, "not resumed yet")
  wait_for(function()
    return done
  end)
  eq(steps[2], "hi", "resumed value")
  eq(#errors, 0, "no errors")
end)

test("synchronous callback works", function()
  local be, errors = make_backend()
  local got, done

  async.run(be, function(a)
    got = a:wrap(function(cb)
      cb("now")
    end)
    done = true
  end)

  wait_for(function()
    return done
  end)
  eq(got, "now")
  eq(#errors, 0, "no errors")
end)

test("nil values are preserved (n tracking)", function()
  local be = make_backend()
  local count, done

  async.run(be, function(a)
    count = select(
      "#",
      a:wrap(function(cb)
        cb(nil, "x", nil)
      end)
    )
    done = true
  end)

  wait_for(function()
    return done
  end)
  eq(count, 3, "returned value count")
end)

test("sequential waits accumulate", function()
  local be, errors = make_backend()
  local sum, done = 0, false

  async.run(be, function(a)
    for i = 1, 3 do
      sum = sum
        + a:wrap(function(cb)
          vim.defer_fn(function()
            cb(i)
          end, 5)
        end)
    end
    done = true
  end)

  wait_for(function()
    return done
  end)
  eq(sum, 6)
  eq(#errors, 0, "no errors")
end)

test("resume from libuv fast context, then vim.api is safe", function()
  local be, errors = make_backend()
  local api_ok, done

  async.run(be, function(a)
    a:wrap(function(cb)
      local timer = uv.new_timer()
      timer:start(10, 0, function() -- fast event context
        timer:stop()
        timer:close()
        cb()
      end)
    end)
    -- would throw E5560 if we were still in a fast context
    api_ok = pcall(vim.api.nvim_get_current_buf)
    done = true
  end)

  wait_for(function()
    return done
  end)
  eq(api_ok, true, "vim.api callable after resume")
  eq(#errors, 0, "no errors")
end)

test("callback fired twice reports an error", function()
  local be, errors = make_backend()
  local fire, done

  async.run(be, function(a)
    a:wrap(function(cb)
      fire = cb
    end)
    done = true
  end)

  fire("first")
  wait_for(function()
    return done
  end)
  fire("second")
  eq(#errors, 1, "error count")
  assert(errors[1]:find("more than once"), "message mentions double call")
end)

test("error in coroutine body goes to on_error", function()
  local be, errors = make_backend()

  async.run(be, function()
    error("boom")
  end)

  eq(#errors, 1, "error count")
  assert(errors[1]:find("boom"), "message contains boom")
end)

test("error after a yield goes to on_error", function()
  local be, errors = make_backend()
  local done

  async.run(be, function(a)
    a:wrap(function(cb)
      vim.defer_fn(cb, 5)
    end)
    error("late boom")
  end)

  wait_for(function()
    return #errors > 0
  end)
  assert(errors[1]:find("late boom"), "message contains late boom")
end)

test("stray coroutine.yield is reported", function()
  local be, errors = make_backend()

  async.run(be, function()
    coroutine.yield("not ours")
  end)

  eq(#errors, 1, "error count")
  assert(errors[1]:find("outside Async:yield"), "stray-yield message")
end)

test("error in fn passed to wrap goes to on_error", function()
  local be, errors = make_backend()

  async.run(be, function(a)
    a:wrap(function()
      error("fn failed")
    end)
  end)

  eq(#errors, 1, "error count")
  assert(errors[1]:find("fn failed"), "message contains fn failed")
end)

test("nvim read and write ok", function()
  local be, errors = make_backend()

  local done = false
  async.run(be, function(a)
    local err, fd = a:wrap(function(cb)
      uv.fs_open(".tmp/test.txt", "w", 420, cb)
    end)

    if err then
      error(err)
    end

    local write_err = a:wrap(function(cb)
      uv.fs_write(fd, "hello world 2", 0, cb)
    end)

    if write_err then
      error(write_err)
    end

    local close_err = a:wrap(function(cb)
      uv.fs_close(fd, cb)
    end)

    if close_err then
      error(close_err)
    end
    done = true
  end)

  wait_for(function()
    return done or (#errors > 0)
  end)

  if #errors > 0 then
    error("This is an error: " .. errors[1], 0)
  end
end)

-- ---------------------------------------------------------------
-- report (also written to .tmp/results.txt)
-- ---------------------------------------------------------------
log(string.format("\n%d passed, %d failed", passed, failed))

local f = io.open(".tmp/results.txt", "w")
if f then
  f:write(table.concat(out, "\n"), "\n")
  f:close()
end

vim.cmd(failed == 0 and "qa!" or "cq")
