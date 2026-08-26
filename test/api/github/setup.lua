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

local sutils = require("api.setup_utils")

local cwd = ".test_setup/github"

return function()
  ---@type __rissue.SetupConfig
  local setup_file = {
    --- Github enterprise cloud
    sutils.setup_command(cwd .. "/ghec.json", "./scripts/curl_safe.sh", {
      true,
      "https://unpkg.com/@octokit/openapi@22.0.0/generated/ghec.deref.json",
    }),
    sutils.setup_file(cwd .. "/server-statistics-advisory-db.yaml", ""),
    sutils.setup_file(cwd .. "/server-statistics-packages.yaml", ""),
    sutils.setup_file(cwd .. "/server-statistics-actions.yaml", ""),

    --- Github Public Api
    sutils.setup_command(cwd .. "/github_api.json", "./scripts/curl_safe.sh", {
      true,
      "https://unpkg.com/@octokit/openapi@22.0.0/generated/api.github.com.deref.json",
    }),
  }

  local ghes_versions = { "3.14", "3.15", "3.16", "3.17", "3.18", "3.19" }
  for _, version in ipairs(ghes_versions) do
    setup_file[#setup_file + 1] = sutils.setup_command(
      cwd .. "/ghes-" .. version .. ".json",
      "./scripts/curl_safe.sh",
      {
        true,
        "https://unpkg.com/@octokit/openapi@22.0.0/generated/ghes-"
          .. version
          .. ".deref.json",
      }
    )
  end

  sutils.run_setup(cwd, setup_file)
end
