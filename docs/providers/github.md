# Providers - Github

Adds support for github.

<!-- @VERSION:github -->Version: 0.1<!-- @VERSION:github -->

## Supported

Github versions that the provider supports:

- api.github.com (2026-03-10)
- ghec (Github Enterprise Cloud) (2026-03-10)
- ghes 3.10-3.22 (Github Enterprise Server) (2026-03-10 and 2022-11-28)

Minimum active support for ghes: 3.16

Theoretical support for ghes: 3.0

> [!NOTE]
> **Support for ghes versions below 3.16**
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

## Types

<!-- &rissue.Github.Settings@docs -->

### `rissue.Github.Settings`

Note: use `rissue.Github.Opts` for a partial version of
`rissue.Github.Settings`

- api_version: `(rissue.Github.ApiVersion|false)?`
  -- Override the api version to be used.
  Most commonly used when doing requests like `get.issues()` or
  `get.merge_requests()`

  Setting it to false removes the api_version header to be sent to the server.

  _It is not recommended for the api_version to be set as a permanent setting,
  but rather a request option_

- endpoints: `rissue.Github.opts.Endpoints`
  -- Required field on param in each query: `q`.

  The query field supports template strings:
  - `{owner}` - Repository owner
  - `{repo}` - Repository name

  See the default settings for examples.

- fetch_delay: `integer`
  -- The delay between fetching in each endpoints/pages

- items_per_page: `integer`
  -- Defines how many items are fetched per page when performing pagination
  requests in github. Limit=100 (enforced by github)

- max_items: `integer`
  -- Limits how many items will be fetched and rendered.

  Note: This does not guarantee the output size of the result to be exactly
  `max_items` and may have more items than requested

- media_type: `rissue.Github.MediaType`
  -- The type of media to request from issues and pull requests.

  Attaches a header to the requests:

  ```text
  -H "Accept: application/vnd.github.<media_type>+json"
  ```

  Options:
  - "raw" -- Enables `body` in the api response
  - "text" -- Enables `body_text` in the api response
  - "html" -- Enables `body_html` in the api response
  - "full" -- Combination of `raw`, `text`, and `html`.

  _Note: It is not possible to access to `body_text` and `body_html` when
  `full` is selected. Enable the `store_raw` option instead and access it from
  raw response_

  See more on [github docs](https://docs.github.com/en/).
  - [Issues](https://docs.github.com/en/rest/issues/issues)
  - [Pull Requests](https://docs.github.com/en/rest/pulls/pulls)

- store_raw: `boolean`
  -- Store the raw response from the server in the results

<!-- &rissue.Github.Settings@docs -->

<!-- &rissue.Github.opts.Endpoints@docs -->

### `rissue.Github.opts.Endpoints`

- issues: `rissue.Query[]`
- merge_requests: `rissue.Query[]`

<!-- &rissue.Github.opts.Endpoints@docs -->

<!-- &rissue.Github.supports.AdditionalInfo@docs -->

### `rissue.Github.supports.AdditionalInfo`

- api_version: `(rissue.Github.ApiVersion)?`
- ghes: `string?` -- The Github Enterprise Version (3.x)
- ghes_code: `integer?` -- Typically represented as 3xxx (e.g. 3.14 -> 03014)

<!-- &rissue.Github.supports.AdditionalInfo@docs -->

#### From rissue

<!-- &rissue.Query@docs -->

### `rissue.Query`

- endpoint: `string`
  -- The endpoint url appended after the api endpoint from `rissue.ProviderInfo`
- param: `table<string, string>`
  -- The query parameters. Behavior differs between each provider.

<!-- &rissue.Query@docs -->

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
