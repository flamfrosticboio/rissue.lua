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

local config = require("rissue.providers.github.config")
local fetch = require("rissue.providers.github.fetch")
local supports = require("rissue.providers.github.supports")
local time = require("rissue.utils.time")

---@param raw table
---@param settings rissue.Github.Settings
---@return rissue.item.base
local function into_base(raw, settings)
  ---@type rissue.label[]
  local labels = {}

  for _, label in ipairs(raw.labels) do
    labels[#labels + 1] = {
      name = label.name,
      color = label.color,
      description = label.description,
    }
  end

  ---@type rissue.item.base
  return {
    title = raw.title,
    web_url = raw.html_url,
    body = raw.body or raw.body_html or raw.body_text,
    id = raw.number,
    url = raw.url,
    author = {
      web_url = raw.user.html_url,
      username = raw.user.login,
      display_name = raw.user.name,
    },
    created_at = time.iso_to_timestamp_utc(raw.created_at),
    labels = labels,
    raw = settings.store_raw and raw or nil,
  }
end

---@param raw table
---@param settings rissue.Github.Settings
---@return rissue.issue
local function into_issue(raw, settings)
  local base = into_base(raw, settings)
  ---@cast base rissue.issue
  base.is_open = raw.state == "open"
  return base
end

---@param raw table
---@return rissue.pr.State
local function pr_state(raw)
  if raw.state == "open" then
    return "open"
  end
  if raw.merged or raw.merged_at ~= nil then
    return "merged"
  end
  return "canceled"
end

---@param raw table
---@param settings rissue.Github.Settings
---@return rissue.pr
local function into_merge_requests(raw, settings)
  local base = into_base(raw, settings)
  ---@cast base rissue.pr
  base.state = pr_state(raw)
  return base
end

---@type rissue.provider.GetIssues<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
local function get_issues(info, token, opts)
  return fetch.try_fetch(info, opts.endpoints.issues, {
    parser = into_issue,
    key = function(item)
      return item.id
    end,
    settings = opts,
    token = token,
  })
end

---@type rissue.provider.GetMergeRequests<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
local function get_merge_requests(info, token, opts)
  return fetch.try_fetch(info, opts.endpoints.merge_requests, {
    parser = into_merge_requests,
    key = function(item)
      return item.id
    end,
    settings = opts,
    token = token,
  })
end

---@type rissue.Provider
return {
  name = "github",
  version = "0.1",
  version_code = 1000,
  supports = supports.main,
  get_merge_requests = get_merge_requests,
  get_issues = get_issues,
  settings = config.default,
}
