# RIssue

A plugin that abstracts issues and pull requests from git providers such as:

- github
- gitlab (planned on v0.3)
- gitea (planned on v0.4)
- forgejo (codeberg) (planned on v0.4)

This plugin can be extended for integrations for multiple plugins such as Snacks.

> [!NOTE]
> This project is still on alpha

## Documentation

Browse in the [docs folder](./docs) for documentation.

To get started, go to [docs/main.md](./docs/main.md)

## Setup

Install dependencies required:

- luv (lua libuv)

  ```bash
  # With luarocks
  luarocks install luv
  ```

- curl (version >= 7.81.0)

On linux, install it with your preferred package manager (apt, pacman, etc.).

On windows, install it with your preferred way (winget, website, choco, etc.)

## Developing

Install mise and run in project root:

```bash
mise setup
```
