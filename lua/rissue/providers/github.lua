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
local table_op = require("rissue.utils.table_op")
local time = require("rissue.utils.time")

--- !TYPES

---@alias rissue.Github.SupportedApiVersions "2026-03-10" | "2022-11-28"

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.SupportedApiVersions?

---@class rissue.Github.opts.Endpoints
---@field issues rissue.Query[]
---@field merge_requests rissue.Query[]

---@class rissue.Github.Settings
--- Required field on param in each query: `q`
--- `q` can be used as template string.
---
--- Supported template strings for `q`:
--- - `{owner}` - Repository owner
--- - `{repo}` - Repository name
---
--- See default settings for examples.
---@field endpoints rissue.Github.opts.Endpoints
--- Override the api version to be used.
--- Most commonly used when doing requests like `get.issues()` or `get.merge_requests()`
---
--- Setting it to false removes the api_version header to be sent to the server.
---
--- **Warning: NOT RECOMMENDED TO BE SET ON USER SETTINGS**
---@field api_version? rissue.Github.SupportedApiVersions | false
--- Limits how many items will be fetched and rendered.
--- Note: This does not guarantee the output size of the result to be exactly `max_items`
---       and may have more items than requested
---@field max_items integer
--- Defines how many items are fetched per page when performing pagination requests in github. Limit=100
---@field items_per_page integer
--- Settings on the parallel fetching.
--- When this option is `true`, it will be always enabled
--- When this option is `false`, it will be always disabled (fallback to fetching sequentially).
--- When this option is an integer, it will act as a threshold comparing `max_items` ``(max_items >= threshold)``
---@field parallel_fetching boolean | integer

--- Partial version of rissue.Github.Settings
---@class (partial) rissue.Github.Opts: rissue.Github.Settings

--- /!TYPES

--- !SETTINGS

