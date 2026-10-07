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

local ok, inspect = pcall(require, "inspect")
if not ok then
  inspect = tostring
end

---@diagnostic disable: unused-function, unused-local
local function _print_inspect(...)
  local args = { ... }
  if #args == 1 then
    io.write(inspect(args[1]))
    io.flush()
    return
  end

  for _, arg in ipairs(args) do
    io.write(inspect(arg))
    io.write("\t")
  end
  io.flush()
end

local function reset()
  for name in pairs(package.loaded) do
    if name:match("^rissue") and not name:match("^rissue%.utils") then
      package.loaded[name] = nil
    end
  end
end

describe("get", function()
  before_each(reset)
  it("coroutine ok under coroutine contexts", function()
    local rissue = require("rissue")
    local config = require("rissue.config")
    rissue.setup({
      endpoint_shortcuts = {
        custom = {
          patterns = { "custom%.com" },
          domain = "api.customendpoint.com",
        },
      },
      additional_providers = {
        "./test/provider/_test_custom_loader.lua",
      },
      provider_options = {
        custom = {
          enable_coroutine = true,
        },
      },
    })
    assert.is_not_nil(config.providers.custom)

    local provider_info, provider_info_err = rissue.get_provider_info(
      "https://custom.com/flamfrosticboio/rissue.lua.git"
    )

    assert(provider_info, provider_info_err or "unknown error")
    assert.same({
      domain = "api.customendpoint.com",
      name = "custom",
      owner = "flamfrosticboio",
      protocol = "https",
      repo = "rissue.lua",
    }, provider_info)

    local issues, err_msg, done
    local co = coroutine.create(function()
      issues, err_msg = rissue.get_issues(provider_info)
      done = true
    end)

    -- first call to try hitting where coroutine.yield() inside provider
    coroutine.resume(co)
    ---@diagnostic disable-next-line: undefined-field
    assert.equal("get_issues", config.providers.custom.viewer.on_coroutine)

    -- second call to return back to coroutine.yield()
    coroutine.resume(co)
    ---@diagnostic disable-next-line: undefined-field
    assert.equal(nil, config.providers.custom.viewer.on_coroutine)

    assert.is_true(done)
    assert(issues, err_msg)
  end)

  it("blocking mode ok", function()
    local rissue = require("rissue")
    local config = require("rissue.config")
    rissue.setup({
      endpoint_shortcuts = {
        custom = {
          patterns = { "custom%.com" },
          domain = "api.customendpoint.com",
        },
      },
      additional_providers = {
        "./test/provider/_test_custom_loader.lua",
      },
      provider_options = {
        custom = {
          enable_coroutine = true,
        },
      },
    })

    assert.is_not_nil(config.providers.custom)

    local provider_info, provider_info_err = rissue.get_provider_info(
      "https://custom.com/flamfrosticboio/rissue.lua.git"
    )

    assert(provider_info, provider_info_err or "unknown error")
    assert.same({
      domain = "api.customendpoint.com",
      name = "custom",
      owner = "flamfrosticboio",
      protocol = "https",
      repo = "rissue.lua",
    }, provider_info)

    local expect = "get_issues" ---@type string?
    ---@diagnostic disable-next-line: undefined-field
    config.providers.custom.viewer.on_coroutine_hook = function()
      ---@diagnostic disable-next-line: undefined-field
      assert.equal(expect, config.providers.custom.viewer.on_coroutine)
      expect = nil
    end

    local issues, err_msg = rissue.get_issues(provider_info)
    assert(issues, err_msg)
  end)
end)
