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

---@diagnostic disable: redundant-parameter

local describe = describe or require("busted").describe
local it = it or require("busted").it
---@type luassert | fun()
local assert = require("busted").assert

local test_files = ".test_setup/github"

---@class __rissue.github.test_version
---@field is_proxy boolean?
---@field request_opts rissue.Github.Opts?
---@field additional_info rissue.Github.supports.AdditionalInfo?

---@param name string
---@param specfile string
---@param opts __rissue.github.test_version
local function test_version(name, specfile, opts)
  local is_proxy = opts.is_proxy
  local utils = require("api.utils")
  local provider = require("rissue.provider")
  local get = require("rissue.get")
  utils.with_server({
    name = name,
    specfile = test_files .. "/" .. specfile .. ".json",
    is_proxy = is_proxy or false,
  }, function(_, port)
    local domain = utils.host .. ":" .. port

    local info_shared = nil

    it("found provider", function()
      local info, err = provider.get_provider_info(
        "http://" .. domain .. "/owner/repo.git",
        opts.request_opts
      )
      assert(not err, err)
      assert.is_not_nil(info)
      assert.same({
        domain = domain,
        name = "github",
        owner = "owner",
        repo = "repo",
        protocol = "http", -- since prism is launched in http mode
        additional_info = opts.additional_info,
      } --[[@as rissue.ProviderInfo]], info)

      info_shared = info
    end)

    it("issues ok at /search/issues", function()
      assert.is_not_nil(info_shared, "provider test was not ok")
      ---@cast info_shared rissue.ProviderInfo
      local issues, err = get.get_issues(info_shared, {
        endpoints = {
          issues = {
            { endpoint = "/search/issues", param = { q = "type:issue" } },
          },
          merge_requests = {},
        },
      } --[[@as rissue.Github.Opts]])
      assert(issues, err)
      assert.same({
        {
          author = {
            username = "Nick3C",
            web_url = "https://github.com/Nick3C",
          },
          body = "...",
          created_at = 1247429441,
          id = 132,
          is_open = true,
          labels = {
            {
              color = "ff0000",
              name = "bug",
            },
          },
          title = "Line Number Indexes Beyond 20 Not Displayed",
          url = "https://api.github.com/repos/batterseapower/pinyin-toolkit/issues/132",
          web_url = "https://github.com/batterseapower/pinyin-toolkit/issues/132",
        },
      }, issues)
    end)

    it("issues ok at /issues", function()
      assert.is_not_nil(info_shared, "provider test was not ok")
      ---@cast info_shared rissue.ProviderInfo
      local issues, err = get.get_issues(info_shared, {
        endpoints = {
          issues = {
            { endpoint = "/issues", param = { q = "type:issue" } },
          },
          merge_requests = {},
        },
      } --[[@as rissue.Github.Opts]])
      assert(issues, err)
      assert.same({
        {
          author = {
            username = "octocat",
            web_url = "https://github.com/octocat",
          },
          body = "I'm having a problem with this.",
          created_at = 1303479228,
          id = 1347,
          is_open = true,
          labels = {
            {
              color = "f29513",
              name = "bug",
              description = "Something isn't working",
            },
          },
          title = "Found a bug",
          url = "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          web_url = "https://github.com/octocat/Hello-World/issues/1347",
        },
      }, issues)
    end)

    it("issues ok at /repos/{owner}/{repo}/issues", function()
      assert.is_not_nil(info_shared, "provider test was not ok")
      ---@cast info_shared rissue.ProviderInfo
      local issues, err = get.get_issues(info_shared, {
        endpoints = {
          issues = {
            {
              endpoint = "/repos/{owner}/{repo}/issues",
              param = { q = "type:issue" },
            },
          },
          merge_requests = {},
        },
      } --[[@as rissue.Github.Opts]])
      assert(issues, err)
      assert.same({
        {
          author = {
            username = "octocat",
            web_url = "https://github.com/octocat",
          },
          body = "I'm having a problem with this.",
          created_at = 1303479228,
          id = 1347,
          is_open = true,
          labels = {
            {
              color = "f29513",
              name = "bug",
              description = "Something isn't working",
            },
          },
          title = "Found a bug",
          url = "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          web_url = "https://github.com/octocat/Hello-World/issues/1347",
        },
      }, issues)
    end)

    it("issues ok at /user/issues", function()
      assert.is_not_nil(info_shared, "provider test was not ok")
      ---@cast info_shared rissue.ProviderInfo
      local issues, err = get.get_issues(info_shared, {
        endpoints = {
          issues = {
            {
              endpoint = "/user/issues",
              param = { q = "type:issue" },
            },
          },
          merge_requests = {},
        },
      } --[[@as rissue.Github.Opts]])
      assert(issues, err)
      assert.same({
        {
          author = {
            username = "octocat",
            web_url = "https://github.com/octocat",
          },
          body = "I'm having a problem with this.",
          created_at = 1303479228,
          id = 1347,
          is_open = true,
          labels = {
            {
              color = "f29513",
              name = "bug",
              description = "Something isn't working",
            },
          },
          title = "Found a bug",
          url = "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          web_url = "https://github.com/octocat/Hello-World/issues/1347",
        },
      }, issues)
    end)
  end)
