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

---@diagnostic disable: undefined-field, redundant-parameter

local function reset()
  for name in pairs(package.loaded) do
    if name:match("^rissue") and not name:match("^rissue%.utils") then
      package.loaded[name] = nil
    end
  end
end

local this_script = debug.getinfo(1, "S").source:sub(2)
local this_dir = this_script:match("^(.*[/\\])") or "./"

describe("remote_info", function()
  reset()
  require("rissue").setup()
  local provider = require("rissue.provider")

  it("matches https", function()
    local url = "https://github.com/flamfrosticboio/rissue.git"
    local info = provider.remote_info(url)
    assert.same({
      curl_protocol = "https",
      domain = "github.com",
      owner = "flamfrosticboio",
      repo = "rissue",
      full_url = url,
    } --[[@as rissue.RemoteInfo]], info)
  end)

  it("matches git", function()
    local url = "git@github.com:flamfrosticboio/rissue.git"
    local info = provider.remote_info(url)
    assert.same({
      curl_protocol = "https", -- since https on all protocols by default
      domain = "github.com",
      owner = "flamfrosticboio",
      repo = "rissue",
      full_url = url,
    } --[[@as rissue.RemoteInfo]], info)
  end)

  it("matches http", function()
    local url = "http://github.com/flamfrosticboio/rissue.git"
    local info = provider.remote_info(url)
    assert.same({
      curl_protocol = "http",
      domain = "github.com",
      owner = "flamfrosticboio",
      repo = "rissue",
      full_url = url,
    } --[[@as rissue.RemoteInfo]], info)
  end)
end)

describe("provider_info", function()
  reset()

  -- EXPLICITLY DISABLE OTHER PROVIDERS
  require("rissue.config").providers = {}

  local setup_err = require("rissue").setup({
    endpoint_shortcuts = {
      custom_shortcut = {
        domain = "api.custom.com",
        patterns = { "custom%.com" },
      },
    },
    additional_providers = {
      this_dir .. "/_test_custom_loader.lua",
    },
  })
  if setup_err then
    error(setup_err)
  end

  local provider = require("rissue.provider")

  it("matches custom", function()
    local url = "https://custom.com/flamfrosticboio/rissue.git"
    local remote_info, err = provider.remote_info(url)
    assert(remote_info and not err, err)
    local info, err2 = provider.provider_info(remote_info)
    assert(info and not err2, err2)
    assert.same({
      domain = "api.custom.com",
      name = "custom_shortcut",
      owner = "flamfrosticboio",
      repo = "rissue",
      protocol = "https",
    }, info)
  end)

  it("matches builtin github", function()
    local url = "https://github.com/flamfrosticboio/rissue.git"
    local remote_info, err = provider.remote_info(url)
    assert(remote_info and not err, err)
    local info, err2 = provider.provider_info(remote_info)
    assert(info and not err2, err2)
    assert.same({
      domain = "api.github.com",
      name = "github",
      owner = "flamfrosticboio",
      repo = "rissue",
      protocol = "https",
      additional_info = {
        api_version = "2026-03-10",
      },
    }, info)
  end)
end)
