# Gitlab

Adds support for `gitlab.com`

<!-- @VERSION:gitlab -->Version: 1.0.2<!-- @VERSION:gitlab -->

> [!NOTE]
>
> This provider is not rigorously tested against multiple versions. If there are
> versions that breaks, please report it through the issue tracker.

## Default Settings

To learn more about what each field does, see its
[type definition](/docs/types.md#rissuegitlabconfig)

<!-- *gitlab.config -->

```lua
--- Default settings for Gitlab provider
---@type rissue.Gitlab.Config
config.defaults = {
  max = 20,
  endpoints = {
    issues = {
      {
        endpoint = "projects/{repo}/issues",
        param = {
          order_by = "priority",
          sort = "asc",
          state = "opened",
        },
      },
    },
    merge_requests = {
      {
        endpoint = "projects/{repo}/merge_requests",
        param = {
          order_by = "priority",
          sort = "asc",
          state = "opened",
        },
      },
    },
  },
  per_page = 100,
  should_pass_raw = false,
  delay = 1000,
}
```

<!-- *gitlab.config -->
