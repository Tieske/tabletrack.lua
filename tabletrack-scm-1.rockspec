package = "tabletrack"
version = "scm-1"
source = {
  url = "git://github.com/Tieske/tabletrack.lua.git",
}
description = {
  summary = "Module to track table accesses",
  detailed = [[
    Module to (transparently) track table accesses and log to file, tracking
    what fields were accessed and from where.
  ]],
  homepage = "https://github.com/Tieske/tabletrack.lua",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.4",
}
build = {
  type = "builtin",
  modules = {
    ["tabletrack.init"] = "src/tabletrack/init.lua",
  },
  install = {
    bin = {
      tabletrack = "bin/tabletrack.lua"
    },
  },
}
