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

local this_script = debug.getinfo(1, "S").source:sub(2)
local this_dir = this_script:match("^(.*[/\\])") or "./"

describe("rissue", function()
  describe("setup", function()
    local rissue = require("rissue")
    local config = require("rissue.config")

    before_each(function()
      for name in pairs(package.loaded) do
        if name:match("^rissue") and not name:match("^rissue%.utils") then
          package.loaded[name] = nil
        end
      end

      rissue = require("rissue")
      config = require("rissue.config")
    end)

    it("Additional providers were provided", function()
      rissue.setup({
        additional_providers = {
          this_dir .. "/provider/_test_custom_loader.lua",
        },
      })

      assert(config.providers.custom, "'custom' Not found")
    end)
  end)
  describe("functions", function()
    local rissue = require("rissue")
    rissue.setup()

    it("get_provider_info() correct if provided with string", function()
      local info, err =
        rissue.get_provider_info("https://github.com/flamfrosticboio/rissue")
      assert(info and not err, err or "unknown error")
    end)
    it(
      "get_provider_info() correct if provided with rissue.RemoteInfo",
      function()
        local remote_info, remote_err =
          rissue.get_remote_info("https://github.com/flamfrosticboio/rissue")
        assert(remote_info and not remote_err, remote_err or "unknown error")
        local info, err = rissue.get_provider_info(remote_info)
        assert(info and not err, err or "unknown error")
      end
    )

    it("get_issues() correct if provided with string", function()
      local get = require("rissue.get")
      stub(get, "issues")

      rissue.get_issues("https://github.com/flamfrosticboio/rissue")

      assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
        match.same({
          additional_info = {
            api_version = "2026-03-10",
          },
          domain = "api.github.com",
          name = "github",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue",
        }),
        match.is_nil()
      )

      get.issues:revert() ---@diagnostic disable-line: undefined-field
    end)

    it("get_issues() correct if provided with rissue.RemoteInfo", function()
      local get = require("rissue.get")
      stub(get, "issues")

      local remote_info, remote_err =
        rissue.get_remote_info("https://github.com/flamfrosticboio/rissue")

      assert(remote_info and not remote_err, remote_err or "unknown error")

      rissue.get_issues(remote_info)

      assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
        match.same({
          additional_info = {
            api_version = "2026-03-10",
          },
          domain = "api.github.com",
          name = "github",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue",
        }),
        match.is_nil()
      )

      get.issues:revert() ---@diagnostic disable-line: undefined-field
    end)

    it("get_issues() correct if provided with rissue.ProviderInfo", function()
      local get = require("rissue.get")
      stub(get, "issues")

      local info, remote_err =
        rissue.get_provider_info("https://github.com/flamfrosticboio/rissue")

      assert(info and not remote_err, remote_err or "unknown error")

      rissue.get_issues(info)

      assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
        match.same({
          additional_info = {
            api_version = "2026-03-10",
          },
          domain = "api.github.com",
          name = "github",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue",
        }),
        match.is_nil()
      )

      get.issues:revert() ---@diagnostic disable-line: undefined-field
    end)

    it("get_merge_requests() correct if provided with string", function()
      local get = require("rissue.get")
      stub(get, "issues")

      rissue.get_issues("https://github.com/flamfrosticboio/rissue")

      assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
        match.same({
          additional_info = {
            api_version = "2026-03-10",
          },
          domain = "api.github.com",
          name = "github",
          owner = "flamfrosticboio",
          protocol = "https",
          repo = "rissue",
        }),
        match.is_nil()
      )

      get.issues:revert() ---@diagnostic disable-line: undefined-field
    end)

    it(
      "get_merge_requests() correct if provided with rissue.RemoteInfo",
      function()
        local get = require("rissue.get")
        stub(get, "issues")

        local remote_info, remote_err =
          rissue.get_remote_info("https://github.com/flamfrosticboio/rissue")

        assert(remote_info and not remote_err, remote_err or "unknown error")

        rissue.get_issues(remote_info)

        assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
          match.same({
            additional_info = {
              api_version = "2026-03-10",
            },
            domain = "api.github.com",
            name = "github",
            owner = "flamfrosticboio",
            protocol = "https",
            repo = "rissue",
          }),
          match.is_nil()
        )

        get.issues:revert() ---@diagnostic disable-line: undefined-field
      end
    )

    it(
      "get_merge_requests() correct if provided with rissue.ProviderInfo",
      function()
        local get = require("rissue.get")
        stub(get, "issues")

        local info, remote_err =
          rissue.get_provider_info("https://github.com/flamfrosticboio/rissue")

        assert(info and not remote_err, remote_err or "unknown error")

        rissue.get_issues(info)

        assert.stub(get.issues --[[@as luassert.spy]]).was.called_with(
          match.same({
            additional_info = {
              api_version = "2026-03-10",
            },
            domain = "api.github.com",
            name = "github",
            owner = "flamfrosticboio",
            protocol = "https",
            repo = "rissue",
          }),
          match.is_nil()
        )

        get.issues:revert() ---@diagnostic disable-line: undefined-field
      end
    )
  end)
end)
