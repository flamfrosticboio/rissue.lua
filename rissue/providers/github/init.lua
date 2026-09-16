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

local config = require("rissue.providers.github.config")
local curl = require("rissue.utils.curl")
local fmt = require("rissue.utils.fmt")
local json = require("rissue.utils.json")
local log = require("rissue.utils.log")
local supports = require("rissue.providers.github.supports")
local table_op = require("rissue.utils.table_op")
local time = require("rissue.utils.time")

---@param info rissue.ProviderInfo<rissue.Github.supports.AdditionalInfo>
local function get_api_endpoint(info)
  return info.protocol
    .. "://"
    .. info.domain
    .. (info.additional_info and info.additional_info.ghes == true and "/api/v3" or "")
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
    if result.incomplete_results == true then
      return result.items, "response has incomplete results"
    end
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
      accept = ("Accept: application/vnd.github.%s+json"):format(
        opts.settings.media_type
      ),
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

        if raw_items and unmapping_error then
          log.warn("Warning: " .. unmapping_error)
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
    headers[#headers + 1] = config.api_ver_template .. info.additional_info.api_version
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
  supports = supports.main,
  get_merge_requests = get_merge_requests,
  get_issues = get_issues,
  settings = config.default,
}
