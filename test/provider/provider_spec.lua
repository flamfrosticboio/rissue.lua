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
local async = require("rissue.utils.async")

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
  before_each(reset)

  it("matches custom", function()
    local setup_err = require("rissue").setup({
      endpoint_shortcuts = {
        {
          name = "custom_shortcut",
          domain = "api.custom.com",
          patterns = { "custom%.com" },
        },
      },
    })

    assert(not setup_err, setup_err)

    local provider = require("rissue.provider")

    local url = "https://custom.com/flamfrosticboio/rissue.git"
    local remote_info, err = provider.remote_info(url)
    assert(remote_info and not err, err)

    local info
    local backend = async.default_backend()
    async.run(
      backend,
      ---@async
      function(a)
        local _info, err2 = provider.provider_info(a, remote_info)
        assert(_info and not err2, err2)
        info = _info
      end
    )

    assert.same({
      domain = "api.custom.com",
      name = "custom_shortcut",
      owner = "flamfrosticboio",
      repo = "rissue",
      protocol = "https",
    }, info)
  end)

  it("matches builtin github", function()
    local setup_err = require("rissue").setup()
    assert(not setup_err, setup_err)
    local provider = require("rissue.provider")

    local url = "https://github.com/flamfrosticboio/rissue.git"
    local remote_info, err = provider.remote_info(url)
    assert(remote_info and not err, err)

    local info
    local backend = async.default_backend()
    async.run(
      backend,
      ---@async
      function(a)
        local _info, err2 = provider.provider_info(a, remote_info)
        assert(_info and not err2, err2)
        info = _info
      end
    )

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

  it("Settings are properly scoped", function()
    local setup_err = require("rissue").setup({
      endpoint_shortcuts = {},
      additional_providers = {
        this_dir .. "_test_custom_loader.lua",
      },
    })

    local config = require("rissue.config")
    local keys = {}
    for name in pairs(config.providers) do
      keys[#keys + 1] = name
    end
    for _, name in ipairs(keys) do
      if name ~= "custom" then
        config.providers[name] = nil
      end
    end

    assert(not setup_err, setup_err)
    local provider = require("rissue.provider")

    local url = "https://custom.com/flamfrosticboio/rissue.git"
    local remote_info, err = provider.remote_info(url)
    assert(remote_info and not err, err)

    spy.on(config, "merge_provider_settings")

    local backend = async.default_backend()
    async.run(
      backend,
      ---@async
      function(a)
        provider.provider_info(a, remote_info, { custom = { my_opts = true } })
      end
    )

    ---@diagnostic disable-next-line: param-type-mismatch
    assert.spy(config.merge_provider_settings).was.called(1)
    assert
      ---@diagnostic disable-next-line: param-type-mismatch
      .spy(config.merge_provider_settings)
      .was
      .called_with(match.is_table(), match.same({ my_opts = true }))

    config.merge_provider_settings:revert()
  end)

  it("Multiple shortcuts ok", function()
    local setup_err = require("rissue").setup({
      endpoint_shortcuts = {
        {
          name = "custom",
          patterns = { "custom%.com" },
          domain = "api.custom.com",
        },
        {
          name = "custom_other",
          patterns = { "extra%.water%.com" },
          domain = "api.extra.custom.com",
        },
        {
          name = "custom",
          patterns = { "something%.org" },
          domain = "api.custom.com",
          additional_info = { custom = true },
        },
      },
    })
    assert(not setup_err, setup_err)
    local provider = require("rissue.provider")

    local backend = async.default_backend()
    async.run(
      backend,
      ---@async
      function(a)
        local remote_info = provider.remote_info(
          "https://custom.com/flamfrosticboio/rissue.lua.git"
        )
        assert(remote_info, "Url cannot be converted into remote info")
        local res = provider.provider_info(a, remote_info)
        assert.same({
          domain = "api.custom.com",
          name = "custom",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue.lua",
        }, res)

        remote_info = provider.remote_info(
          "https://extra.water.com/flamfrosticboio/rissue.lua.git"
        )
        assert(remote_info, "Url cannot be converted into remote info")
        res = provider.provider_info(a, remote_info)
        assert.same({
          domain = "api.extra.custom.com",
          name = "custom_other",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue.lua",
        }, res)

        remote_info = provider.remote_info(
          "https://something.org/flamfrosticboio/rissue.lua.git"
        )
        assert(remote_info, "Url cannot be converted into remote info")
        res = provider.provider_info(a, remote_info)
        assert.same({
          domain = "api.custom.com",
          name = "custom",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue.lua",
          additional_info = {
            custom = true,
          },
        }, res)
      end
    )
  end)
end)
