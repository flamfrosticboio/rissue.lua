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

-- Github setup

local gutils = require("api.github.setup_utils")
local sutils = require("api.setup_utils")

return function()
  local cwd = sutils.cwd .. "/github"

  ---@type __rissue.SetupConfig
  local setup_file = {
    cache = {
      name = "github",
      folder = "github",
      ttl = 7 * 24 * 60 * 60, -- 1 week
    },

    --- Github enterprise cloud (api: 2026)
    sutils.setup_command(cwd .. "/ghec.json", "./scripts/curl_safe.sh", {
      true,
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghec/dereferenced/ghec.2026-03-10.deref.json",
    }),
    sutils.setup_file(cwd .. "/server-statistics-advisory-db.yaml", ""),
    sutils.setup_file(cwd .. "/server-statistics-packages.yaml", ""),
    sutils.setup_file(cwd .. "/server-statistics-actions.yaml", ""),

    --- Github Public Api (api: 2026)
    sutils.setup_command(cwd .. "/github_api.json", "./scripts/curl_safe.sh", {
      true,
      "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/api.github.com/dereferenced/api.github.com.2026-03-10.deref.json",
    }),
  }

  for _, version in ipairs(gutils.ghes_2022_versions) do
    setup_file[#setup_file + 1] = sutils.setup_command(
      cwd .. "/ghes-" .. version .. ".json",
      "./scripts/curl_safe.sh",
      {
        true,
        "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
          .. version
          .. "/dereferenced/ghes-"
          .. version
          .. ".2022-11-28.deref.json",
      }
    )
  end

  for _, version in ipairs(gutils.ghes_2026_versions) do
    setup_file[#setup_file + 1] = sutils.setup_command(
      cwd .. "/ghes-" .. version .. "-2026.json",
      "./scripts/curl_safe.sh",
      {
        true,
        "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
          .. version
          .. "/dereferenced/ghes-"
          .. version
          .. ".2026-03-10.deref.json",
      }
    )
  end

  for _, version in ipairs(gutils.ghes_non_dated_versions) do
    setup_file[#setup_file + 1] = sutils.setup_command(
      cwd .. "/ghes-" .. version .. ".json",
      "./scripts/curl_safe.sh",
      {
        true,
        "https://raw.githubusercontent.com/github/rest-api-description/refs/heads/main/descriptions/ghes-"
          .. version
          .. "/dereferenced/ghes-"
          .. version
          .. ".deref.json",
      }
    )
  end

  sutils.run_setup(cwd, setup_file)
end
