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

local curl = require("rissue.utils.curl")
local fmt = require("rissue.utils.fmt")
local json = require("rissue.utils.json")
local log = require("rissue.utils.log")

--- !TYPES

---@alias rissue.Github.SupportedApiVersions "2026-03-10" | "2022-11-28"

--- Additional options when checking provider support
---@class rissue.Github.supports.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

--- Additional options when checking provider support
---@class rissue.Github.get_merge_requests.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

--- Additional options when checking provider support
---@class rissue.Github.get_issues.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.SupportedApiVersions?

---@class rissue.Github.Opts
---@field endpoints string[]

---@class rissue.Github.Settings
--- Required field on param in each query: `q`
--- `q` can be used as template string.
---
--- Supported template strings for `q`:
--- - `{owner}` - Repository owner
--- - `{repo}` - Repository name
---
--- See default settings for examples.
---@field endpoints rissue.Query[]

--- /!TYPES

--- !SETTINGS

local default_settings = {
  ---@type rissue.Query[]
  endpoints = {
    {
      endpoint = "/search/issues",
      param = {
        q = "repo:{owner}/{repo} type:issue is:open label:security,critical",
        sort = "interactions",
        order = "desc",
      },
    },
    {
      endpoint = "/search/issues",
      param = {
        q = "repo:{owner}/{repo} type:issue is:open label:blocker,P0",
        sort = "interactions",
        order = "desc",
      },
    },
    {
      endpoint = "/search/issues",
      param = {
        q = "repo:{owner}/{repo} type:issue is:open",
        sort = "interactions",
        order = "desc",
      },
    },
  },
}

--- /!SETTINGS

--- !TECHNICAL:GITHUB_GHES_RANGE

--- Api version will be chosen by the table below
--- uses (abbb scheme) (a = major; b = minor)

local ghes_latest = 03022
---@type {[1]: integer, [2]: integer, [3]: string}[]
local ghes_api_versions_range = {
  { 03009, 03020, "2022-11-28" }, -- ghes 3.9-3.20
  { 03021, ghes_latest, "2026-03-10" }, -- ghes 3.21+
}

--- /!TECHNICAL:GITHUB_GHES_RANGE

local accept_type = "application/vnd.github.raw+json"
local api_ver_template = "X-GitHub-Api-Version: "

---@generic T
---@param range {[1]: integer, [2]: integer, [3]: T}[]
---@param target integer
---@return T?
local function from_range(range, target)
  for _, val in ipairs(range) do
    if val[1] <= target and val[2] >= target then
      return val[3]
    end
  end
end

---@class rissue.Provider.Opts: table
---@field custom_fetch_endpoints string[]

---@param info rissue.ProviderInfo<rissue.Github.supports.AdditionalInfo>
local function get_api_endpoint(info)
  return info.protocol
    .. "://"
    .. info.domain
    .. (info.additional_info and info.additional_info.ghes == true and "/api/v3" or "")
end

---@param url string
---@param opts rissue.utils.curl.Opts
---@return boolean
---@return string? result
local function check(url, opts)
  local result, exit_code = curl.request(url, opts)
  if exit_code ~= 0 then
    log.warn(("Failed to fetch endpoint '%s': %s"):format(url, result))
  end

  return exit_code == 0 and result:match("verifiable_password_authentication"), result
end

---@type rissue.provider_info.Supports<rissue.Github.supports.Opts, rissue.Github.Opts, rissue.Github.supports.AdditionalInfo>
local function supports(info, token, opts)
  local base = info.curl_protocol .. "://" .. info.domain

  ---@type rissue.utils.curl.Opts
  local settings = { auth = token, accept = "application/json", method = "GET" }

  -- ghes version
  local is_ghes, ghes_output = check(base .. "/api/v3/meta", settings)
  if is_ghes then
    ---@type rissue.Github.supports.AdditionalInfo
    local additional_info = {}
    if ghes_output then
      local major, minor = ghes_output:match('"installed_version":%s*"(%d+)%.(%d+)')
      local version = tonumber(major) * 1000 + tonumber(minor)
      additional_info.ghes = major .. "." .. minor
      additional_info.ghes_code = version

      if opts.request then
        if type(opts.request.api_version) == "string" then
          additional_info.api_version = opts.request.api_version
        end
        -- do nothing if api_version is false or any other types
      else
        additional_info.api_version = from_range(ghes_api_versions_range, version)
      end
    end
    return true, additional_info
  end

  -- ghec or api.github.com version (when checking with url failed)
  -- examples includes: domain proxy, GHEC with Data Residency
  local res = check(base .. "/meta", settings)
  return res
end

---@param result any
---@return any[]?
local function unmap_result(result)
  -- If the result was a kind of search (search/issues)
  if type(result.items) == "table" and type(result.total_count) == "number" then
    return result.items
  end
end

---@param raw table
---@return rissue.issue
local function into_issue(raw)
  ---@type rissue.issue
  return {
    is_open = raw.state == "open",
    title = raw.title,
    web_url = raw.html_url,
    id = raw.number,
    url = raw.url,
    author = {
      web_url = raw.user.html_url,
      username = raw.user.login,
      display_name = raw.user.name,
    },
    created_at = tonumber(raw.created_at) or 0, --- todo: add tz reader
    labels = {}, -- todo: complete reading labels
  }
end

---@type rissue.provider_info.GetIssues<rissue.Github.get_issues.Opts, rissue.Github.Opts, rissue.Github.supports.AdditionalInfo>
local function get_issues(info, token, opts)
  ---@type rissue.Query[]
  local endpoints = opts.settings.endpoints or default_settings.endpoints
  local base_endpoint = get_api_endpoint(info)

  local headers = {}
  if info.additional_info and info.additional_info.api_version then
    headers[#headers + 1] = api_ver_template .. info.additional_info.api_version
  end

  for _, query in ipairs(endpoints) do
    --- todo: add switch to parallel fetching on each query endpoint if limits are threshold (default=50)
    --- If link header is present, we just use that until there is no more rel=next.
    --- NOTE: Sometimes, there will be validation failed because you have more than 5 boolean operators (AND, OR, NOT)
    --- NOTE : There is incomplete_results on the /search pagination field

    ---@type string
    local endpoint = base_endpoint .. query.endpoint

    if not query.param.q then
      error("Query has no 'q' passed on query.param", 0)
    end

    query.param.q = fmt(query.param.q, {
      owner = info.owner,
      repo = info.repo,
    })

    local result, exit_code = curl.request(endpoint, {
      auth = token,
      accept = accept_type,
      data_type = "urlencode",
      data = query.param,
      method = "GET",
    })

    if exit_code == 0 then
      local ok, decoded_result = pcall(function()
        local decoded, err = json.decode(result)
        if not decoded then
          error(err, 0)
        end
        return decoded
      end)
      local items = unmap_result(decoded_result)
      if items then
        for _, item in ipairs(items) do
          local issue = into_issue(item)
          print(require("inspect")(issue))
        end
      end
    end
  end
end

---@type rissue.provider_info.GetIssues<rissue.Github.get_merge_requests.Opts, rissue.Github.Opts, rissue.Github.supports.AdditionalInfo>
local function get_merge_requests(_info, _token, _opts) end

---@type rissue.provider_spec
return {
  provider_name = "github",
  supports = supports,
  get_merge_requests = get_merge_requests,
  get_issues = get_issues,
}