end

local gutils = require("api.github.setup_utils")

describe("github #api", function()
  local utils = require("api.utils")
  utils.with_proxy({
    -- Since the current api description does not support custom, we will just rewrite
    -- all application into application/json
    accept_rewrite = "application/json",
    port = 55000,
    target_port = 55001,
    name = "github cloud",
    prefix = "",
  }, function()
    test_version("api.github.com #github_api", "github_api", {
      additional_info = {
        api_version = "2026-03-10",
      },
      is_proxy = true,
    })
    test_version("ghec #ghec", "ghec", {
      additional_info = {
        api_version = "2026-03-10",
      },
      is_proxy = true,
    })
  end)

  utils.with_proxy({
    name = "github ghes #ghes",
    prefix = "/api/v3",
    port = 55000,
    target_port = 55001,
    -- Since the current api description does not support custom, we will just rewrite
    -- all application into application/json
    accept_rewrite = "application/json",
  }, function()
    for _, version in ipairs(gutils.ghes_2022_versions) do
      local code = gutils.ghes_code_mapped[version]
      if not code then
        error("ghes code equivalent not found for " .. version)
      end
      test_version(
        version .. " #ghes_" .. version .. "_2022", -- e.g. "3.14 #ghes-3.14"
        "ghes-" .. version,

        {
          is_proxy = true,
          additional_info = {
            ghes = version,
            api_version = "2022-11-28",
            ghes_code = code,
          },
          request_opts = {
            api_version = "2022-11-28",
          },
        }
      )
    end

    for _, version in ipairs(gutils.ghes_non_dated_versions) do
      local code = gutils.ghes_code_mapped[version]
      if not code then
        error("ghes code equivalent not found for " .. version)
      end
      test_version(
        version .. " #ghes_" .. version, -- e.g. "3.14 #ghes-3.14"
        "ghes-" .. version,
        {
          is_proxy = true,
          additional_info = {
            ghes = version,
            ghes_code = code,
          },
        }
      )
    end

    for _, version in ipairs(gutils.ghes_2026_versions) do
      local code = gutils.ghes_code_mapped[version]
      if not code then
        error("ghes code equivalent not found for " .. version)
      end
      test_version(
        version .. " #ghes_" .. version .. "_2026", -- e.g. "3.14 #ghes-3.14-2026"
        "ghes-" .. version .. "-2026",
        {
          is_proxy = true,
          additional_info = {
            ghes = version,
            api_version = "2026-03-10",
            ghes_code = code,
          },
          request_opts = {
            api_version = "2026-03-10",
          },
        }
      )
    end
  end)
end)
