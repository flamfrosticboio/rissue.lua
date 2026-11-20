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

---@diagnostic disable: redundant-parameter, invisible

---@param list any[]
---@param val any
---@return integer? index
local function list_find(list, val)
  for i, v in ipairs(list) do
    if v == val then
      return i
    end
  end
  return nil
end

---@param list any[]
---@param val any
---@return integer count
local function list_count(list, val)
  local count = 0
  for _, v in ipairs(list) do
    if v == val then
      count = count + 1
    end
  end

  return count
end

local function check_if_present(list, key)
  assert.is_not_nil(
    list_find(list, key),
    ("Cannot find %s in the command line arguments"):format(key)
  )
end

local function check_if_not_present(list, key)
  assert.is_nil(
    list_find(list, key),
    ("Found %s in the command line arguments where it shouldn't"):format(key)
  )
end

describe("curl", function()
  describe("construct", function()
    it("url ok", function()
      local url = "https://example.com"
      local res, err = curl.construct(url, {})

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      assert(list_find(res, url), "Cannot find url on the args list")
    end)

    it("-X method passed", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        method = "POST",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-X")
      check_if_present(res, "POST")
    end)

    it("-X method uppercases the words", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        method = "get",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-X")
      check_if_present(res, "GET")
    end)

    it("-X method default to GET", function()
      ---@type rissue.utils.curl.Opts
      local opts = {}

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-X")
      check_if_present(res, "GET")
    end)

    it("-H headers passed", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        headers = { "a", "b", "c" },
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      assert.equal(list_count(res, "-H"), 3, "-H count mismatch")
      check_if_present(res, "a")
      check_if_present(res, "b")
      check_if_present(res, "c")
    end)

    it("-A user_agent supported ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        user_agent = "hi",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-A")
      check_if_present(res, "hi")
    end)

    it("-u auth user pass ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { user = "hello", pass = "world" },
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-u")
      check_if_present(res, "hello:world")
    end)

    it("-H auth token ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = "mytokenbearer",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-H")
      check_if_present(res, "Authorization: Bearer mytokenbearer")
    end)

    it("--max-time timeout ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        timeout = 1.5, -- 1.5 seconds
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--max-time")
      check_if_present(res, "1.5")
    end)

    it("-L follow redirects ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        follow_redirects = true,
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "-L")
    end)

    it("--fail-with-body fail ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        fail_fast = true,
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--fail-with-body")
    end)

    it("--retry retry ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retries = 10,
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--retry")
      check_if_present(res, "10")
    end)

    it("--retry-delay retry_delay ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retry_delay = 10,
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--retry-delay")
      check_if_present(res, "10")
    end)

    it("--data data normal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "default",
        data = "hello",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data")
      check_if_present(res, "hello")
    end)

    it("--data-raw data literal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "literal",
        data = "hello",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data-raw")
      check_if_present(res, "hello")
    end)

    it("--data-binary data binary ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "binary",
        data = "hello",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data-binary")
      check_if_present(res, "hello")
    end)

    it("--data-urlencode fails successfully on type(data) is string", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "urlencode",
        data = "hello=true&world=true",
        method = "GET",
      }

      local res, err = curl.construct("example", opts)

      assert.same(
        "Cannot use option 'urlencode' on pure string. Pass a table instead",
        err
      )
      assert.is_nil(res, "result is not empty when error raised")
    end)

    it("--data-urlencode no -G on POST", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "POST",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
      check_if_not_present(res, "-G")
    end)

    it("--data-urlencode has -G on GET", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "GET",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
      check_if_present(res, "-G")
    end)

    it("--data-urlencode has -G on HEAD", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "HEAD",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(err, "construct returned an error: " .. tostring(err))
      assert(res, "construct returned no result and no error")

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
      check_if_present(res, "-G")
    end)

    it("--form form fail on type(data) is a string", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form",
        data = "hello",
      }

      local res, err = curl.construct("example", opts)

      assert.is_nil(res, "result is not empty when error raised")
      assert.same("Cannot use 'form' if the data is pure string", err)
    end)

    it("--form-string fails on type(data) is a string", function()
      local res, err = curl.construct("example", {
        data_type = "form_string",
        data = "hello",
      })

      assert.is_nil(res, "result is not empty when error raised")
      assert.same("Cannot use 'form_string' if the data is pure string", err)
    end)

    it("--form form normal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form",
        data = { name = true, write = false },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      assert.equal(2, list_count(res, "--form"))
      check_if_present(res, "name=true")
      check_if_present(res, "write=false")
    end)

    it("--form-string form_string ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form_string",
        data = { name = true, write = false },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      assert.equal(2, list_count(res, "--form-string"))
      check_if_present(res, "name=true")
      check_if_present(res, "write=false")
    end)

    it("--negotiate auth passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { pass = "", user = "", method = "negotiate" },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--negotiate")
      check_if_present(res, ":")
    end)

    it("--ntlm auth passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { pass = "", user = "", method = "ntlm" },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--ntlm")
      check_if_present(res, ":")
    end)

    it("--digest auth passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { pass = "", user = "", method = "digest" },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--digest")
      check_if_present(res, ":")
    end)

    it("--anyauth auth passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { pass = "", user = "", method = "anyauth" },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--anyauth")
      check_if_present(res, ":")
    end)

    it("-H accept header passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        accept = "application/json",
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "-H")
      check_if_present(res, "Accept: application/json")
    end)

    it("raw args added", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        raw_args = { "--my-raw-arg", "--my-other-raw-arg" },
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--my-raw-arg")
      check_if_present(res, "--my-other-raw-arg")
    end)

    it("-H content type header passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        content_type = "application/json",
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "-H")
      check_if_present(res, "Content-Type: application/json")
    end)

    it("--dump-header include_result_headers passed ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        include_result_headers = true,
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--dump-header")
      local idx = list_find(res, "--dump-header")
      local temp = res[idx + 1]
      assert.is_not_nil(temp, "Did not pass any temp name after --dump-header")
    end)

    it("--retry-all-errors retry_when is all ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retry_when = "all",
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--retry-all-errors")
    end)

    it("--retry-connrefused retry_when is connrefused ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retry_when = "connrefused",
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--retry-connrefused")
    end)

    it("retry_when = false disables retry flags", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retry_when = false,
      }

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_not_present(res, "--retry-all-errors")
      check_if_not_present(res, "--retry-connrefused")
    end)

    it("retry_when defaults to all", function()
      ---@type rissue.utils.curl.Opts
      local opts = {}

      local res, err = curl.construct("example", opts)

      assert(not err, err)
      assert(res, "error not defined when res is nil")

      check_if_present(res, "--retry-all-errors")
    end)

    it("fail on bad opts.data_type", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data = "",
        ---@diagnostic disable-next-line: assign-type-mismatch
        data_type = "water",
      }

      local res, err = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_nil(res, "result is not empty when error raised")
      assert.same(
        'Expecting any of [binary, default, form, form_string, literal, urlencode], got "water"',
        err
      )
    end)

    it("fail on bad opts.data", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        ---@diagnostic disable-next-line: assign-type-mismatch
        data = 2,
      }

      local res, err = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_nil(res, "result is not empty when error raised")
      assert.same("Expecting opts.data to be string or table, got number", err)
    end)

    it("fail on bad opts.data keys", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data = {
          [2] = "water",
        },
      }

      local res, err = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_nil(res, "result is not empty when error raised")
      assert.same(
        "Expecting all keys on data to be string, got 2 (number)",
        err
      )
    end)
  end)

  describe("request", function()
    it("Fail when construct fails", function()
      ---@diagnostic disable-next-line: missing-fields, await-in-sync
      local result, err = curl.request({} --[[@as rissue.Async]], "someurl", {
        ---@diagnostic disable-next-line: assign-type-mismatch
        data = 25,
      })

      assert.is_not_nil(err, "did not fail successfully")
      assert.is_nil(result, "Expected result to be nil when error is not nil")
      assert.same("Expecting opts.data to be string or table, got number", err)
    end)
  end)

  describe("post", function()
    it("set ok", function()
      local test = stub(curl, "request")

      local async_object = {}
      ---@diagnostic disable-next-line: await-in-sync
      curl.post(async_object, "hello", "my data", {})

      assert.stub(test).called_with(
        async_object,
        "hello",
        match.is_same({
          method = "POST",
          data = "my data",
        })
      )
    end)
  end)
end)
