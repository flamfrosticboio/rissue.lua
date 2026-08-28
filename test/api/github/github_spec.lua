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

local describe = describe or require("busted").describe
local it = it or require("busted").it
---@type luassert | fun()
local assert = require("busted").assert

local test_files = ".test_setup/github"

---@param name string
---@param specfile string
---@param is_proxy boolean?
local function test_version(name, specfile, is_proxy)
  local utils = require("api.utils")
  local provider = require("rissue.provider")
  utils.with_server({
    name = name,
    specfile = test_files .. "/" .. specfile .. ".json",
    is_proxy = is_proxy or false,
  }, function(_, port)
    local domain = utils.host .. ":" .. port

    it("found provider", function()
      local ok, info =
        provider.get_provider_info("http://" .. domain .. "/owner/repo.git")
      if not ok then
        error(info)
      end

      assert.same({
        domain = domain,
        name = "github",
        owner = "owner",
        repo = "repo",
        protocol = "http", -- since prism is launched in http mode
      } --[[@as rissue.ProviderInfo]], info)
    end)
  end)
end

local gutils = require("api.github.setup_utils")

describe("github #api", function()
  local utils = require("api.utils")
  test_version("api.github.com #github_api", "github_api")
  test_version("ghec #ghec", "ghec")

  utils.with_proxy({
    name = "github ghes #ghes",
    prefix = "/api/v3",
    port = 55000,
    target_port = 55001,
  }, function()
    for _, version in ipairs(gutils.ghes_versions) do
      test_version(version, "ghes-" .. version, true)
    end

    for _, version in ipairs(gutils.ghes_2026_versions) do
      test_version(version, "ghes-" .. version .. "-2026", true)
    end
  end)
end)