---@type rissue.Github.Settings
local default_settings = {
  endpoints = {
    issues = {
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
    merge_requests = {},
  },
  parallel_fetching = 50,
  max_items = 100,
  items_per_page = 100,
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
  local result, err = curl.request(url, opts)
  if not result then
    log.warn(("Failed to fetch endpoint '%s': %s"):format(url, err))
  end

  return not not (result and result.content:match("verifiable_password_authentication")),
    result and result.content
end

---@type rissue.provider.Supports<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
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

      if type(opts.api_version) == "string" then
        additional_info.api_version = opts.api_version
      elseif opts.api_version ~= false then
        additional_info.api_version = from_range(ghes_api_versions_range, version)
      end
    end
    return true, additional_info
  end

  -- ghec or api.github.com version (when checking with url failed)
  -- examples includes: domain proxy, GHEC with Data Residency
  local res = check(base .. "/meta", settings)
  if res then
    return res, { api_version = "2026-03-10" } --[[@as rissue.Github.supports.AdditionalInfo]]
  end
  return false
end

--- Parses github's link header into a table.
--- Common or to be expected:
--- - `next` - `link?`
--- - `last` - `link?`
--- - `first` - `link?`
---@param link_header_raw string
---@return table<string, string>
local function parse_link_header(link_header_raw)
  local links = {}
  for pointer, name in link_header_raw:gmatch('<(%S+)>;%s*rel="(%S+)"') do
    links[name] = pointer
  end
  return links
end

---@param result any
---@return any[]? results
---@return string? errors
local function unmap_result(result)
  if type(result) ~= "table" then
    return nil, "not a table"
  end

  if type(result.status) == "string" then
    return nil,
      ("%s: %s"):format(result.status, (result.message or "no message provided"))
  end

  -- If the result was a kind of search (search/issues)
  if type(result.items) == "table" and type(result.total_count) == "number" then
    return result.items
  elseif table_op.is_list(result) then
    return result
  end

  return nil, "unknown pattern"
end

---@param raw table
---@return rissue.issue
local function into_issue(raw)
  ---@type rissue.label[]
  local labels = {}

  for _, label in ipairs(raw.labels) do
    labels[#labels + 1] = {
      name = label.name,
      color = label.color,
      description = label.description,
    }
  end

  ---@type rissue.issue
  return {
    is_open = raw.state == "open",
    title = raw.title,
    web_url = raw.html_url,
    body = raw.body,
    id = raw.number,
    url = raw.url,
    author = {
      web_url = raw.user.html_url,
      username = raw.user.login,
      display_name = raw.user.name,
    },
    created_at = time.iso_to_timestamp_utc(raw.created_at),
    labels = labels,
  }
end

---@class __rissue.Github.FetchPagingOpts
---@field endpoint string
---@field query rissue.Query
---@field token string?
---@field buffer table<integer, any>
---@field settings rissue.Github.Settings
---@field mapper fun(item: any): any

--- Fetches the items where the endpoint is a paging.
--- Stops fetching other pages when the buffer size reaches the target size.
--- The buffer would may be larger than the target size.
---@param opts __rissue.Github.FetchPagingOpts
local function fetch_paging(opts)
  local use_endpoint_raw = false

  while true do
    if table_op.count(opts.buffer) > opts.settings.max_items then
      break
    end

    ---@type rissue.utils.curl.Opts
    local curl_opts = {
      auth = opts.token,
      accept = accept_type,
      method = "GET",
      include_result_headers = true,
    }

    -- the link header provides an api link to the next page
    -- if use_endpoint_raw is true, expect endpoint to point to
    -- this api link of the next page
    if not use_endpoint_raw then
      opts.query.param.page = "1"
      curl_opts.data = opts.query.param
      curl_opts.data_type = "urlencode"
    end

    local result, fetch_err = curl.request(opts.endpoint, curl_opts)

    if result then
      local ok, err = pcall(function()
        local decoded_result, decode_error = json.decode(result.content)
        if decode_error then
          error(decode_error, 0)
        end

        local raw_items, unmapping_error = unmap_result(decoded_result)
        if not raw_items then
          error(
            "Error occurred when decoding result: "
              .. (unmapping_error or "unhandled error"),
            0
          )
        end

        for _, item in ipairs(raw_items) do
          local issue = opts.mapper(item)
          opts.buffer[issue.id] = issue
        end
      end)

      if not ok then
        log.error(err or "An unknown error occurred when decoding response into issue")
        break
      end

      if not result.headers.link then
        break
      end

      local link_headers = parse_link_header(result.headers.link)
      if link_headers.next then
        use_endpoint_raw = true
        opts.endpoint = link_headers.next
      end
    else
      log.warn("Failed to fetch an endpoint: " .. (fetch_err or "unhandled error"))
    end
  end
end

--- Fetches the endpoints in sequential synchronous order
---@param info rissue.ProviderInfo
---@param token string?
---@param base_endpoint string
---@param endpoints rissue.Query[]
---@param settings rissue.Github.Settings
local function fetch_sequential(info, token, base_endpoint, endpoints, settings)
  local results = {}

  for _, query in ipairs(endpoints) do
    --- todo: add switch to parallel fetching on each query endpoint if limits are threshold (default=50)
    --- If link header is present, we just use that until there is no more rel=next.
    --- NOTE: Sometimes, there will be validation failed because you have more than 5 boolean operators (AND, OR, NOT)
    --- NOTE : There is incomplete_results on the /search pagination field

    if table_op.count(results) > settings.max_items then
      break
    end

    ---@type string
    local endpoint = base_endpoint .. query.endpoint

    if not query.param.q then
      return nil, "Query has no 'q' passed on query.param"
    end

    query.param.q = fmt(query.param.q, {
      owner = info.owner,
      repo = info.repo,
    })

    query.param.per_page = tostring(settings.items_per_page)

    fetch_paging({
      buffer = results,
      endpoint = endpoint,
      query = query,
      token = token,
      settings = settings,
      mapper = into_issue,
    })
  end

  return table_op.set_into_list(results)
end

---@type rissue.provider.GetIssues<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
local function get_issues(info, token, opts)
  -- todo: fix tests proxy not working on support with /api/v3

  local base_endpoint = get_api_endpoint(info)

  local headers = {}
  if info.additional_info and info.additional_info.api_version then
    headers[#headers + 1] = api_ver_template .. info.additional_info.api_version
  end

  local use_parallel_fetching = opts.parallel_fetching
  if
    use_parallel_fetching == true
    or type(use_parallel_fetching) == "number"
      and opts.max_items >= use_parallel_fetching
  then
    return nil, "Not yet implemented"
  else
    return fetch_sequential(info, token, base_endpoint, opts.endpoints.issues, opts)
  end
end

---@type rissue.provider.GetMergeRequests<rissue.Github.supports.AdditionalInfo, rissue.Github.Settings>
local function get_merge_requests(_info, _token, _opts) end

---@type rissue.Provider
return {
  name = "github",
  version = "0.1",
  version_code = 1000,
  supports = supports,
  get_merge_requests = get_merge_requests,
  get_issues = get_issues,
  settings = default_settings,
}
