package = "rissue"
rockspec_format = "3.0"
version = "dev-1"

source = {
  url = "git+https://github.com/flamfrosticboio/rissue.git",
}

description = {
  summary = "A file that abstracts issues and pull requests from git providers such as github and gitlab",
  detailed = "A file that abstracts issues and pull requests from git providers such as github and gitlab",
  homepage = "https://github.com/flamfrosticboio/rissue",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "luv >= 1.52.1",
}

build = {
  type = "builtin",
  modules = {},
}

test_dependencies = {
  "busted >= 2.3.0",
  "luv >= 1.52.1",
}
