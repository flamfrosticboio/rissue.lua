# Providers - Github

Adds support for github.

<!-- VERSION -->Version: 0.1<!-- /VERSION -->

## Supported

Github versions that the provider supports:

- api.github.com (2026-03-10)
- ghec (Github Enterprise Cloud) (2026-03-10)
- ghes 3.10-3.22 (Github Enterprise Server) (2026-03-10 and 2022-11-28)

Minimum active support for ghes: 3.10

Theoretical support for ghes: 3.0

> [!NOTE] Support for ghes versions lower than the minimum active support
> There is has no active maintenance for versions lower than the active support,
> but is sometimes compatible from the theoretical support. For compatibility, versions
> starting at ghes 3.0 will be tested.

## Settings

<!-- !SETTINGS -->
```lua
---@type rissue.Github.Settings
local default_settings = {
  endpoints = {
    issues = {
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open label:security,critical",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open label:blocker,P0",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} type:issue is:open",
          sort = "interactions",
          order = "desc",
        },
      },
    },
    merge_requests = {},
  },
}
```
<!-- /!SETTINGS -->

## Types

<!-- !TYPES -->
```lua
---@alias rissue.Github.SupportedApiVersions "2026-03-10" | "2022-11-28"

--- Additional options when checking provider support
---@class rissue.Github.supports.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

--- Additional options when checking provider support
---@class rissue.Github.get_merge_requests.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

--- Additional options when checking provider support
---@class rissue.Github.get_issues.Opts
---@field api_version rissue.Github.SupportedApiVersions | false

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.SupportedApiVersions?

---@class rissue.Github.opts.Endpoints
---@field issues rissue.Query[]
---@field merge_requests rissue.Query[]

---@class rissue.Github.Settings
--- Required field on param in each query: `q`
--- `q` can be used as template string.
---
--- Supported template strings for `q`:
--- - `{owner}` - Repository owner
--- - `{repo}` - Repository name
---
--- See default settings for examples.
---@field endpoints rissue.Github.opts.Endpoints
--- Override the api version to be used.
--- Most commonly used when doing requests like `get.issues()` or `get.merge_requests()`
---
--- **Warning: NOT RECOMMENDED TO BE SET ON USER SETTINGS**
---@field api_version rissue.Github.SupportedApiVersions?
```
<!-- /!TYPES -->

## Technical

- On supported versions of ghes, the highest api version will be used.

Implementation:
<!-- !TECHNICAL:GITHUB_GHES_RANGE -->
```lua
--- Api version will be chosen by the table below
--- uses (abbb scheme) (a = major; b = minor)

local ghes_latest = 03022
---@type {[1]: integer, [2]: integer, [3]: string}[]
local ghes_api_versions_range = {
  { 03009, 03020, "2022-11-28" }, -- ghes 3.9-3.20
  { 03021, ghes_latest, "2026-03-10" }, -- ghes 3.21+
}
```
<!-- /!TECHNICAL:GITHUB_GHES_RANGE -->
