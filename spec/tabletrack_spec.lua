local tt = require "tabletrack"

local dump = function(t)
  -- uncomment next line for verbose output
  --print(require("pl.pretty").write(t))
end

describe("tabletrack", function()


  local filename = "./tracker_output"
  local snapshot


  before_each(function()
    os.remove(filename)
    snapshot = assert:snapshot()
    assert:set_parameter("TableFormatLevel", -1)
  end)


  after_each(function()
    os.remove(filename)
    snapshot:revert()
  end)


  it("tracks access of a new key, set+get", function()
    local t = tt.track_access({}, {
      name = "test_table",
      filename = filename,
    })
    t.hello = "world"
    local x = t.world                       -- luacheck: ignore

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("tracks access of an existing key", function()
    tt.track_access({
      hello = "world",
    }, {
      name = "test_table",
      filename = filename,
    })
    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.exists)
    local trace, count = next(results.test_table.hello.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("gets the first stacktrace line", function()
    local t = tt.track_access({}, {
      name = "test_table",
      filename = filename,
      full_trace = false,
    })
    t.hello = "world"
    local x = t.world                       -- luacheck: ignore

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.not_matches("\\", trace)
    assert.not_matches("\n", trace)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.not_matches("\\", trace)
    assert.not_matches("\n", trace)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("gets the full stacktrace", function()
    local t = tt.track_access({}, {
      name = "test_table",
      filename = filename,
      full_trace = true,
    })
    t.hello = "world"
    local x = t.world                       -- luacheck: ignore

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("\\", trace)
    assert.not_matches("\n", trace)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("\\", trace)
    assert.not_matches("\n", trace)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("tracks access of a new key, with meta table, set+get", function()
    local t = setmetatable({},{})
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    t.hello = "world"
    local x = t.world                       -- luacheck: ignore

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("tracks access of an existing key, with meta table", function()
    local t = setmetatable({},{})
    t.hello = "world"
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.exists)
    local trace, count = next(results.test_table.hello.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("tracks access with meta table, where __index is a table", function()
    local t = setmetatable({},{
      __index = {
        world = "from the mt-index"
      }
    })
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    t.hello = "world"
    local x = t.world
    assert.equal("from the mt-index", x)

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("doesn't track the same table twice", function()
    local t = setmetatable({},{})
    t.hello = "world"
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    assert.has.error(function() tt.track_access(t) end,
                     "cannot track an already tracked table")
  end)


  it("tracks access of a new key, with meta table having index/newindex, set+get", function()
    local t = setmetatable({},{
      __index = function(self, key) return "xxx" end,
      __newindex = function(self, key, value)
        rawset(self, "called", key)
      end,
    })
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    t.hello = "world"
    assert.equal("hello", rawget(t, "called")) -- __newindex was invoked
    local xxx = t.world
    assert.equal("xxx", xxx)  -- __index should be invoked

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)
  end)


  it("tracks only the tracked table when reusing a metatable", function()
    local t = setmetatable({},{
      __index = function(self, key) return "xxx" end,
      __newindex = function(self, key, value)
        rawset(self, "called", key)
      end,
    })
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    local s = setmetatable({}, getmetatable(t))

    t.hello = "world"
    assert.equal("hello", rawget(t, "called")) -- __newindex was invoked
    local xxx = t.world
    assert.equal("xxx", xxx)  -- __index should be invoked

    s.world = "hello"
    assert.equal("world", rawget(s, "called")) -- __newindex was invoked
    local xxx = s.hello
    assert.equal("xxx", xxx)  -- __index should be invoked

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    results.test_table.hello = nil
    results.test_table.world = nil
    assert.same({test_table = {}}, results)
  end)


  it("tracks the proper table when reusing a metatable", function()
    local t = setmetatable({},{
      __index = function(self, key) return "xxx" end,
      __newindex = function(self, key, value)
        rawset(self, "called", key)
      end,
    })
    tt.track_access(t, {
      name = "test_table",
      filename = filename,
    })
    local s = setmetatable({}, getmetatable(t))
    tt.track_access(s, {
      name = "test_table_s",
      filename = filename,
    })

    t.hello = "world"
    assert.equal("hello", rawget(t, "called")) -- __newindex was invoked
    local xxx = t.world
    assert.equal("xxx", xxx)  -- __index should be invoked

    s.world = "hello"
    assert.equal("world", rawget(s, "called")) -- __newindex was invoked
    local xxx = s.hello
    assert.equal("xxx", xxx)  -- __index should be invoked

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table_s.world.set)
    local trace, count = next(results.test_table_s.world.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table_s.hello.get)
    local trace, count = next(results.test_table_s.hello.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    results.test_table.hello = nil
    results.test_table.world = nil
    results.test_table_s.hello = nil
    results.test_table_s.world = nil
    assert.same({test_table = {}, test_table_s = {}}, results)
  end)


  it("tracks all instances of a metatable", function()
    local mt = tt.track_type({
      __index = function(self, key) return "xxx" end,
      __newindex = function(self, key, value)
        rawset(self, "called", key)
      end,
    }, {
      name = "test_mt_table",
      filename = filename,
      full_trace = true,
    })

    local t = setmetatable({ hello_exists = "world"}, mt)
    local s = setmetatable({ world_exists = "hello"}, mt)

    t.hello = "world"
    assert.equal("hello", rawget(t, "called")) -- __newindex was invoked
    local xxx = t.world
    assert.equal("xxx", xxx)  -- __index should be invoked

    local xxx = s.hello
    assert.equal("xxx", xxx)  -- __index should be invoked
    s.world = "hello"
    assert.equal("world", rawget(s, "called")) -- __newindex was invoked

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_mt_table.hello_exists.exists)
    local trace, count = next(results.test_mt_table.hello_exists.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world_exists.exists)
    local trace, count = next(results.test_mt_table.world_exists.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.hello.set)
    local trace, count = next(results.test_mt_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world.get)
    local trace, count = next(results.test_mt_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world.set)
    local trace, count = next(results.test_mt_table.world.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.hello.get)
    local trace, count = next(results.test_mt_table.hello.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    results.test_mt_table.hello = nil
    results.test_mt_table.world = nil
    results.test_mt_table.hello = nil
    results.test_mt_table.world = nil
    results.test_mt_table.world_exists = nil
    results.test_mt_table.hello_exists = nil
    assert.same({test_mt_table = {}}, results)
  end)


  it("tracks multiple calls when using a proxy", function()
    local t = tt.track_access({}, {
      name = "test_table",
      filename = filename,
      proxy = true,
    })
    t.hello = "world"
    t.hello = "world"
    local x = t.world                       -- luacheck: ignore
    local x = t.world                       -- luacheck: ignore
    local x = t.world                       -- luacheck: ignore

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_table.hello.set)
    local trace, count = next(results.test_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_table.world.get)
    local trace, count = next(results.test_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

  end)


  it("tracks all instances of a metatable with proxy", function()
    local last_call
    local mt = tt.track_type({
      __index = function(self, key)
        last_call = "__index"
        return "xxx"
      end,
      __newindex = function(self, key, value)
        last_call = "__newindex"
        rawset(self, "called", key)
      end,
    }, {
      name = "test_mt_table",
      filename = filename,
      full_trace = true,
      proxy = true,
    })

    local t = setmetatable({ hello_exists = "world"}, mt)
    local s = setmetatable({ world_exists = "hello"}, mt)

    last_call = nil
    t.hello = "world"
    assert.equal("__newindex", last_call) -- __newindex was invoked

    last_call = nil
    local xxx = t.world
    assert.equal("__index", last_call)  -- __index should be invoked
    assert.equal("xxx", xxx)

    last_call = nil
    local xxx = s.hello   -- luacheck: ignore
    assert.equal("__index", last_call)  -- __index should be invoked

    last_call = nil
    s.world = "hello"
    assert.equal("__newindex", last_call) -- __newindex was invoked

    local results = tt.parse_file(filename)
    dump(results)
    assert(results.test_mt_table.hello_exists.exists)
    local trace, count = next(results.test_mt_table.hello_exists.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world_exists.exists)
    local trace, count = next(results.test_mt_table.world_exists.exists)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.hello.set)
    local trace, count = next(results.test_mt_table.hello.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world.get)
    local trace, count = next(results.test_mt_table.world.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.world.set)
    local trace, count = next(results.test_mt_table.world.set)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    assert(results.test_mt_table.hello.get)
    local trace, count = next(results.test_mt_table.hello.get)
    assert.equal(count, 1)
    assert.matches("^[^\\]+tabletrack_spec%.lua", trace)

    results.test_mt_table.hello = nil
    results.test_mt_table.world = nil
    results.test_mt_table.hello = nil
    results.test_mt_table.world = nil
    results.test_mt_table.world_exists = nil
    results.test_mt_table.hello_exists = nil
    assert.same({test_mt_table = {}}, results)
  end)


end)
