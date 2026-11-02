# Providers

> [!NOTE] Written on 30/10/2026. New versions may differ. If so, report this as
> an documentation update in the issues tab.

## Writing a provider

### Structure

A provider should return the following structure from `rissue.Provider`. See
[its types](provider#`rissue.Provider`) for more details about each field.

Example:

```lua
---@type rissue.Provider
return {
  name = "github",
  version = { major = 1, minor = 0, patch = 0 },
  supports = supports.main,
  get_merge_requests = get_merge_requests,
  get_issues = get_issues,
  settings = config.default,
}
```

### Using on Development

To use your newly created provider, use `rissue.setup()` with
`additional_providers` config pointing to your provider's filepath.

```lua
rissue.setup({
  additional_providers = {
    "path/to/your/provider.lua"
  }
})
--- name from your structure (e.g. github)
assert(require('rissue.config').providers["your_provider_name"] ~= nil)
```

Example:

```lua
rissue.setup({
  additional_providers = {
    project_dir .. "github.lua" -- has { name = 'github', ... } inside
  }
})
--- name from your structure (e.g. github)
assert(require('rissue.config').providers["github"] ~= nil)
```

### Making Supports

The `rissue.provider.Supports` field is called when the provider cannot
determine the provider from the associated shortcuts.

You are allowed to query on the server based on the `rissue.RemoteInfo`
provided, but make this as the last case scenario when its impossible to
determine by remote info's url alone.

Use helper functions such as `require("rissue.utils.curl")` to make checking the
remote info easier.

Additionally, `rissue.provider.Supports` gives you an auth token `token` and
settings, so there is no need for you to check the token and update settings
each time.

When returning, pass `boolean` when it is supported. Additionally, you can
return additional information about the remote information as second argument.

Example implementation:

```lua
local curl = require('rissue.utils.curl')

---@type rissue.provider.Supports<any, any>
local function supports(async, info, token, opts)
    --- short circuit when info url contains "github.com"
    if info.domain:find("github%.com") then
        return true
    end


    local url = info.curl_protocol .. "://" .. info.domain .. "/meta"
    local result, err = curl.request(async, url, opts)

    if not result.contents:match('"status"%s*:%s*"404"') then
        --- Note, this is **NOT** how github implements additional info.
        --- This is just an example.
        return true, { type = "cloud_server" }
    end

    return false
end

return {
    ...,
    supports = supports,
}
```

## Making Issues and Merge Requests

The provider should get the list of issues/merge_requests from server
(preferably using the built-in curl module). Depending on the git provider
server's way on fetching issues and merge requests, you may fetch more
sequentially or by parallel.

After getting the raws from curl, decode when using `rissue.utils.json`
(`require('rissue.utils.json')`), then process them and turn them into
`rissue.Issue` or `rissue.MergeRequest.`

After getting the initial issues / merge_requests, use the builder function `cb`
to add those issues to their own way of building the list. Most of the time, the
builder function is a `table.insert()` in the hood, but sometimes other methods
(such as folke/snacks's picker) has their own way to showing a list of items
asynchronously.

When either you have reached max limit asked by user or the server has exhausted
their list, return normally.

When you encounter an error (e.g. server not available), return them as
`err_msg: string`

Example:

```lua
---@type rissue.provider.GetIssues<any, any>
local function get_issues(async, info, token, opts, cb)
    for _, urls in ipairs(list_of_urls) do
        local curl_result = curl.run_async(async, "my_url_from_info", { auth = token })
        local items, err = get_items(curl_result.contents)
        if err then
            --- early exit since there wouldn't be any
            return err
        end
        for _, item in ipairs(items) do
            cb(into_issue(item))
        end
    end
end

return {
    ...,
    get_issues = get_issues,
}

```

## Types

<!-- &rissue.Provider@docs -->

### `rissue.Provider`

Specific requirements for a provider

- <details>
  <summary><code>get_issues</code>: <code>rissue.provider.GetIssues&lt;any, any&gt;</code> – Gets issues using the provided <code>info</code>.</summary>

  Read more from
  [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)

  </details>

- <details>
  <summary><code>get_merge_requests</code>: <code>rissue.provider.GetMergeRequests&lt;any, any&gt;</code> – Gets merge requests using the provided <code>info</code>.</summary>

  Read more from
  [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)

  </details>

- `name`: `string` — The provider name.
- `settings`: `table<string, any>` — Default settings of the provider. Used for
  merging settings at `get.issue()` and other related operations.
- <details>
  <summary><code>supports</code>: <code>rissue.provider.Supports&lt;any, any&gt;</code> – Checks if the remote information given is supported by the provider.</summary>

  Read more from
  [docs/types.md#rissue.provider.d](docs/types.md#rissueproviderd)

  </details>

- <details>
  <summary><code>version</code>: <code>{ major: integer, minor: integer, patch: integer }</code> – Current version of the provider.</summary>

  **Bumping rules:**

  - Major version **should only be bumped** when the specifications contains
    breaking changes.
  - Minor versions **should only be bumped** when the specifications contains
    new features but does not break any current changes.
  - The patch version is bumped when there are **changes within the provider
    itself without affecting the results**

  </details>

<!-- &rissue.Provider@docs -->

<!-- &rissue.provider.d@docs -->

### `rissue.provider.d`

- <details>
  <summary><code>get_issues</code>: <code>function(async: rissue.Async, info: rissue.RemoteInfo&lt;I&gt;, token: string|nil, opts: &lt;S:table&gt;, cb: fun(issue: rissue.Issue)): string?</code> – Gets issues using the provided <code>info</code>.</summary>

  Note: `cb` is used to construct issues. This is useful when showing partial
  results while fetching more items (e.g. snacks picker).

  </details>

- <details>
  <summary><code>get_merge_requests</code>: <code>function(async: rissue.Async, info: rissue.RemoteInfo&lt;I&gt;, token: string|nil, opts: &lt;S:table&gt;, cb: fun(issue: rissue.Issue)): string?</code> – Gets merge requests using the provided <code>info</code>.</summary>

  Note: `cb` is used to construct issues. This is useful when showing partial
  results while fetching more items (e.g. snacks picker).

  </details>

- <details>
  <summary><code>supports</code>: <code>function(async: rissue.Async, info: rissue.RemoteInfo&lt;I&gt;, token: string|nil, opts: &lt;S:table&gt;): boolean, table?</code> – Checks if the remote information given is supported by the provider.</summary>

  In some cases, the provider will try to query the server to look for clues
  such as querying `/meta` to check ghes version for github.

  The second return `additional_info` is used to give additional information
  about the provider such as ghes version (github enterprise server) in github.

  </details>

<!-- &rissue.provider.d@docs -->
