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

local log = require("rissue.utils.log")
local strings = require("rissue.utils.strings")

describe("`trim()`", function()
  it("trims leading and trailing whitespace", function()
    assert.equal("hello", strings.trim("   hello   "))
  end)

  it("trims tabs and newlines", function()
    assert.equal("hello", strings.trim("\t\n hello \r\n\t"))
  end)

  it("keeps inner whitespace", function()
    assert.equal("hello   world", strings.trim("  hello   world  "))
  end)

  it("returns same string when nothing to trim", function()
    assert.equal("hello", strings.trim("hello"))
  end)

  it("returns empty string for empty input", function()
    assert.equal("", strings.trim(""))
  end)

  it("returns empty string for whitespace-only input", function()
    assert.equal("", strings.trim(" \t\r\n "))
  end)

  it("handles single character", function()
    assert.equal("a", strings.trim(" a "))
  end)
end)

describe("`trim_newlines()`", function()
  it("trims leading and trailing \\n", function()
    assert.equal("hello", strings.trim_newlines("\n\nhello\n\n"))
  end)

  it("trims leading and trailing \\r\\n", function()
    assert.equal("hello", strings.trim_newlines("\r\nhello\r\n"))
  end)

  it("does not trim spaces or tabs", function()
    assert.equal(" hello\t", strings.trim_newlines("\n hello\t\n"))
  end)

  it("keeps inner newlines", function()
    assert.equal("a\nb\r\nc", strings.trim_newlines("\na\nb\r\nc\n"))
  end)

  it("returns same string when nothing to trim", function()
    assert.equal("hello", strings.trim_newlines("hello"))
  end)

  it("returns empty string for empty input", function()
    assert.equal("", strings.trim_newlines(""))
  end)

  it("returns empty string for newline-only input", function()
    assert.equal("", strings.trim_newlines("\r\n\n\r"))
  end)
end)

describe("`truncate()`", function()
  it("returns string unchanged when shorter than max", function()
    assert.equal("hello", strings.truncate("hello", 10))
  end)

  it("returns string unchanged when equal to max", function()
    assert.equal("hello", strings.truncate("hello", 5))
  end)

  it("truncates ascii", function()
    assert.equal("hel", strings.truncate("hello", 3))
  end)

  it("returns empty string when max is 0", function()
    assert.equal("", strings.truncate("hello", 0))
  end)

  it("returns empty string for empty input", function()
    assert.equal("", strings.truncate("", 3))
  end)

  it("does not split a 2-byte character", function()
    -- "é" is 2 bytes; cutting at byte 2 would split it
    assert.equal("h", strings.truncate("héllo", 2))
  end)

  it("keeps a 2-byte character when it fits", function()
    assert.equal("hé", strings.truncate("héllo", 3))
  end)

  it("does not split a 4-byte character", function()
    -- "😀" is 4 bytes, occupying bytes 2-5
    assert.equal("a", strings.truncate("a😀b", 3))
    assert.equal("a", strings.truncate("a😀b", 4))
  end)

  it("keeps a 4-byte character when it fits", function()
    assert.equal("a😀", strings.truncate("a😀b", 5))
  end)

  it("returns empty string if first character does not fit", function()
    assert.equal("", strings.truncate("é", 1))
  end)

  ---@diagnostic disable-next-line: undefined-global
  local utf8 = utf8 ---@type table
  if type(utf8) == "table" and type(utf8.len) == "function" then
    it("result is always valid utf-8", function()
      local s = "añ😀日本語"
      for max = 0, #s do
        assert.is_true(utf8.len(strings.truncate(s, max)) ~= nil)
      end
    end)
  else
    log.warn(
      "utf8 library missing from runtime. Disabling tests requiring utf8..."
    )
  end
end)
