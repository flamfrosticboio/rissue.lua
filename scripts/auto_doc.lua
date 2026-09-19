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

local uv = require("luv") ---@type uv

--- Auto documenting providers

--- Opens files safely
---@param file string
---@return string
local function read_file(file)
  local fd, err = uv.fs_open(file, "r", 438)
  if not fd then
    error(err, 2)
  end

  local ok, result = pcall(function()
    local stat, stat_err = uv.fs_fstat(fd)
    if not stat then
      error(stat_err, 0)
    end
    local data, read_err = uv.fs_read(fd, stat.size, 0)
    if not data then
      error(read_err, 0)
    end
    return data
  end)

  uv.fs_close(fd)

  if not ok then
    error(result, 0)
  end

  return result
end

---@param file string
---@param contents string
local function write_file(file, contents)
  local fd, err = uv.fs_open(file, "w", 438)
  if not fd then
    error(err, 2)
  end

  local ok, result = pcall(function()
    local _, write_err = uv.fs_write(fd, contents, 0)
    if write_err then
      error(write_err)
    end
  end)

  uv.fs_close(fd)

  if not ok then
    error(result, 0)
  end

  return result
end

---@param content string
---@return table<string, string> mapped_blocks
local function extract_blocks(content)
  local blocks = {}

  for name in content:gmatch("%-%-%-%s*&(%S-)\n") do
    assert(type(name) == "string", "Name is not a string")
    local start_pat = "%-%-%-%s*&" .. name .. "\n"
    local end_pat = "%-%-%-%s*/" .. name .. "\n"
    local pat = start_pat .. "(.-)" .. end_pat

    ---@type string?
    local body = content:match(pat)
    if body then
      blocks[name] = body:match("^%s*(.-)%s*$")
    end
  end

  return blocks
end

---@param filepath string
local function strip_lua_file_extension(filepath)
  return filepath:gsub("%.lua$", "")
end

---@param content string
---@param blocks table<string, string>
local function apply_blocks(content, blocks)
  for name, body in pairs(blocks) do
    local start_pat = "<!%-%-%s*&" .. name .. "%s*%-%->"
    local end_pat = "<!%-%-%s*/" .. name .. "%s*%-%->"
    local pat = start_pat .. "(.-)" .. end_pat
    local replacement = "<!-- &"
      .. name
      .. " -->\n```lua\n"
      .. body
      .. "\n```\n<!-- /"
      .. name
      .. " -->"
    content = content:gsub(pat, replacement)
  end

  return content
end

local is_windows = package.config:sub(1, 1) == "\\"
local function shell_quote(s)
  if is_windows then
    return '"' .. s:gsub('"', '\\"') .. '"'
  end
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

---@param path string
local function run_formatter(path)
  os.execute("npx prettier --config .prettierrc --write " .. shell_quote(path))
end

local providers_dir = "src/rissue/providers"
local fd, err = uv.fs_scandir(providers_dir)
if not fd then
  error(err)
end
while true do
  local name, ftype = uv.fs_scandir_next(fd)
  if not name then
    break
  end

  local doc_file_path = "docs/providers/"
    .. strip_lua_file_extension(name)
    .. ".md"
  local impl_file_path = providers_dir .. "/" .. name
  local doc_contents = read_file(doc_file_path)
  if ftype == "directory" then
    local ifd, ifd_err = uv.fs_scandir(impl_file_path)
    if not ifd then
      error(ifd_err)
    end
    while true do
      local impl_fname, impl_ftype = uv.fs_scandir_next(ifd)
      if not impl_fname then
        break
      end

      local impl_fpath = impl_file_path .. "/" .. impl_fname

      if impl_ftype == "file" then
        local impl_contents = read_file(impl_fpath)
        local blocks = extract_blocks(impl_contents)
        doc_contents = apply_blocks(doc_contents, blocks)
      else
        print("Warning: Nested directory scanning is not yet supported")
      end
    end
    write_file(doc_file_path, doc_contents)
    run_formatter(doc_file_path)
  elseif ftype == "file" then
    local impl_file = read_file(impl_file_path)
    local blocks = extract_blocks(impl_file)
    local new_content = apply_blocks(doc_contents, blocks)

    write_file(doc_file_path, new_content)
    run_formatter(doc_file_path)
  else
    error("Invalid filetype: " .. ftype)
  end

  print(
    "\nIf running on precommit/prek and any files were written, run "
      .. "'git add --update .'"
  )
end
