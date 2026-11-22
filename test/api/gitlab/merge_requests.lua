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

--- MERGE REQUESTS

local _busted = require("busted")
local describe = _busted.describe or describe
local it = _busted.it or it
local assert = _busted.assert or assert

local shared = require("api.gitlab.shared")

---@type rissue.MergeRequest
local v19_response = {
  author = {
    display_name = "Administrator",
    username = "admin",
    web_url = "https://gitlab.example.com/root",
  },
  body = "Repellendus impedit et vel velit dignissimos.",
  created_at = 1660740395,
  id = 14,
  labels = { {
    name = "string",
  } },
  state = "canceled",
  title = "Impedit et ut et dolores vero provident ullam est",
  url = "http://127.0.0.1:55000/api/v4/projects/4/issues/14",
  web_url = "https://gitlab.example.com/my-group/my-project/-/merge_requests/1",
}

---@type rissue.MergeRequest
local v9_response = {

  author = {
    display_name = "string",
    username = "string",
    web_url = "string",
  },
  body = "string",
  created_at = 1566656122,
  id = 0,
  labels = { {
    name = "string",
  } },
  state = "canceled",
  title = "string",
  web_url = "string",
}

local default_response = v19_response

---@param name string
---@param rissue rissue
---@param info rissue.ProviderInfo
return function(name, rissue, info)
  local expected_response = name == "v9" and v9_response or default_response
  describe(string.format("mr #gl_%s_mr", name), function()
    it("GET /projects/:id/merge_requests", function()
      ---@type rissue.Gitlab.Opts
      local opts = {
        endpoints = {
          issues = {},
          merge_requests = {
            {
              endpoint = "projects/{repo}/merge_requests",
              param = {},
            },
          },
        },
      }

      local result, err = rissue.get_merge_requests(info, opts)
      assert(not err, err)
      assert.same({
        expected_response,
      }, result)
    end)

    shared.ignore_on({ "v9" }, name, function()
      it("GET /merge_requests", function()
        ---@type rissue.Gitlab.Opts
        local opts = {
          endpoints = {
            issues = {},
            merge_requests = {
              {
                endpoint = "merge_requests",
                param = {},
              },
            },
          },
        }

        local result, err = rissue.get_merge_requests(info, opts)
        assert(not err, err)
        assert.same({
          expected_response,
        }, result)
      end)

      it("GET /groups/:id/merge_requests", function()
        ---@type rissue.Gitlab.Opts
        local opts = {
          endpoints = {
            issues = {},
            merge_requests = {
              {
                endpoint = "groups/rissue-group/merge_requests",
                param = {},
              },
            },
          },
        }

        local result, err = rissue.get_merge_requests(info, opts)
        assert(not err, err)
        assert.same({
          expected_response,
        }, result)
      end)

      --- Should expect GET 200 with empty response
      it("GET /search", function()
        ---@type rissue.Gitlab.Opts
        local opts = {
          endpoints = {
            issues = {},
            merge_requests = {
              {
                endpoint = "search",
                param = {
                  scope = "merge_requests",
                  search = "file",
                },
              },
            },
          },
        }

        local result, err = rissue.get_merge_requests(info, opts)
        ---@diagnostic disable-next-line: redundant-parameter
        assert.equal("Failed to decode response: unexpected response", err)
        assert(not result or #result == 0, "there are unexpected results")
      end)

      --- Should expect GET 200 with empty response
      it("GET /groups/:id/search", function()
        ---@type rissue.Gitlab.Opts
        local opts = {
          endpoints = {
            issues = {},
            merge_requests = {
              {
                endpoint = "groups/rissue-group/search",
                param = {
                  scope = "merge_requests",
                  search = "file",
                },
              },
            },
          },
        }

        local result, err = rissue.get_merge_requests(info, opts)
        ---@diagnostic disable-next-line: redundant-parameter
        assert.equal("Failed to decode response: unexpected response", err)
        assert(not result or #result == 0, "there are unexpected results")
      end)

      --- Should expect GET 200 with empty response
      it("GET /projects/:id/search", function()
        ---@type rissue.Gitlab.Opts
        local opts = {
          endpoints = {
            issues = {},
            merge_requests = {
              {
                endpoint = "projects/{repo}/search",
                param = {
                  scope = "merge_requests",
                  search = "file",
                },
              },
            },
          },
        }

        local result, err = rissue.get_merge_requests(info, opts)
        ---@diagnostic disable-next-line: redundant-parameter
        assert.equal("Failed to decode response: unexpected response", err)
        assert(not result or #result == 0, "there are unexpected results")
      end)
    end)
  end)
end
