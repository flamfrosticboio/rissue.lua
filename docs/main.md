# Rissue

<!-- &rissue@description -->

A plugin that gets issues and merge requests from git provider.

Example usage:

```lua
local rissue = require('rissue')
rissue.setup({
    -- your preferred configuration
})
rissue.get_issues("https://github.com/flamfrosticboio/rissue")
rissue.get_merge_requests("https://github.com/flamfrosticboio/rissue")
```

<!-- &rissue@description -->

## Table of Contents

- [Config](main#Config)
- [Usage](main#Usage)
- [Types](main#Types)

## Config

Default config for rissue (see more on [setup.md](doc#setup)):
<!-- *rissue.config.settings -->

```lua
--- Settings (configured with `rissue.setup()`)
---@type rissue.Config
config.options = {
  additional_providers = {},
  env_file = ".env",
  env = {
    provider_prefix = "GIT_TK_",
  },
  provider_options = {},
  endpoint_shortcuts = {
    github = {
      domain = "api.github.com",
      patterns = { "github.com" },
      additional_info = {
        api_version = "2026-03-10",
      } --[[@as rissue.Github.supports.AdditionalInfo]],
    },
  },
  timeout = 60000,
}
```

<!-- *rissue.config.settings -->

## Usage

<!-- &rissue.get_issues()@docs -->

### rissue.get_issues()

Gets issues from the url, remote info or provider info

If the provided remote is a `string` (url) or `rissue.RemoteInfo`,
then the `opts` arg requires specifying the provider name inside a table.

Example:

```lua
--- Passing opts as `string` or `rissue.RemoteInfo`
rissue.get_issues("https://github.com/flamfrosticboio/rissue.git", {
  github = { max_items = 50 },
  gitlab = { max_items = 500 },
  --- gitea and forgejo may use default/user settings
})

--- Passing opts as `rissue.ProviderInfo`
local info, err =
  rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
assert(info, err)
assert(info.name == "github", "Not a github provider")
--- Now we know that info is specifically github
rissue.get_issues(info, { max_items = 50 })
```

**Parameters:**

- `remote`: `string|rissue.ProviderInfo<any>|rissue.RemoteInfo` -- See description
- `opts`: `(table|table<string, table?>)?` -- See description

**Returns:**

- (1) `rissue.issue[]?` -- List of issues. `nil` when it fails.
- (2) `string?` -- Error message if operation fails.

<!-- &rissue.get_issues()@docs -->

<!-- &rissue.get_merge_requests()@docs -->

### rissue.get_merge_requests()

Gets merge requests from the remote url, remote info or provider info

If the provided remote is a `string` (url) or `rissue.RemoteInfo`,
then the `opts` arg requires specifying the provider name inside a table.

Example:

```lua
--- Passing opts as `string` or `rissue.RemoteInfo`
rissue.get_merge_requests("https://github.com/flamfrosticboio/rissue.git", {
  github = { max_items = 50 },
  gitlab = { max_items = 500 },
  --- gitea and forgejo may use default/user settings
})

--- Passing opts as `rissue.ProviderInfo`
local info, err =
  rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
assert(info, err)
assert(info.name == "github", "Not a github provider")
--- Now we know that info is specifically github
rissue.get_merge_requests(info, { max_items = 50 })
```

**Parameters:**

- `remote`: `string|rissue.ProviderInfo<any>|rissue.RemoteInfo` -- See description
- `opts`: `(table|table<string, table?>)?` -- See description

**Returns:**

- (1) `rissue.pr[]?` -- List of merge requests. `nil` when it fails.
- (2) `string?` -- Error message if operation fails.

<!-- &rissue.get_merge_requests()@docs -->

## Types

<!-- &rissue.issue@docs -->

### `rissue.issue`

The structure for issues.

- author: `rissue.user`
- body: `string?`
- created_at: `integer`
- id: `integer` -- The id of the issue
- is_open: `boolean`
- labels: `rissue.label[]`
- raw: `table?`
  -- Raw response from server (if supported and enabled).
  See your current git provider's settings on this option.
- title: `string`
- url: `string`
- web_url: `string` -- A web version to the url

<!-- &rissue.issue@docs -->

<!-- &rissue.pr@docs -->

### `rissue.pr`

The structure for pull/merge request

- author: `rissue.user`
- body: `string?`
- created_at: `integer`
- id: `integer` -- The id of the issue
- labels: `rissue.label[]`
- raw: `table?`
  -- Raw response from server (if supported and enabled).
  See your current git provider's settings on this option.
- state: `"canceled"|"merged"|"open"` -- The state of the pull request
- title: `string`
- url: `string`
- web_url: `string` -- A web version to the url

<!-- &rissue.pr@docs -->

<!-- &rissue.ProviderInfo@docs -->

### `rissue.ProviderInfo`

The full provider information that will be used for `rissue.get_issues()`
and `rissue.get_merge_requests()`.

Depending on the provider, the provider may perform curl requests to the
servers to confirm and write their additional information required for that
repository.

- additional_info: `<T>?`
  -- Additional provider information used for specific provider (e.g. github ghes)
- domain: `string` -- The api endpoint
- name: `string` -- The name of the provider
- owner: `string` -- The owner of the repository
- protocol: `"http"|"https"` -- The curl protocol
- repo: `string` -- The repository name

<!-- &rissue.ProviderInfo@docs -->

<!-- &rissue.RemoteInfo@docs -->

### `rissue.RemoteInfo`

The remote information extracted from a url.

- curl_protocol: `"http"|"https"` -- Protocol
- domain: `string` -- The api domain of the provider
- full_url: `string` -- The clean url
- owner: `string` -- The owner of the repository
- repo: `string` -- The repository name

<!-- &rissue.RemoteInfo@docs -->

---

Note: This documentation is automated
