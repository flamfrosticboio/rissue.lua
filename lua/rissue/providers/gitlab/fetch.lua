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

local curl_module = require("rissue.utils.curl")
local fmt = require("rissue.utils.fmt")
local json = require("rissue.utils.json")
local process = require("rissue.utils.process")
local strings = require("rissue.utils.strings")
local table_op = require("rissue.utils.table_op")

local shared = require("rissue.providers.gitlab.shared")

local log = shared.log

--- Formats {repo} into usable "info.owner .. "/" .. info.repo" supported by gitlab
---@param info rissue.ProviderInfo
---@param endpoint rissue.url
local function endpoint_to_full_url(info, endpoint)
  return string.format(
    "%s://%s/api/v4/%s", -- use api v4
    info.protocol,
    info.domain,
    fmt(endpoint, {
      repo = function()
        local path = (info.owner .. "/" .. info.repo):gsub("/", "%%2F")
        return path
      end,
    }) -- formats {repo}
  )
end

---@async
---@param async rissue.Async
---@param endpoint string
---@param opts rissue.curl.Opts
---@return string? err_msg
---@return string? result
---@return table<string, string>? headers
local function run_query(async, endpoint, opts)
  local result, err = curl_module.request(async, endpoint, opts)
  if not result then
    return err and shared.into_error_message(err) or "unknown error"
  end

  return nil, result.content, result.headers
end

--- Prepares the query for running by setting up defaults.
---
--- Returns a copy of base_query with edits
---@param base_query rissue.Query
---@param info rissue.ProviderInfo
---@param config rissue.Gitlab.Config
---@return rissue.Query
local function prepare_query(base_query, info, config)
  local param = {}
  table_op.shallow_key_merge_overwrite(param, base_query.param) -- copy other settings

  param.order_by = base_query.param.order_by or "created_at" -- default
  param.sort = base_query.param.sort or "desc" -- default
  param.per_page = tostring(math.min(config.max, 100))
  param.pagination = "keyset"

  ---@type rissue.Query
  return {
    endpoint = endpoint_to_full_url(info, base_query.endpoint),
    param = param,
  }
end

---@param headers string
---@return string?
local function get_next_page(headers)
  return headers:match('<([^>]+)>;%s*rel="next"')
end

---@param response string
---@return table[]? results if decoding was a success
---@return string? error
local function decode(response)
  local decoded, err = json.decode(response)
  if err or type(decoded) ~= "table" then
    local msg = "Failed to decode response: " .. (err or "unexpected response")
    log.trace(
      msg
        .. "\n"
        .. "Failing decode result: "
        .. (response ~= "" and response or "<empty response>")
    )
    return nil, msg
  end

  --- For cases where it returns 200, but returns a failing message,
  --- we check its decoded body is a kind of gitlab error
  local server_err = shared.try_represent_server_error(decoded)
  --- A success means this server_err has the basic error fields
  if server_err ~= nil then
    return nil, server_err
  end

  return decoded
end

---@param cb fun(item: table)
---@param status { count: integer }
---@param max integer
local function push_results(results, status, max, cb)
  for _, item in ipairs(results) do
    if status.count >= max then
      return
    end
    local ok, cb_err = pcall(cb, item)
    if not ok then
      log.warn("Callback failed:", cb_err)
    end
    status.count = status.count + 1
  end
end

---@async
---@param millis integer Delay in milliseconds
local function delay(async, millis)
  local delay_ok, delay_err = process.sleep(async, millis)
  if not delay_ok then
    log.warn("Failed to delay: " .. (delay_err or "unknown error"))
  end
end

---@class __rissue.Gitlab.FetchOpts
---@field queries rissue.Query
---@field cb fun(result: any)
---@field config rissue.Gitlab.Config
---@field info rissue.ProviderInfo
---@field token string?

---@async
---@param async rissue.Async
---@param opts __rissue.Gitlab.FetchOpts
---@return string? err_msgs
local function fetch(async, opts)
  local curl_headers = {}
  local error_messages = {} ---@type string[]
  local add_error_message = table_op.appender(error_messages)
  if opts.token then
    table.insert(curl_headers, "PRIVATE-TOKEN: " .. opts.token)
  end

  -- reusable curl opts
  local curl_opts = {
    headers = curl_headers,
    data_type = "urlencode",
    include_result_headers = true,
    retry_when = "connrefused",
  }

  for i, base_query in ipairs(opts.queries) do
    if i > 1 then
      delay(async, opts.config.delay)
    end

    local query = prepare_query(base_query, opts.info, opts.config)
    curl_opts.data = query.param

    local status = { count = 0 }

    while status.count < opts.config.max do
      local err, res, headers = run_query(async, query.endpoint, curl_opts)
      if not res then
        local msg = ('Failed to fetch "%s": %s'):format(query.endpoint, err)
        if #msg > 500 then
          log.debug(msg)
          msg = strings.truncate(msg, 500) .. "... (truncated, see debug log)"
        end
        --- we only need to log the errors and proceed to next base query.
        log.warn(msg)
        add_error_message(msg)
        break
      end

      local decoded, decode_err = decode(res)
      if not decoded then
        local msg = decode_err or "unknown error while decoding"
        log.warn(msg)
        add_error_message(msg)
        break
      end

      push_results(decoded, status, opts.config.max, opts.cb)

      local link = headers and headers.link
      local next_page = link and get_next_page(link)
      if not next_page then
        break
      end

      query.endpoint = next_page
      curl_opts.data = nil -- already encoded in the next-page URL
      delay(async, opts.config.delay)
    end
  end

  if #error_messages > 0 then
    return table.concat(error_messages, "\n")
  end
end

return fetch
