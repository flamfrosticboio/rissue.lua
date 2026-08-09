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

local provider = require("rissue.provider")

---@type uv
local uv = require("luv")

require("rissue").setup()

describe("provider", function ()
    it("github self-hosted", function ()
        async()
        local ok, info = provider.get_provider_info(
            "git:github.mycompany.com:owner/repo.git"
        )
        assert(ok == true, (info --[[@as string]]))

        assert.is_false(uv.run())
    end)
end)
