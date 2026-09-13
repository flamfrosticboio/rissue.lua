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

local file = require("rissue.utils.file")
local log = require("rissue.utils.log")
local process = require("rissue.utils.process")
local table_op = require("rissue.utils.table_op")

local M = {}

---@alias rissue.utils.curl.Method  "GET" | "POST" | "PUT" | "DELETE" | "PATCH" | "HEAD" | "OPTIONS" | "TRACE" | "CONNECT" | string

---@alias rissue.utils.curl.Formats "application/json" | "text/html" | string

---@alias rissue.utils.curl.DataType "default" | "literal" | "binary" | "urlencode" | "form" | "form_string"

---@alias rissue.utils.curl.AuthMethod "ntlm" | "digest" | "negotiate" | "anyauth"

---@class __rissue.curl.DataTypeMap
---@field default string
---@field literal string
---@field binary string
---@field urlencode string
---@field form string
---@field form_string string

---@class rissue.utils.curl.Result
---@field exitcode integer
---@field content string
---@field err string
--- Available if --dump-header was passed
---@field headers? table<string, string>

---@class rissue.utils.curl.Opts
--- Default: GET
---@field method? rissue.utils.curl.Method
--- Headers to be passed to curl. Other headers are also handled without manually
--- constructing the headers yourself.
---@field headers? string[]
--- Default: none
---@field timeout? integer
--- Default: true
---@field follow_redirects? boolean
--- Default: 3
---@field retries? integer
--- Default: 1 (1 second)
---@field retry_delay? integer
--- Passes `--fail-with-body` (if supported) or `--fail` to the command line arguments.
---
--- Default: true
---@field fail_fast? boolean
--- Passes a user agent header to the command line arguments. Equivalent to:
--- `User-Agent: <agent-string>`
---@field user_agent? string?
---@field raw_args? string[]
---If passed as string, it will be used as a token directly. Otherwise, it will be pass
---to `curl -u` option
---@field auth? string | { user: string, pass: string, method: rissue.utils.curl.AuthMethod? }
---@field content_type? rissue.utils.curl.Formats
---@field accept? rissue.utils.curl.Formats
--- Enables form escape mode
---@field form_escape? boolean
--- If `data_type` == `special` then:
---   if `is_form` == true then it uses `--form-escape`
---@field data_type? rissue.utils.curl.DataType
--- Key-value pairs (default/raw/form) or raw payload (binary/JSON/etc.)
---
--- Form cannot be a string
---@field data? string | table<string, any>
---@field cwd? string
---@field env? string[]|table<string, string?>
--- Lists and parses the received headers from the server.
--- Provides `headers` in the `results`
---@field include_result_headers? boolean

---@type __rissue.curl.DataTypeMap
local _data_type_arg = {
  default = "--data",
  literal = "--data-raw",
  binary = "--data-binary",
  urlencode = "--data-urlencode",
  form = "--form",
  form_string = "--form-string",
}

