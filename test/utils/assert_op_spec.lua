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

local assert_op = require("rissue.utils.assert_op")

--- Simple testable objects that can only be achieved in runtime

local test_thread = coroutine.create(
  ---@async
  function()
    coroutine.yield()
  end
)

local test_thread_2 = coroutine.create(
  ---@async
  function()
    coroutine.yield()
  end
)

local test_table = {}
local test_table_2 = {}

local test_func = function() end

local test_func_2 = function() end

local test_userdata = io.stdout
local test_userdata_2 = io.stdin

---@param base table
---@param entry table
---@param expected_fail_msg string?
local function assert_structure(base, entry, expected_fail_msg)
  local ok, err_msg = assert_op.table_expects(entry, base, "test_obj")
  local expected = expected_fail_msg == nil
  assert(
    ok == expected,
    ("Wrong result (expecting %s, got %s). %s"):format(
      tostring(expected),
      tostring(ok),
      err_msg or "[no err msg]"
    )
  )
  if expected == false then
    assert(
      err_msg == expected_fail_msg,
      ("Not correct fail message.\nExpected:\n\t%s\nGot:\n\t%s"):format(
        expected_fail_msg,
        err_msg
      )
    )
  end
end

describe("assert_op check_structure", function()
  it("match type when empty ok", function()
    assert_structure(
      { str = assert_op.matchers.is_string },
      {},
      "Expecting test_obj.str to be a string, got nil (type nil)"
    )
    assert_structure(
      { str = "10" },
      {},
      'Expecting test_obj.str to be "10", got nil'
    )

    assert_structure(
      { str = "10", num = 10 },
      { str = "10" },
      "Expecting test_obj.num to be 10, got nil"
    )
  end)

  describe("message format", function()
    it("enclosed in brackets when field key is not usable as string", function()
      --- allowed
      assert_structure(
        { ["my_name"] = true },
        {},
        "Expecting test_obj.my_name to be true, got nil"
      )

      assert_structure(
        { ["i1234"] = true },
        {},
        "Expecting test_obj.i1234 to be true, got nil"
      )

      assert_structure(
        { ["___wow"] = true },
        {},
        "Expecting test_obj.___wow to be true, got nil"
      )

      -- not allowed
      assert_structure(
        { ["1my_name"] = true },
        {},
        'Expecting test_obj["1my_name"] to be true, got nil'
      )

      assert_structure(
        { ["hello world"] = true },
        {},
        'Expecting test_obj["hello world"] to be true, got nil'
      )

      assert_structure(
        { ["ok24_@@@@"] = true },
        {},
        'Expecting test_obj["ok24_@@@@"] to be true, got nil'
      )
    end)

    it(
      "enclosed in brackets when field key is a string but a reserved word",
      function()
        for keyword in pairs(assert_op.DISALLOWED_KEYWORDS) do
          assert_structure(
            { [keyword] = true },
            {},
            ('Expecting test_obj["%s"] to be true, got nil'):format(keyword)
          )
        end
      end
    )

    it("enclosed in brackets when field key is not a string", function()
      assert_structure(
        { true, 10, "hello" },
        { true, 10 },
        'Expecting test_obj[3] to be "hello", got nil'
      )

      assert_structure(
        { assert_op.matchers.is_boolean },
        {},
        "Expecting test_obj[1] to be a boolean, got nil (type nil)"
      )

      assert_structure(
        { [test_thread] = true },
        {},
        string.format(
          "Expecting test_obj[%s] to be true, got nil",
          tostring(test_thread)
        )
      )

      assert_structure(
        { [test_func] = true },
        {},
        string.format(
          "Expecting test_obj[%s] to be true, got nil",
          tostring(test_func)
        )
      )

      assert_structure(
        { [test_table] = true },
        {},
        string.format(
          "Expecting test_obj[%s] to be true, got nil",
          tostring(test_table)
        )
      )

      assert_structure(
        { [test_userdata] = true },
        {},
        string.format(
          "Expecting test_obj[%s] to be true, got nil",
          tostring(test_userdata)
        )
      )

      assert_structure(
        { [false] = true },
        {},
        "Expecting test_obj[false] to be true, got nil"
      )
    end)
  end)

  describe("equality", function()
    local base = {
      contents = true,
      name = "water",
      id = 204,
      cb = test_func,
      opts = test_table,
      thread = test_thread,
      data = test_userdata,
    }

    it("all equal should ok", function()
      assert_structure(base, {
        contents = true,
        name = "water",
        id = 204,
        cb = test_func,
        opts = test_table,
        thread = test_thread,
        data = test_userdata,
      })
    end)

    it("ok on key but fail on wrong value", function()
      assert_structure(base, {
        contents = false,
        name = "water",
        id = 204,
        cb = test_func,
        opts = test_table,
        thread = test_thread,
        data = test_userdata,
      }, "Expecting test_obj.contents to be true, got false")

      assert_structure(base, {
        contents = true,
        name = "waterr",
        id = 204,
        cb = test_func,
        opts = test_table,
        thread = test_thread,
        data = test_userdata,
      }, 'Expecting test_obj.name to be "water", got "waterr"')

      assert_structure(base, {
        contents = true,
        name = 20,
        id = 204,
        cb = test_func,
        opts = test_table,
        thread = test_thread,
        data = test_userdata,
      }, 'Expecting test_obj.name to be "water", got 20')

      assert_structure(base, {
        contents = true,
        name = "water",
        id = -205,
        cb = test_func,
        opts = test_table,
        thread = test_thread,
        data = test_userdata,
      }, "Expecting test_obj.id to be 204, got -205")

      assert_structure(
        base,
        {
          contents = true,
          name = "water",
          id = 204,
          cb = test_func_2,
          opts = test_table,
          thread = test_thread,
          data = test_userdata,
        },
        ("Expecting test_obj.cb to be %s, got %s"):format(
          tostring(test_func),
          tostring(test_func_2)
        )
      )

      assert_structure(
        base,
        {
          contents = true,
          name = "water",
          id = 204,
          cb = test_func,
          opts = test_table_2,
          thread = test_thread,
          data = test_userdata,
        },
        ("Expecting test_obj.opts to be %s, got %s"):format(
          tostring(test_table),
          tostring(test_table_2)
        )
      )

      assert_structure(
        base,
        {
          contents = true,
          name = "water",
          id = 204,
          cb = test_func,
          opts = test_table,
          thread = test_thread_2,
          data = test_userdata,
        },
        ("Expecting test_obj.thread to be %s, got %s"):format(
          tostring(test_thread),
          tostring(test_thread_2)
        )
      )

      assert_structure(
        base,
        {
          contents = true,
          name = "water",
          id = 204,
          cb = test_func,
          opts = test_table,
          thread = test_thread,
          data = test_userdata_2,
        },
        ("Expecting test_obj.data to be %s, got %s"):format(
          tostring(test_userdata),
          tostring(test_userdata_2)
        )
      )
    end)
  end)

  describe("matcher", function()
    local base = {
      str = assert_op.matchers.is_string,
      num = assert_op.matchers.is_number,
      bool = assert_op.matchers.is_boolean,
      thread = assert_op.matchers.is_thread,
      tbl = assert_op.matchers.is_table,
      func = assert_op.matchers.is_function,
      userdata = assert_op.matchers.is_userdata,
    }

    it("match type is_string ok", function()
      assert_structure(base, {
        str = "water",
        num = 20,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = 2,
        num = 20,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      }, "Expecting test_obj.str to be a string, got 2 (type number)")
    end)

    it("match type is_number ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = "water",
        num = true,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      }, "Expecting test_obj.num to be a number, got true (type boolean)")
    end)

    it("match type is_boolean ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = "water",
        num = 10,
        bool = nil,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      }, "Expecting test_obj.bool to be a boolean, got nil (type nil)")
    end)

    it("match type is_thread ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = "10",
        num = 10,
        bool = true,
        thread = 2,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      }, "Expecting test_obj.thread to be a thread, got 2 (type number)")
    end)

    it("match type is_table ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = "wow",
        func = test_func,
        userdata = test_userdata,
      }, 'Expecting test_obj.tbl to be a table, got "wow" (type string)')
    end)

    it("match type is_function ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(base, {
        str = "20",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = "wow",
        userdata = test_userdata,
      }, 'Expecting test_obj.func to be a function, got "wow" (type string)')
    end)

    it("match type is_function ok", function()
      assert_structure(base, {
        str = "water",
        num = 10,
        bool = true,
        thread = test_thread,
        tbl = test_table,
        func = test_func,
        userdata = test_userdata,
      })

      assert_structure(
        base,
        {
          str = "water",
          num = 10,
          bool = true,
          thread = test_thread,
          tbl = test_table,
          func = test_func,
          userdata = false,
        },
        "Expecting test_obj.userdata to be a userdata, got false (type boolean)"
      )
    end)

    it("match type multiple ok", function()
      local base_multiple = {
        multiple = assert_op.matchers.multiple(
          assert_op.matchers.is_string,
          assert_op.matchers.is_table,
          assert_op.matchers.is_function,
          assert_op.matchers.is_nil,
          15
        ),
      }

      assert_structure(base_multiple, {
        multiple = "hello",
      })

      assert_structure(base_multiple, {
        multiple = {},
      })

      assert_structure(base_multiple, {
        multiple = test_func_2,
      })

      assert_structure(base_multiple, {
        str = "water",
      })

      assert_structure(base_multiple, {
        multiple = 15,
      })

      assert_structure(
        base_multiple,
        {
          multiple = 2,
        },
        "Expecting test_obj.multiple to be string|table|function|nil|`15`, got 2 (type number)"
      )
    end)

    it("match follows ok", function()
      local base2 = {
        follows = assert_op.matchers.follows({
          name = true,
          str = assert_op.matchers.is_string,
          others = assert_op.matchers.multiple(
            assert_op.matchers.is_number,
            assert_op.matchers.is_boolean
          ),
        }, "schema_follows"),
      }

      assert_structure(base2, {
        follows = {
          name = true,
          str = "hello",
          others = 10,
        },
      })

      assert_structure(base2, {
        follows = {
          name = false,
          str = "hello",
          others = 10,
        },
      }, "Expecting test_obj.follows.name to be true, got false")

      assert_structure(
        base2,
        {
          follows = {
            name = true,
            str = test_table,
            others = 10,
          },
        },
        string.format(
          "Expecting test_obj.follows.str to be a string, got %s (type table)",
          tostring(test_table)
        )
      )

      assert_structure(base2, {
        follows = {
          name = true,
          str = "hi",
          others = 2,
        },
      })

      assert_structure(base2, {
        follows = {
          name = true,
          str = "hi",
          others = true,
        },
      })

      assert_structure(
        base2,
        {
          follows = {
            name = true,
            str = "hi",
            others = "invalid",
          },
        },
        'Expecting test_obj.follows.others to be number|boolean, got "invalid" (type string)'
      )
    end)
  end)
end)
