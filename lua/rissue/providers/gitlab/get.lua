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

local get = {}

local fetch = require("rissue.providers.gitlab.fetch")
local time = require("rissue.utils.time")

---@param info rissue.ProviderInfo
local function into_base_api_url(info)
  return info.protocol .. "://" .. info.domain .. "/api/v4"
end

---@param labels string[]
---@return rissue.Label[]
local function construct_labels(labels)
  local res = {} ---@type rissue.Label[]
  for i, label in ipairs(labels) do
    res[i] = { name = label }
  end
  return res
end

---@param author rissue.Gitlab.UserBasic
---@return rissue.User
local function construct_author(author)
  return {
    username = author.username or author.public_email or "<unknown username>",
    web_url = author.web_url,
    display_name = author.name,
  }
end

---@param res rissue.Gitlab.IssueResponse | rissue.Gitlab.MergeRequestResponse
---@param info rissue.ProviderInfo
---@return string?
local function get_api_url(res, info)
  if res._links then
    return res._links.self
  end

  if res.project_id and res.iid then
    return string.format(
      "%s/projects/%d/issues/%d",
      into_base_api_url(info),
      math.floor(res.project_id),
      math.floor(res.iid)
    )
  end
end

---@param res rissue.Gitlab.IssueResponse
---@param should_pass_raw boolean
---@param info rissue.ProviderInfo
---@return rissue.Issue
local function construct_issue(res, should_pass_raw, info)
  ---@type rissue.Issue
  return {
    web_url = res.web_url,
    title = res.title or "<unknown title>",
    created_at = res.created_at and time.iso_to_timestamp_utc(res.created_at)
      or -1,
    url = get_api_url(res, info),
    id = res.iid,
    labels = construct_labels(res.labels),
    author = construct_author(res.author),
    body = res.description,
    raw = should_pass_raw and res or nil,
    is_open = res.state == "opened",
  }
end

---@param state "opened" | "closed" | "locked" | "merged"
---@return rissue.mr.State
local function map_state(state)
  if state == "opened" then
    return "open"
  elseif state == "merged" then
    return "merged"
  else
    return "canceled"
  end
end

---@param res rissue.Gitlab.MergeRequestResponse
---@param should_pass_raw boolean
---@param info rissue.ProviderInfo
---@return rissue.MergeRequest
local function construct_merge_requests(res, should_pass_raw, info)
  ---@type rissue.MergeRequest
  return {
    web_url = res.web_url,
    title = res.title or "<unknown title>",
    created_at = res.created_at and time.iso_to_timestamp_utc(res.created_at)
      or -1,
    url = get_api_url(res, info),
    id = res.iid,
    labels = construct_labels(res.labels),
    author = construct_author(res.author),
    body = res.description,
    raw = should_pass_raw and res or nil,
    state = map_state(res.state),
  }
end

---@async
---@type rissue.provider.GetIssues<nil, rissue.Gitlab.Config>
function get.issues(async, info, tok, opts, cb)
  return fetch(async, {
    queries = opts.endpoints.issues,
    cb = function(res)
      cb(construct_issue(res, opts.should_pass_raw, info))
    end,
    config = opts,
    info = info,
    token = tok,
  })
end

---@async
---@type rissue.provider.GetMergeRequests<nil, rissue.Gitlab.Config>
function get.merge_requests(async, info, tok, opts, cb)
  return fetch(async, {
    queries = opts.endpoints.merge_requests,
    cb = function(res)
      cb(construct_merge_requests(res, opts.should_pass_raw, info))
    end,
    config = opts,
    info = info,
    token = tok,
  })
end

return get