-- Construct the command line arguments based on curl opts
---@param url string
---@param opts rissue.utils.curl.Opts
---@return string[] args
function M.construct(url, opts)
  --- Apply default options
  opts = opts or {}
  opts.method = (opts.method or "GET"):upper()
  opts.retries = opts.retries or 3
  opts.retry_delay = opts.retry_delay or 1
  opts.data_type = opts.data_type or "default"

  local args = {}

  args[#args + 1] = url
  args[#args + 1] = "-s"
  args[#args + 1] = "-X"
  args[#args + 1] = opts.method

  if opts.accept then
    args[#args + 1] = "-H"
    args[#args + 1] = "Accept: " .. opts.accept
  end

  if opts.content_type then
    args[#args + 1] = "-H"
    args[#args + 1] = "Content-Type: " .. opts.content_type
  end

  if opts.headers then
    for _, header in ipairs(opts.headers) do
      args[#args + 1] = "-H"
      args[#args + 1] = header
    end
  end

  if opts.user_agent then
    args[#args + 1] = "-A"
    args[#args + 1] = opts.user_agent
  end

  if opts.auth then
    if type(opts.auth) == "string" then
      args[#args + 1] = "-H"
      args[#args + 1] = "Authorization: Bearer " .. opts.auth
    elseif type(opts.auth) == "table" then
      args[#args + 1] = "-u"
      args[#args + 1] = opts.auth.user .. ":" .. opts.auth.pass
      if opts.auth.method then
        args[#args + 1] = "--" .. opts.auth.method
      end
    end
  end

  if opts.timeout then
    args[#args + 1] = "--max-time"
    args[#args + 1] = tostring(opts.timeout)
  end

  if opts.follow_redirects ~= false then
    args[#args + 1] = "-L"
  end

  if opts.fail_fast ~= false then
    args[#args + 1] = "--fail-with-body"
  end

  args[#args + 1] = "--retry"
  args[#args + 1] = tostring(opts.retries)
  args[#args + 1] = "--retry-delay"
  args[#args + 1] = tostring(opts.retry_delay)

  if opts.data then
    local d = opts.data
    local d_type = opts.data_type

    if opts.form_escape then
      args[#args + 1] = "--form-escape"
    end

    if
      opts.data_type == "urlencode" and (opts.method == "GET" or opts.method == "HEAD")
    then
      --- Make urlencode be placed on url when method=GET is used
      args[#args + 1] = "-G"
    end

    if type(d) == "table" then
      --- assuming its a table
      for k, v in pairs(d) do
        local line = k .. "=" .. tostring(v)
        local arg_key = _data_type_arg[d_type]
        args[#args + 1] = arg_key
        args[#args + 1] = line
      end
    else
      if opts.data_type == "form" then
        error("Cannot use 'form' if the data is pure string")
      elseif opts.data_type == "form_literal" then
        error("Cannot use 'form_literal' if the data is pure string")
      elseif opts.data_type == "urlencode" then
        error("Cannot use option 'urlencode' on pure string. Pass a table instead")
      end

      local arg_key = _data_type_arg[d_type]
      args[#args + 1] = arg_key
      args[#args + 1] = d
    end
  end

  if opts.include_result_headers then
    args[#args + 1] = "--dump-header"
    args[#args + 1] = os.tmpname()
  end

  if opts.raw_args then
    for _, arg in ipairs(opts.raw_args) do
      args[#args + 1] = arg
    end
  end

  return args
end

---@param raw string
local function parse_received_headers(raw)
  local res = {}
  for name, value in raw:gmatch("\n(%S-):[ \t]*([^\r\n]*)") do
    name = name:lower()
    if res[name] then
      res[name] = res[name] .. ", " .. value -- merge duplicates per RFC 9110
    else
      res[name] = value
    end
  end
  return res
end

--- Run curl with specified args.
---
--- Note: must be in coroutine mode
---@param args string[]
---@param cwd? string
---@param env? string[]|table<string,string?>
---@return rissue.utils.curl.Result? result
---@return string? error
function M.raw(args, cwd, env)
  local result, err = process.run_co({
    cmd = "curl",
    args = args,
    cwd = cwd,
    env = env,
  })

  -- might cause bugs
  if not result then
    return nil, err or "unhandled error"
  end

  local headers = nil
  if result.return_code == 0 then
    local _, idx = table_op.find(args, "--dump-header")
    if idx > 0 then
      local headers_file = args[idx + 1]

      if not headers_file then
        return nil, "[Bug]: Passed --dump-header without filename"
      end

      local output, read_file_err = file.read_file(headers_file) -- Warning: raises error
      if not output then
        return nil,
          read_file_err or "unhandled error during tempfile read with --dump-header"
      end

      local delete_ok, delete_err = file.delete_file(headers_file)
      if not delete_ok then
        -- just do nothing for a while since its not a critical bug
        log.warn(
          "Failed to delete tmpfile when --dump-header was used: "
            .. (delete_err or "unhandled error")
        )
      end

      headers = parse_received_headers(output)
    end
  end

  ---@type rissue.utils.curl.Result
  local res = {
    exitcode = result.return_code,
    content = result.stdout,
    err = result.stderr,
    headers = headers,
  }

  return res, nil
end

--- Runs curl in exclusive coroutine mode.
---@param url string
---@param opts rissue.utils.curl.Opts
---@return rissue.utils.curl.Result? result
---@return string? error
function M.request(url, opts)
  local args = M.construct(url, opts)
  return M.raw(args, opts.cwd, opts.env)
end

--- Helper that curls with POST
---@param url string
---@param data string | table<string, string?>
---@param opts rissue.utils.curl.Opts?
---@return rissue.utils.curl.Result? result
---@return string? error
function M.post(url, data, opts)
  opts = opts or {}
  opts.method = "POST"
  opts.data = data

  return M.request(url, opts)
end

return M
