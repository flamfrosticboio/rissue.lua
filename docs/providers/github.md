# Providers - Github

Adds support for github.

<!-- @VERSION:github -->Version: 1.0.0<!-- @VERSION:github -->

## Supported

Github versions that the provider supports:

- api.github.com (2026-03-10)
- ghec (Github Enterprise Cloud) (2026-03-10)
- ghes 3.10-3.22 (Github Enterprise Server) (2026-03-10 and 2022-11-28)

Minimum active support for ghes: 3.16

Theoretical support for ghes: 3.0

> [!NOTE]
>
> **Support for ghes versions below 3.16**
>
> There is has no active maintenance for versions lower than 3.16, but is
> ensured compatibility starting from 3.0.

## Settings

<!-- *github.conf -->

```lua
--- Default settings
---@type rissue.Github.Settings
M.default = {
  endpoints = {
    issues = {
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:issue is:open label:security,critical",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:issue is:open label:blocker,P0",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:issue is:open",
          sort = "interactions",
          order = "desc",
        },
      },
    },
    merge_requests = {
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:pr is:open label:security,critical",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:pr is:open label:blocker,P0",
          sort = "interactions",
          order = "desc",
        },
      },
      {
        endpoint = "/search/issues",
        param = {
          q = "repo:{owner}/{repo} is:pr is:open",
          sort = "interactions",
          order = "desc",
        },
      },
    },
  },
  max_items = 100,
  items_per_page = 100,
  media_type = "raw",
  store_raw = false,
  fetch_delay = 1000,
}
```

<!-- *github.conf -->

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
