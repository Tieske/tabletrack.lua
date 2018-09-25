#!/usr/bin/env lua

local tt = require "tabletrack"

local filter = {}
local files = {}
local by_source = false

local function insert_filter(f)
  if not (f:find("^[^%.%s]+%.[^%.%s]+$") or f:find("^[^%.%s]+$")) then
    error("Bad filter format provided: " .. tostring(f))
  end
  filter[f] = true
end

-- parse arguments
local i = 0
while i < #arg do
  i = i + 1
  local val = arg[i]
  -- filter switch
  if val == "-f" then
    i = i + 1
    insert_filter(arg[i])
  elseif val == "-s" then
    by_source = true
  elseif val == "-h" or val == "--help" then
    print [[
usage:
  tabletrack [options] <filename> ...

  options:
    -f filter : specifies a table/field filter
    -s        : indexes by sourcecode (default is table+field name)
]]
    os.exit()
  else
    files[#files+1] = val
  end
end


-- parse files
local result = {}
for i = 1, math.max(1,#files) do -- if no files, then still 1, which invokes with nil, causing the default filename
  local r = tt.parse_file(files[i])
  for table_name, fields in pairs(r) do
    result[table_name] = result[table_name] or {}
    local tbl = result[table_name]
    for field_name, types in pairs(fields) do
      tbl[field_name] = tbl[field_name] or {}
      local field = tbl[field_name]
      for type_name, traces in pairs(types) do
        field[type_name] = field[type_name] or {}
        local tpe = field[type_name]
        for trace, count in pairs(traces) do
          tpe[trace] = (tpe[trace] or 0) + count
        end
      end
    end
  end
end

-- filter fields
if next(filter) then
  for table_name, fields in pairs(result) do
    if not filter[table_name] then -- this one is not allowed, check on fields
      for field_name, methods in pairs(fields) do
        if not filter[table_name .. "." .. field_name] then
          -- field also not allowed, so remove
          fields[field_name] = nil
        end
      end
      if not next(fields) then
        -- all fields gone, so remove table
        result[table_name] = nil
      end
    end
  end
end

-- for sorting, do numerical compare for line numbers
local function match_line(trace)
  local s, e = trace:find(":%d*:")
  return trace:sub(1,s) .. string.rep("0",10 - (e - s - 1)) .. trace:sub(s+1, -1)
end

local function display_plain(result)
  local tables = {}
  for table_name, data in pairs(result) do
    tables[#tables+1] = { table_name = table_name, data = data }
  end
  table.sort(tables, function(a,b)
    return a.table_name:upper() < b.table_name:upper()
  end)

  for _, t in ipairs(tables) do
    local name = t.table_name
    local data = t.data
    print(name)

    local fields = {}
    for field_name, data in pairs(data) do
      fields[#fields+1] = { field_name = field_name, data = data }
    end
    table.sort(fields, function(a,b)
      return a.field_name:upper() < b.field_name:upper()
    end)

    for _, f in ipairs(fields) do
      local name = f.field_name
      local data = f.data
      print("  " .. name)

      local entries = {}
      for call_type, trace_data in pairs(data) do
        for trace, count in pairs(trace_data) do
          entries[#entries+1] = trace .. " (" .. call_type .. " x " .. count ..")"
        end
      end
      table.sort(entries, function(a, b)
        return match_line(a) < match_line(b)
      end)
      for _, entry in ipairs(entries) do
        print("    " .. entry)
      end
    end
  end
end


local function display_source(result)
  local list = {}
  for table_name, fields in pairs(result) do
    for field_name, types in pairs(fields) do
      for type_name, traces in pairs(types) do
        for trace, count in pairs(traces) do
          local name = table_name .. "." .. field_name
          name = name .. string.rep(" ", 30 - #name)
          trace = trace .. string.rep(" ", 90 - #trace)
          list[#list+1] = trace .. " -- " .. name .. " (" .. type_name .. " x " .. count ..")"
        end
      end
    end
  end
  table.sort(list, function(a, b)
    return match_line(a) < match_line(b)
  end)
  for _, entry in ipairs(list) do
    print(entry)
  end
end

if by_source then
  display_source(result)
else
  display_plain(result)
end
