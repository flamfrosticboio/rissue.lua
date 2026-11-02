# Rissue

## Main

<!-- &rissue@docs -->

### `rissue`

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

- <details>
  <summary><code>get_issues</code>: <code>function(remote: string|rissue.ProviderInfo|rissue.RemoteInfo, opts: (table|table&lt;string, table?&gt;)?): rissue.Issue[]?, string?</code> – Gets issues from the url, remote info or provider info</summary>

  If the provided remote is a `string` (url) or `rissue.RemoteInfo`, then the
  `opts` arg requires specifying the provider name inside a table.

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

  </details>

- <details>
  <summary><code>get_merge_requests</code>: <code>function(remote: string|rissue.ProviderInfo|rissue.RemoteInfo, opts: (table|table&lt;string, table?&gt;)?): rissue.MergeRequest[]?, string?</code> – Gets merge requests from the remote url, remote info or provider info</summary>

  If the provided remote is a `string` (url) or `rissue.RemoteInfo`, then the
  `opts` arg requires specifying the provider name inside a table.

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

  </details>

- <details>
  <summary><code>get_provider_info</code>: <code>function(remote: rissue.RemoteInfo, opts: table&lt;string, table?&gt;?): (rissue.ProviderInfo)?, string?</code> – Gets the provider info from remote info or remote url.</summary>

  Example:

  ```lua
  --- # With url
  rissue.get_provider_info("https://github.com/flamfrosticboio/rissue.git")
  -- should return a github related provider info

  --- # With already parsed or manual constructed `rissue.RemoteInfo`
  local remote_info =
    rissue.get_remote_info("https://github.com/flamfrosticboio/rissue.git")
  rissue.get_provider_info(remote_info)
  ```

  </details>

- `get_remote_info`: `function`
- <details>
  <summary><code>setup</code>: <code>function(opts: (rissue.Opts)?, cwd: string?): string?</code> – Run setup for rissue.</summary>

  Example:

  ```lua
  rissue.setup({
     timeout = 20000 -- 20 seconds
  }, "/home/user/projects/my_project")
  -- Will read the .env file from that path
  ```

  </details>

<!-- &rissue@docs -->

## Config

Default config for rissue (see more on [setup.md](setup)):
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
      patterns = { "github%.com" },
      additional_info = {
        api_version = "2026-03-10",
      } --[[@as rissue.Github.supports.AdditionalInfo]],
    },
  },
  timeout = 60000,
  log = {},
}
```

<!-- *rissue.config.settings -->
