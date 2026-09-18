# Providers - Github

Adds support for github.

<!-- VERSION -->Version: 0.1<!-- /VERSION -->

## Supported

Github versions that the provider supports:

- api.github.com (2026-03-10)
- ghec (Github Enterprise Cloud) (2026-03-10)
- ghes 3.10-3.22 (Github Enterprise Server) (2026-03-10 and 2022-11-28)

Minimum active support for ghes: 3.16

Theoretical support for ghes: 3.0

> [!NOTE]
> **Support for ghes versions below 3.16**
> There is has no active maintenance for versions lower than 3.16, but is ensured
> compatibility starting from 3.0.

## Settings

<!-- &SETTINGS -->

```lua
--- Default settings
---@type rissue.Github.Settings
M.default = {
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
  max_items = 100,
  items_per_page = 100,
  media_type = "raw",
  store_raw = false,
  fetch_delay = 1000,
}
```

<!-- /SETTINGS -->

## Types

<!-- &TYPES -->

````lua
---@alias rissue.Github.ApiVersion "2026-03-10" | "2022-11-28"

---@alias rissue.Github.MediaType
---| "raw" # Enables `body` in the response
---| "text" # Enables `body_text` in the response
---| "html" # Enables `body_html` in the response

---@class rissue.Github.supports.AdditionalInfo
---@field ghes string? The Github Enterprise Version (3.x)
---@field ghes_code integer? Typically represented as 3xxx (e.g. 3.14 -> 03014)
---@field api_version rissue.Github.ApiVersion?

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
--- Setting it to false removes the api_version header to be sent to the server.
---
--- **Warning: NOT RECOMMENDED TO BE SET ON USER SETTINGS**
---@field api_version? rissue.Github.ApiVersion | false
--- Limits how many items will be fetched and rendered.
--- Note: This does not guarantee the output size of the result to be exactly `max_items`
---       and may have more items than requested
---@field max_items integer
--- Defines how many items are fetched per page when performing pagination requests in github. Limit=100
---@field items_per_page integer
--- The type of media to request from issues and pull requests.
---
--- What would be sent to the server:
--- ```lua
--- --- Curl headers
--- headers[#headers + 1] = ("Accept: application/vnd.github.s+json"):format(media_type)
--- --- Results to: "Accept: application/vnd.github.raw+json" if media_type is `json`
--- ```
---@field media_type rissue.Github.MediaType
--- Store the raw response from the server to the original parsed response
---@field store_raw boolean
--- The delay between fetching
---@field fetch_delay integer

--- Partial version of rissue.Github.Settings
---@class (partial) rissue.Github.Opts: rissue.Github.Settings
````

<!-- /TYPES -->

## Technical

- On supported versions of ghes, the highest api version will be used.

Implementation:
<!-- &TECHNICAL:GITHUB_GHES_RANGE -->

```lua
M.ghes_latest_version_code = 03022

--- Api version will be chosen by the table below
--- uses (abbb scheme) (a = major; b = minor)
---@type {[1]: integer, [2]: integer, [3]: string}[]
M.ghes_api_version_range = {
  { 03009, 03020, "2022-11-28" }, -- ghes 3.9-3.20
  { 03021, M.ghes_latest_version_code, "2026-03-10" }, -- ghes 3.21+
}
```

<!-- /TECHNICAL:GITHUB_GHES_RANGE -->
