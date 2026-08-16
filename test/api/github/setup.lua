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

local cmd = require("rissue.utils.cmd")

local cwd = ".test_setup/github"

---@return rissue.cmd[]
local function github_ghec_setup_spec()
  return {
    {
      "curl",
      "-L",
      "-o",
      cwd .. "/ghec.json",
      "https://github.com/octokit/openapi/releases/download/v22.0.0/ghec.deref.json",
    },
    { "touch", cwd .. "/server-statistics-advisory-db.yaml" },
    { "touch", cwd .. "/server-statistics-packages.yaml" },
    { "touch", cwd .. "/server-statistics-actions.yaml" },
  }
end

---@return rissue.cmd[]
local function github_ghes_setup_spec()
  local versions = { "3.14", "3.15", "3.16", "3.17", "3.18", "3.19" }
  local cmds = {}
  for i, version in ipairs(versions) do
    cmds[i] = {
      "curl",
      "-L",
      "-o",
      cwd .. "/ghes-" .. version .. ".json",
      "https://github.com/octokit/openapi/releases/download/v22.0.0/ghes-"
        .. version
        .. ".deref.json",
    }
  end

  return cmds
end

--- Extends an array in place
---@generic T: any
---@param source_list T[]
---@param new_list T[]
local function extend(source_list, new_list)
  local offset = #source_list
  for i = 1, #new_list do
    source_list[i + offset] = new_list[i]
  end
end

---@param arg string
---@return string
local function shell_escape(arg)
  local needs_escape = arg == "" or arg:find("[^%w%-%._/]") ~= nil
  if needs_escape then
    return "'" .. arg:gsub("'", "'\\''") .. "'"
  end
  return arg
end

local function setup()
  local exists = os.execute('[ -d "' .. cwd .. '" ]')
  if exists == 0 then
    print("Already did setup")
    return
  end
  cmd.run({ "mkdir", "-p", cwd })
  print("Directory created")

  local cmds = {}
  extend(cmds, github_ghec_setup_spec())
  extend(cmds, github_ghes_setup_spec())

  print("Running commands: ")
  for _, cmd_ in ipairs(cmds) do
    local res = {}

    for i = 1, #cmd_ do
      res[i] = shell_escape(cmd_[i])
    end
    print("$ " .. table.concat(res, " "))
  end

  local errors = {}
  local total = #cmds
  local remaining = 0

  local results = cmd.run_multiple(cmds, function(cmd_)
    remaining = remaining + 1
    for i = 1, #cmd_ do
      cmd_[i] = shell_escape(cmd_[i])
    end
    print(
      tostring(remaining) .. "/" .. tostring(total) .. ": " .. table.concat(cmd_, " ")
    )
  end)

  for current_cmd, result in pairs(results) do
    if result.return_code ~= 0 then
      local contents = result.stderr.contents ~= "" and result.stderr.contents
        or result.stdout.contents
      errors[#errors + 1] = (
        "failed to run '"
        .. table.concat(current_cmd, " ")
        .. "':\n"
        .. contents
      )
    end
  end

  if #errors > 0 then
    error(table.concat({ "Errors occurred:", unpack(errors) }, "\n\n"))
    os.execute()
  end

  print("Finished without any issues")
end

return setup
