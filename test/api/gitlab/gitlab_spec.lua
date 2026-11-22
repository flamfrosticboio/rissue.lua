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

local utils = require("api.test_utils")

local cwd = require("util").get_test_api_path("gitlab")

local issues = require("api.gitlab.issues")
local merge_requests = require("api.gitlab.merge_requests")

---@class __rissue.Gitlab.TestVersionOpts
---@field additional_info rissue.Gitlab.AdditionalInfo?
---@field proxy __rissue.ProxyHandle?

---@param name string
---@param specfile string
---@param opts __rissue.Gitlab.TestVersionOpts?
local function test_version(name, specfile, opts)
  utils.with_server({
    name = string.format("%s", name),
    specfile = string.format("%s/%s.json", cwd, specfile),
  }, function(_, port)
    local domain = utils.host .. ":" .. port

    ---@type rissue.ProviderInfo
    local provider_info = {
      domain = domain,
      name = "gitlab",
      owner = "owner",
      repo = "repo",
      protocol = "http",
      additional_info = opts and opts.additional_info,
    }

    local rissue = require("rissue")
    local config = require("rissue.config")
    config.providers = { gitlab = require("rissue.providers.gitlab") }

    it(string.format("provider_info #gl_%s_pinfo", name), function()
      local got_info, err =
        rissue.get_provider_info("http://" .. domain .. "/owner/repo.git")

      --- Since assert.same does not support matchers, we just need to copy it at runtime
      --- so that the test will pass
      if
        provider_info.additional_info
        and got_info
        and got_info.additional_info
      then
        provider_info.additional_info.version = got_info.additional_info.version
      end

      assert(not err, err)
      assert.same(provider_info, got_info)
    end)

    issues(name, rissue, provider_info)
    merge_requests(name, rissue, provider_info)
  end)
end

describe("gitlab #api", function()
  test_version("latest", "latest", {
    additional_info = {
      is_enterprise = true,
      version = "stub",
    },
  })

  test_version("v9", "v9.0", {
    additional_info = {
      is_enterprise = false,
      version = "stub",
    },
  })

  test_version("v19.6", "v19.6", {
    additional_info = {
      is_enterprise = true,
      version = "stub",
    },
  })
end)
