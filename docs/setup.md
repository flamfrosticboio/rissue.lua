# Rissue Setup

Page for setting up rissue.

## Usage

<!-- &rissue.setup()@docs -->

### rissue.setup()

Run setup for rissue.

Example:

```lua
rissue.setup({
   timeout = 20000 -- 20 seconds
}, "/home/user/projects/my_project")
-- Will read the .env file from that path
```

**Parameters:**

- `opts`: `(rissue.Opts)?` -- Configuration
- `cwd`: `string?` -- The current working directory (used in finding env file)

**Returns:**

- (1) `string?` -- The error message from setup

<!-- &rissue.setup()@docs -->

## Options

<!-- &rissue.Opts@docs -->

### `rissue.Opts`

- additional_providers: `string[]`
  -- List of provider's filepaths to import with `loadfile()`
- endpoint_shortcuts: `table<string, rissue.EndpointShortcut>`
- env: `(rissue.opts.Env)?`
- env_file: `string` -- The name of the env file
- provider_options: `table<string, table>`
  -- List of options for a provider. See the provider's documentation for the
  list of options that is supported.
- timeout: `integer`
  -- Specifies the timeout in milliseconds on operations such as `get.issues()`
  and `provider.get_provider_info()`

<!-- &rissue.Opts@docs -->

## Defaults

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
