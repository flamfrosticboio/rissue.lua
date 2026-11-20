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

local file = require("rissue.utils.file")
local log = require("rissue.utils.log")
local process = require("rissue.utils.process")
local strings = require("rissue.utils.strings")
local table_op = require("rissue.utils.table_op")

---@class rissue.mod.Curl
local M = {}

---@class __rissue.curl.DataTypeMap
---@field default string
---@field literal string
---@field binary string
---@field urlencode string
---@field form string
---@field form_string string

---@type __rissue.curl.DataTypeMap
local _data_type_arg = {
  default = "--data",
  literal = "--data-raw",
  binary = "--data-binary",
  urlencode = "--data-urlencode",
  form = "--form",
  form_string = "--form-string",
}

local function valid_data_types()
  local keys = table_op.tbl_keys(_data_type_arg)
  table.sort(keys) -- stable order, so tests don't flake
  return table.concat(keys, ", ")
end

local type_arg_repr = valid_data_types()

--- Checks if the installed curl is compatible (7.83.0 <= curl < 9.0.0)
---
--- For this version, this rejects curl that are older than 7.83.0, and curl
--- with a major version greater than 8 (9.x.x and above), since those have
--- not been tested against the arguments used here.
---@async
---@param async rissue.Async
---@return string? err_msg Problems encountered while getting curl versions
---@return boolean compatible Only meaningful when err_msg is nil
---@return string version_string An empty string when it encounters an error
function M.is_version_compatible(async)
  local result, err =
    process.run_async(async, { cmd = "curl", args = { "--version" } })
  if not result then
    return "failed to run curl --version: " .. (err or "unknown error"),
      false,
      ""
  end

  if result.return_code ~= 0 then
    local parts = {} ---@type string[]
    for _, s in ipairs({ result.stderr, result.stdout }) do
      s = strings.trim(s)
      if s ~= "" then
        parts[#parts + 1] = s
      end
    end

    local detail = table.concat(parts, "\n")
    if detail == "" then
      detail = "no output"
    end

    local msg = string.format("curl (%d): %s", result.return_code, detail)
    return msg, false, ""
  end

  local maj, min, pat = result.stdout:match("^curl (%d+)%.(%d+)%.?(%d*)")
  local major, minor = tonumber(maj), tonumber(min)
  local patch = tonumber(pat) or 0
  if not (major and minor) then
    local snippet = strings.truncate(result.stdout, 40)
    return ("cannot parse curl version from: %q"):format(snippet), false, ""
  end

  local ver_string = string.format("%d.%d.%d", major, minor, patch)

  --- For curl, the major version does not affect any of the args we have yet. But maybe
  --- after 9.x.x, there would be some problems, so we would be limiting it by 8.x.x
  local compatible = major >= 7
    and major <= 8
    and not (major == 7 and minor < 83)

  return nil, compatible, ver_string
end

-- Construct the command line arguments based on curl opts.
---@param url string
---@param opts rissue.utils.curl.Opts
---@return string[]? args
---@return string? err_msg
function M.construct(url, opts)
  local args = {} ---@type string[]

  local method = (opts.method or "GET"):upper()

  args[#args + 1] = url
  args[#args + 1] = "-sS"
  args[#args + 1] = "-X"
  args[#args + 1] = method
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
  args[#args + 1] = tostring(opts.retries or 3)
  args[#args + 1] = "--retry-delay"
  args[#args + 1] = tostring(opts.retry_delay or 1)

  if opts.data then
    local d = opts.data
    local dt = type(d)
    ---@type rissue.curl.DataType
    local data_type = opts.data_type or "default"

    local arg_key = _data_type_arg[data_type] ---@type string?
    if not arg_key then
      return nil,
        string.format(
          "Expecting any of [%s], got %s",
          type_arg_repr,
          strings.represent_value(data_type)
        )
    end

    if opts.form_escape then
      args[#args + 1] = "--form-escape"
    end

    --- Make urlencode be placed on url when method=GET|HEAD is used
    --- since we cannot place it on the body
    if data_type == "urlencode" and (method == "GET" or method == "HEAD") then
      args[#args + 1] = "-G"
    end

    if dt == "table" then
      --- assuming its a table
      for k, v in pairs(d) do
        local kt = type(k)
        if kt ~= "string" then
          return nil,
            string.format(
              "Expecting all keys on data to be string, got %s (%s)",
              strings.represent_value(k),
              kt
            )
        end
        local line = k .. "=" .. tostring(v)
        args[#args + 1] = arg_key
        args[#args + 1] = line
      end
    elseif dt == "string" then
      if data_type == "form" then
        return nil, "Cannot use 'form' if the data is pure string"
      elseif data_type == "form_string" then
        return nil, "Cannot use 'form_string' if the data is pure string"
      elseif data_type == "urlencode" then
        return nil,
          "Cannot use option 'urlencode' on pure string. Pass a table instead"
      end

      args[#args + 1] = arg_key
      args[#args + 1] = d
    else
      return nil, "Expecting opts.data to be string or table, got " .. dt
    end
  end

  if opts.include_result_headers then
    args[#args + 1] = "--dump-header"
    args[#args + 1] = os.tmpname()
  end

  if opts.outfile then
    args[#args + 1] = "-o"
    args[#args + 1] = opts.outfile
    args[#args + 1] = "--create-dirs"
    args[#args + 1] = "--remove-on-error"
  end

  if opts.retry_when == "all" or opts.retry_when == nil then
    args[#args + 1] = "--retry-all-errors"
  elseif opts.retry_when == "connrefused" then
    args[#args + 1] = "--retry-connrefused"
  end

  if opts.raw_args then
    for _, arg in ipairs(opts.raw_args) do
      args[#args + 1] = arg
    end
  end

  return args
end

---@param raw string
---@return table<string, string>
local function parse_received_headers(raw)
  local res = {} ---@type table<string, string>
  ---@diagnostic disable-next-line: no-unknown Value is somehow not matched as string
  for raw_name, value in raw:gmatch("\n(%S-):[ \t]*([^\r\n]*)") do
    local name = raw_name:lower()
    if res[name] then
      res[name] = res[name] .. ", " .. value -- merge duplicates per RFC 9110
    else
      res[name] = value
    end
  end
  return res
end

--- Run curl with specified args.
---@async
---@param async rissue.Async
---@param args string[]
---@param cwd? string
---@param env? string[]|table<string,string?>
---@return rissue.utils.curl.Result? result
---@return string? error
function M.raw(async, args, cwd, env)
  local result, err = process.run_async(async, {
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
  local _, idx = table_op.find(args, "--dump-header")
  local headers_file = idx and idx > 0 and args[idx + 1] or nil

  if idx and idx > 0 and not headers_file then
    return nil, "[Bug]: Passed --dump-header without filename"
  end

  if headers_file then
    local succeeded = result.return_code == 0

    -- Only read the headers when curl succeeded
    local output ---@type string?
    local read_file_err ---@type string?
    if succeeded then
      output, read_file_err = file.read_file(headers_file) -- Warning: raises error
    end

    -- Always delete the tmpfile, even if curl failed
    local delete_ok, delete_err = file.delete_file(headers_file)
    if not delete_ok then
      -- just do nothing for a while since its not a critical bug
      log.warn(
        "Failed to delete tmpfile when --dump-header was used: "
          .. (delete_err or "unhandled error")
      )
    end

    if succeeded then
      if not output then
        return nil,
          read_file_err
            or "unhandled error during tempfile read with --dump-header"
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
---
--- Note: Requires curl >= 7.83.0. See `curl.is_version_compatible()` for more info.
---@async
---@param async rissue.Async
---@param url string
---@param opts rissue.utils.curl.Opts?
---@return rissue.utils.curl.Result? result
---@return string? error
function M.request(async, url, opts)
  opts = opts or {}
  local args, err_msg = M.construct(url, opts)
  if not args then
    return nil, err_msg or "unknown error"
  end
  return M.raw(async, args, opts.cwd, opts.env)
end

--- Helper that curls with POST
---@async
---@param async rissue.Async
---@param url string
---@param data string | table<string, string?>
---@param opts rissue.utils.curl.Opts?
---@return rissue.utils.curl.Result? result
---@return string? error
function M.post(async, url, data, opts)
  opts = opts or {}
  opts.method = "POST"
  opts.data = data

  return M.request(async, url, opts)
end

return M
