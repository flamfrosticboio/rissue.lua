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

local test_files = ".test_setup/github"

local M = {}

---@param name string
---@param id integer A unique id
function M.test_version(name, id)
  local utils = require("api.utils")
  local provider = require("rissue.provider")
  describe("provider github enterprise #api", function()
    utils.with_server(name, id, test_files .. "/" .. name .. ".json", function()
      it("found provider", function()
        local ok, info = provider.get_provider_info(
          "http://" .. utils.host .. ":" .. utils.port .. "/owner/repo.git"
        )
        if not ok then
          error(info)
        end

        assert.same({
          domain = tostring(utils.host) .. ":" .. tostring(utils.port + id),
          name = "github",
          owner = "owner",
          repo = "repo",
          protocol = "http", -- since prism is launched in http mode
        } --[[@as rissue.ProviderInfo]], info)
      end)
    end)
  end)
end

return M
