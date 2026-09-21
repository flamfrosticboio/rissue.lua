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

local curl = require("rissue.utils.curl")
local fmt = require("rissue.utils.fmt")
local json = require("rissue.utils.json")
local log = require("rissue.utils.log")
local process = require("rissue.utils.process")
local table_op = require("rissue.utils.table_op")

local config = require("rissue.providers.github.config")

local M = {}

---@param info rissue.ProviderInfo<rissue.Github.supports.AdditionalInfo>
---@return string
local function construct_base_endpoint(info)
  return info.protocol
    .. "://"
    .. info.domain
    .. (
      info.additional_info and info.additional_info.ghes == true and "/api/v3"
      or ""
    )
end

--- Gets the next url from link header
---@param link_header_raw string
---@return string?
local function get_next_from_link_header(link_header_raw)
  return link_header_raw:match('<(%S+)>;%s*rel="next"')
end

---@class __rissue.Github.unmap.Result
---@field total_count integer? Returns total_count field if available
---@field items any[] An array of raw items

---@param result any
---@return __rissue.Github.unmap.Result? results
---@return string? errors
local function unmap(result)
  if type(result) ~= "table" then
    return nil, "not a table"
  end

  if type(result.status) == "string" then
    return nil,
      ("%s: %s"):format(
        result.status,
        (result.message or "no message provided")
      )
  end

  -- If the result was a kind of search ('/search/issues')
  if type(result.items) == "table" and type(result.total_count) == "number" then
    ---@type __rissue.Github.unmap.Result
    local res = {
      total_count = result.total_count,
      items = result.items,
    }
    if result.incomplete_results == true then
      return res, "response has incomplete results"
    end
    return res
  elseif table_op.is_list(result) then
    -- If the result was just normal
    return { items = result }
  end

  return nil, "unknown pattern"
end

--- Warning: raises errors
---@param opts rissue.utils.curl.Opts
---@return rissue.utils.curl.Result? result
---@return string? error
local function try_fetch_query(url, param, opts)
  opts.data_type = "urlencode"
  opts.data = param

  local req, err = curl.request(url, opts)
  if req then
    req.content = req.content:match("^%s*(.-)%s*$")
    req.err = req.err:match("^%s*(.-)%s*$")
  end

  return req, err
end

---@class __rissue.Github.prepare_page.Opts
---@field query rissue.Query
---@field fmt_opts table<string, string>
---@field fetch_opts __rissue.Github.fetch.Opts
---@field base string
---@field page integer?

---@param opts __rissue.Github.prepare_page.Opts
---@return rissue.Query query
local function prepare_page(opts)
  local endpoint = opts.base .. fmt(opts.query.endpoint, opts.fmt_opts)
  local param = table_op.force_deep_extend(opts.query.param)
  param.q = fmt(param.q, opts.fmt_opts)
  param.per_page = opts.fetch_opts.settings.items_per_page
  param.page = tostring(opts.page or 1)

  return { endpoint = endpoint, param = param } --[[@as rissue.Query]]
end

---@class __rissue.Github.fetch_page.Opts
---@field query rissue.Query
---@field curl_opts rissue.utils.curl.Opts

---@class __rissue.Github.fetch_page.Result
---@field contents __rissue.Github.unmap.Result
---@field next_url string?

---@param opts __rissue.Github.fetch_page.Opts
---@return __rissue.Github.fetch_page.Result? result
---@return string? error
local function try_fetch_page(opts)
  local response, fetch_err =
    try_fetch_query(opts.query.endpoint, opts.query.param, opts.curl_opts)

  if response and response.exitcode == 0 then
    local ok, res = pcall(function()
      local decoded, decode_err = json.decode(response.content)
      if decode_err then
        error(decode_err, 0)
      end

      local unmapped, unmap_err = unmap(decoded)
      if not unmapped then
        error(unmap_err or "unknown error", 0)
      elseif unmap_err then
        log.warn(unmap_err)
      end

      return unmapped
    end)

    if not ok then
      return nil, res --[[@as string]] or "unknown error"
    end

    if not response.headers then
      return nil, "Could not get headers from response (bug)"
    end

    return {
      contents = res,
      next_url = response.headers.link and get_next_from_link_header(
        response.headers.link
      ) or nil,
    } --[[@as __rissue.Github.fetch_page.Result]]
  else
    if log.level_enabled(log.levels.error) then
      local message = "Failed to fetch: "
        .. (response and response.err or fetch_err or "unknown error")
      if response and response.content ~= "" then
        message = message .. "\nServer responded: " .. response.content
      end

      log.log(message, log.levels.error)
    end

    return nil, response and response.err or fetch_err
  end
end

---@param delay integer Delay in milliseconds
local function delay_with_warning(delay)
  local delay_ok, delay_err = process.try_delay(delay)
  if not delay_ok then
    log.warn("Failed to delay: " .. (delay_err or "unknown error"))
  end
end

---@class __rissue.Github.fetch.Opts<T, K>
---@field token string?
---@field parser fun(raw: any, settings: rissue.Github.Settings): T
---@field key fun(item: T): K
---@field settings rissue.Github.Settings

---@generic T, K
---@param info rissue.ProviderInfo<rissue.Github.supports.AdditionalInfo>
---@param queries rissue.Query[]
---@param opts __rissue.Github.fetch.Opts
---@return T[]? results
---@return string? error
function M.try_fetch(info, queries, opts)
  if opts.settings.items_per_page > 100 then
    return nil, "Setting 'items_per_page' cannot be above 100"
  end

  local buffer = {}
  local base = construct_base_endpoint(info)
  local headers = {}
  if info.additional_info and info.additional_info.api_version then
    headers[#headers + 1] = config.api_ver_template
      .. info.additional_info.api_version
  end

  ---@type rissue.utils.curl.Opts
  local curl_opts_reusable = {
    headers = headers,
    accept = ("application/vnd.github.%s+json"):format(
      opts.settings.media_type
    ),
    method = "GET",
    auth = opts.token,
    fail_fast = true,
    include_result_headers = true,
  }

  local fmt_opts = {
    owner = info.owner,
    repo = info.repo,
  }

  local function is_full()
    return table_op.count(buffer) >= opts.settings.max_items
  end

  local function parse_items(items)
    for _, item in ipairs(items) do
      local parsed = opts.parser(item, opts.settings)
      buffer[opts.key(parsed)] = parsed
    end
  end

  for _, query in ipairs(queries) do
    if not query.param.q then
      return nil, "'q' is not passed on query: " .. query.endpoint
    end

    query = prepare_page({
      base = base,
      fetch_opts = opts,
      fmt_opts = fmt_opts,
      query = query,
      page = 1,
    })

    while not is_full() do
      local result, err = try_fetch_page({
        query = query,
        curl_opts = curl_opts_reusable,
      })

      if not result then
        log.error("Failed to fetch: " .. (err or "unknown error"))
        break
      end

      xpcall(function()
        parse_items(result.contents.items)
      end, log.log_func(
        log.levels.error,
        { prefix = "Failed to parse: " }
      ))

      if not result.next_url or is_full() then
        break
      end

      query = { endpoint = result.next_url, param = {} }
      delay_with_warning(opts.settings.fetch_delay)
    end
  end

  return table_op.set_into_list(buffer)
end

return M
