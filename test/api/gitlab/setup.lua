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

local _setup_utils = require("api.setup_utils")
local setup = require("api.setup")
local utils = require("util")

local setup_name = "gitlab"

local cwd = utils.get_test_api_path(setup_name)
local tmp_prefix = cwd .. "/__rissue_setup_" .. setup_name .. "_"

local test_api_path = "./test/api"
local assets_folder = test_api_path .. "/.assets"

local redocly_bin = test_api_path .. "/node_modules/.bin/redocly"
local test_gitlab_path = test_api_path .. "/gitlab"
local config1 = test_gitlab_path .. "/redocly_p1.yaml"
local config2 = test_gitlab_path .. "/redocly_p2.yaml"

---@param url string
---@param destname string
---@return __rissue.Pipeline
local function download_asset(url, destname)
  local final_destination = cwd .. "/" .. destname .. ".json"
  local tmp_curl = tmp_prefix .. destname .. "_raw.json"
  local tmp_processed_part1 = tmp_prefix .. destname .. "_processed.json"
  local tmp_processed_part2 = tmp_prefix .. destname .. "_processed_2.json"

  return setup.new_pipeline(destname .. "-external", {
    setup.p_switch_mode("io"),
    setup.p_curl(
      url,
      tmp_curl,
      {},
      { skip_when_file_exists = final_destination }
    ),
    setup.p_register_cleanup({
      setup.p_rmfile(tmp_curl, { skip_when_fail = true }),
      setup.p_rmfile(tmp_processed_part1, { skip_when_fail = true }),
      setup.p_rmfile(tmp_processed_part2, { skip_when_fail = true }),
    }),
    setup.p_switch_mode("cpu"),

    setup.p_run(redocly_bin, {
      args = {
        "bundle",
        tmp_curl,
        "-o",
        tmp_processed_part1,
        "--config",
        config1,
      },
    }),

    setup.p_run(redocly_bin, {
      args = {
        "bundle",
        tmp_processed_part1,
        "-o",
        tmp_processed_part2,
        "--config",
        config2,
      },
    }),
    setup.p_switch_mode("io"),

    setup.p_rename(tmp_processed_part2, final_destination),
  }, { color = utils.assign_color() })
end

---@param sourcename string
---@param destname string
---@return __rissue.Pipeline
local function load_asset(sourcename, destname)
  sourcename = assets_folder .. "/" .. sourcename .. ".json"
  local final_destination = cwd .. "/" .. destname .. ".json"
  return setup.new_pipeline(destname .. "-local", {
    setup.p_copyfile(sourcename, final_destination),
  }, { color = utils.assign_color() })
end

return function()
  ---@type __rissue.Pipeline[]
  local pipeline = {
    download_asset(
      "https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/api/openapi/openapi_v3.yaml",
      "latest"
    ),
    load_asset("gitlab_v19.6.0-ee_openapi_v3", "v19.6"),
    load_asset("gitlab_v9.0.0_openapi", "v9.0"),
  }

  _setup_utils.mkdir(cwd)
  setup.handle_caching(setup_name, 604800) -- 1 week
  setup.run_setup(cwd, pipeline)
end
