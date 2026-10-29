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

-- Github setup

local env = require("rissue.env")
local gutils = require("api.github.setup_utils")
local setup_manager = require("api.setup")
local setup_utils = require("api.setup_utils")
local utils = require("util")

local cwd = utils.get_test_api_path("github")

local tmp_folder = "./.tmp"
local tmp_filename_prefix = tmp_folder .. "/__rissue_setup_github_"

local test_api_path = "./test/api"
local node_modules_path = test_api_path .. "/node_modules/.bin"
local redocly_bin = node_modules_path .. "/redocly"
local redocly_config = test_api_path .. "/github/redocly.yaml"

---@param spec_name string
---@param url string
---@return __rissue.Pipeline
local function spec_pipeline(spec_name, url)
  local dest_path = cwd .. "/" .. spec_name
  local tmp_filename = tmp_filename_prefix .. spec_name
  local tmp_filename_processed = tmp_filename .. "_bundled.json"
  ---@type __rissue.Pipeline
  return {
    setup_manager.p_switch_mode("io"),
    setup_manager.p_curl(
      url,
      tmp_filename,
      { auth = env.get_token("github") },
      { skip_when_file_exists = dest_path }
    ),
    setup_manager.p_register_cleanup(
      ---@async
      function(a, limiters)
        setup_utils.run_pipeline(a, {
          setup_manager.p_rmfile(tmp_filename, { skip_when_fail = true }),
          setup_manager.p_rmfile(
            tmp_filename_processed,
            { skip_when_fail = true }
          ),
        }, limiters)
      end
    ),
    setup_manager.p_switch_mode("cpu"),
    setup_manager.p_run(redocly_bin, {
      args = {
        "bundle",
        tmp_filename,
        "-o",
        tmp_filename_processed,
        "--dereferenced",
        "--config",
        redocly_config,
      },
    }),
    setup_manager.p_switch_mode("io"),
    setup_manager.p_rename(tmp_filename_processed, dest_path),
  }
end

---@param filename string
---@return __rissue.Pipeline
local function empty_file(filename)
  return {
    setup_manager.p_write_f(cwd .. "/" .. filename, ""),
  }
end

local function run()
  ---@type __rissue.Pipeline[]
  local setup_file = {
    --- Github enterprise cloud (api: 2026)
    spec_pipeline(
      "ghec.json",
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghec/dereferenced/ghec.2026-03-10.deref.json"
    ),
    empty_file("server-statistics-advisory-db.yaml"),
    empty_file("server-statistics-packages.yaml"),
    empty_file("server-statistics-actions.yaml"),

    --- Github Public Api (api: 2026)
    spec_pipeline(
      "github_api.json",
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/api.github.com/dereferenced/api.github.com.2026-03-10.deref.json"
    ),
  }
  --
  for _, version in ipairs(gutils.ghes_2022_versions) do
    setup_file[#setup_file + 1] = spec_pipeline(
      "ghes-" .. version .. "-2022.json",
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
        .. version
        .. "/dereferenced/ghes-"
        .. version
        .. ".2022-11-28.deref.json"
    )
  end

  for _, version in ipairs(gutils.ghes_2026_versions) do
    setup_file[#setup_file + 1] = spec_pipeline(
      "ghes-" .. version .. "-2026.json",
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
        .. version
        .. "/dereferenced/ghes-"
        .. version
        .. ".2026-03-10.deref.json"
    )
  end

  for _, version in ipairs(gutils.ghes_non_dated_versions) do
    setup_file[#setup_file + 1] = spec_pipeline(
      "ghes-" .. version .. ".json",
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
        .. version
        .. "/dereferenced/ghes-"
        .. version
        .. ".deref.json"
    )
  end

  setup_utils.mkdir(tmp_folder)
  setup_manager.handle_caching("github", 604800) -- 1 week
  setup_manager.run_setup(cwd, setup_file)
end

return run
