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

---@param name string
---@param major integer
---@param minor integer
---@param func fun()
local function mock_version(name, major, minor, func)
  describe(name, function()
    before_each(function()
      curl.__mock_version(major, minor)
    end)

    after_each(function()
      curl.__mock_version(nil, nil)
    end)

    func()
  end)
end

local _major, _minor = curl.get_version()

mock_version("curl", _major, _minor, function()
  mock_version("version", 10, 10, function()
    it("get_version() is correct", function()
      local M, m = curl.get_version()
      assert.equal(10, M)
      assert.equal(10, m)
    end)

    it("version_atleast() is correct", function()
      assert(false == curl.version_atleast(11, 9), "1 failed")
      assert(false == curl.version_atleast(10, 11), "2 failed")
      assert(true == curl.version_atleast(9, 10), "3 failed")
      assert(true == curl.version_atleast(10, 9), "4 failed")
      assert(false == curl.version_atleast(11, 1), "4 failed")
    end)
  end)

  describe("construct", function()
    it("url ok", function()
      local url = "https://example.com"
      local res = curl.construct(url, {})
      assert(list_find(res, url), "Cannot find url on the args list")
    end)

    it("-X method passed", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        method = "POST",
      }

      local res = curl.construct("example", opts)
      assert.is_not_nil(
        list_find(res, "-X"),
        "Cannot find method argkey on the args list"
      )
      assert.is_not_nil(list_find(res, "POST"), "Cannot find url on the args list")
    end)

    it("-H headers passed", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        headers = { "a", "b", "c" },
      }

      local res = curl.construct("example", opts)

      assert.equal(list_count(res, "-H"), 3, "-H count mismatch")
      assert.is_not_nil(list_find(res, "a"), "Cannot find specified")
      assert.is_not_nil(list_find(res, "b"), "Cannot find specified")
      assert.is_not_nil(list_find(res, "c"), "Cannot find specified")
    end)

    mock_version("-A user_agent supported", 7, 1, function()
      it("ok", function()
        ---@type rissue.utils.curl.Opts
        local opts = {
          user_agent = "hi",
        }

        local res = curl.construct("example", opts)

        assert.is_not_nil(list_find(res, "-A"), "Cannot find user agent argkey")
        assert.is_not_nil(list_find(res, "hi"), "Cannot find user agent")
      end)
    end)

    mock_version("-A user_agent unsupported", 7, 0, function()
      it("ok", function()
        ---@type rissue.utils.curl.Opts
        local opts = {
          user_agent = "hi",
        }

        local res = curl.construct("example", opts)
        -- print(require("inspect")(res))

        assert.is_not_nil(list_find(res, "-H"), "Cannot find user agent argkey")
        assert.is_not_nil(list_find(res, "User-Agent: hi"), "Cannot find user agent")
      end)
    end)

    it("-u auth user pass ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = { user = "hello", pass = "world" },
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "-u"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "hello:world"), "Cannot find arg value")
    end)

    it("-H auth token ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        auth = "mytokenbearer",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "-H"), "Cannot find argkey")
      assert.is_not_nil(
        list_find(res, "Authorization: Bearer mytokenbearer"),
        "Cannot find arg value"
      )
    end)

    it("--max-time timeout ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        timeout = 1.5, -- 1.5 seconds
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--max-time"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "1.5"), "Cannot find arg value")
    end)

    it("-L follow redirects ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        follow_redirects = true,
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "-L"), "Cannot find argkey")
    end)

    mock_version("--fail fail unsupported", 7, 75, function()
      it("ok", function()
        ---@type rissue.utils.curl.Opts
        local opts = {
          fail_fast = true,
        }

        local res = curl.construct("example", opts)
        -- print(require("inspect")(res))

        assert.is_not_nil(list_find(res, "--fail"), "Cannot find argkey")
      end)
    end)

    mock_version("--fail fail supported", 7, 76, function()
      it("ok", function()
        ---@type rissue.utils.curl.Opts
        local opts = {
          fail_fast = true,
        }

        local res = curl.construct("example", opts)
        -- print(require("inspect")(res))

        assert.is_not_nil(list_find(res, "--fail-with-body"), "Cannot find argkey")
      end)
    end)

    it("--retry retry ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retries = 10,
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--retry"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "10"), "Cannot find arg value")
    end)

    it("--retry retry ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        retry_delay = 10,
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--retry-delay"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "10"), "Cannot find arg value")
    end)

    it("--data data normal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "default",
        data = "hello",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--data"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "hello"), "Cannot find arg value")
    end)

    it("--data-raw data literal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "literal",
        data = "hello",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--data-raw"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "hello"), "Cannot find arg value")
    end)

    it("--data-binary data binary ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "binary",
        data = "hello",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--data-binary"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "hello"), "Cannot find arg value")
    end)

    it("--data-urlencode fails successfully on type(data) is string", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "urlencode",
        data = "hello=true&world=true",
        method = "GET",
      }

      local res = pcall(curl.construct, "example", opts)
      assert.is_false(res, "Did not successfully fail")
    end)

    it("--data-urlencode no -G on POST", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "POST",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
    end)

    it("--data-urlencode has -G on GET", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "GET",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
    end)

    it("--data-urlencode data urlencode ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "GET",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "-G")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
    end)

    it("--data-urlencode has -G on HEAD", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        is_form = false,
        data_type = "urlencode",
        data = { name = "john", write = "false" },
        method = "HEAD",
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      check_if_present(res, "--data-urlencode")
      check_if_present(res, "name=john")
      check_if_present(res, "write=false")
    end)

    it("--form form fail on type(data) is a string", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form",
        data = "hello",
      }

      assert.equal(
        false,
        pcall(function()
          local _ = curl.construct("example", opts)
        end, "Did not fail successfully")
      )
      -- print(require("inspect")(res))
    end)

    it("--form form normal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form",
        data = { name = true },
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--form"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "name=true"), "Cannot find arg value")
    end)

    it("--form form literal ok", function()
      ---@type rissue.utils.curl.Opts
      local opts = {
        data_type = "form_literal",
        data = { name = true },
      }

      local res = curl.construct("example", opts)
      -- print(require("inspect")(res))

      assert.is_not_nil(list_find(res, "--form-string"), "Cannot find argkey")
      assert.is_not_nil(list_find(res, "name=true"), "Cannot find arg value")
    end)
  end)

  describe("post", function()
    it("set ok", function()
      local test = stub(curl, "request")

      curl.post("hello", "my data", {})

      assert.stub(test).called_with(
        "hello",
        match.is_same({
          method = "POST",
          data = "my data",
        })
      )
    end)
  end)

  describe("raw", function()
    it("fail on non-coroutine", function()
      assert.equal(
        false,
        pcall(function()
          curl.raw({})
        end),
        "did not fail successfully"
      )
    end)
  end)
end)
