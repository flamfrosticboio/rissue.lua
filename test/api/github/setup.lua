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

local gutils = require("api.github.setup_utils")
local sutils = require("api.setup_utils")
local sutils_fn = require("api.setup_utils_fn")

local cwd = sutils.cwd .. "/github"

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
    sutils.p_run("curl", {
      args = { "-sSf", "--remove-on-error", "-L", "-o", tmp_filename, url },
      skip_when_file_exists = dest_path,
    }),
    sutils.p_register_cleanup(function()
      -- incase when the whole pipeline fails
      sutils.p_rmfile(tmp_filename, { skip_when_fail = true })
      sutils.p_rmfile(tmp_filename_processed, { skip_when_fail = true })
    end),
    sutils.p_run(redocly_bin, {
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
    sutils.p_run(redocly_bin, {
      args = {
        "lint",
        tmp_filename_processed,
        "--config",
        redocly_config,
      },
    }),
    sutils.p_rename(tmp_filename_processed, dest_path),
  }
end

---@param filename string
---@return __rissue.Pipeline
local function empty_file(filename)
  return {
    sutils.p_write_f(cwd .. "/" .. filename, ""),
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

  sutils_fn.mkdir(tmp_folder)
  sutils.handle_caching("github", "github", 604800) -- 1 week
  sutils.run_setup(cwd, setup_file)
end

return run
