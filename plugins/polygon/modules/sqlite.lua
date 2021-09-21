-- coding: UTF-8

local sql3  = require "lsqlite3"
local M     = require "modules.string_rc"
local utils = require "modules.utils"

local ErrMsg, Norm = utils.ErrMsg, utils.Norm


--! Database object types.
local ot_unknown = 0
local ot_master  = 1 --> "sqlite_master"
local ot_table   = 2
local ot_view    = 3
local ot_index   = 4
local ot_trigger = 5

local object_types = {
  ["table"  ] = ot_table;
  ["view"   ] = ot_view;
  ["index"  ] = ot_index;
  ["trigger"] = ot_trigger;
}

local function encode_object_type(name)
  return object_types[name:lower()] or ot_unknown
end


local function decode_object_type(tp, exact)
  local name
  if     tp == ot_master  then name = exact and "metadata" or "table"
  elseif tp == ot_table   then name = "table"
  elseif tp == ot_view    then name = "view"
  elseif tp == ot_index   then name = "index"
  elseif tp == ot_trigger then name = "trigger"
  end
  return name
end


local function format_supported(file_hdr)
  return 1 == string.find(file_hdr, "^SQLite format 3")
end


local func_like2, func_like3, func_regexp do
  local cache_like2 = {}
  local cache_like3 = {}
  local cache_regexp = {}
  local pat_esc = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

  func_like2 = function(ctx, pat, subj)
    local pat2 = cache_like2[pat]
    if pat2 == nil then
      pat2 = pat:lower():gsub(".",
        function(c)
          if c=="%" then return ".*" end
          if c=="_" then return "."  end
          return ( c:gsub(pat_esc, "%%%1") )
        end)
      pat2 = "^"..pat2.."$"
      cache_like2[pat] = pat2
    end
    ctx:result_int(subj and subj:lower():find(pat2) and 1 or 0)
  end

  func_like3 = function(ctx, pat, subj, esc)
    if esc == "" then
      return func_like2(ctx, pat, subj)
    end
    local cache = cache_like3[esc]
    if cache_like3[esc] == nil then
      cache = {}
      cache_like3[esc] = cache
    end
    local pat2 = cache[pat]
    if pat2 == nil then
      esc = esc:sub(1,1):lower():gsub(pat_esc, "%%%1")
      pat2 = pat:lower():gsub("("..esc.."?)(.)",
        function(c1,c2)
          if c2=="%" then return (c1 == "" and ".*" or "%%") end
          if c2=="_" then return (c1 == "" and "."  or "_" ) end
          return ( c2:gsub(pat_esc, "%%%1") )
        end)
      pat2 = "^"..pat2.."$"
      cache[pat] = pat2
    end
    ctx:result_int(subj and subj:lower():find(pat2) and 1 or 0)
  end

  func_regexp = function(ctx, pat, subj)
    local pat2 = cache_regexp[pat]
    if pat2 == nil then
      pat2 = regex.new(pat) or 0
      cache_regexp[pat] = pat2
    end
    ctx:result_int(subj and pat2~=0 and pat2:find(subj) and 1 or 0)
  end
end


local function open(file_name)
  local db = sql3.open(file_name)
  if db then
    -- since sql3.open() won't fail on a non-DB file, let's work around that with a statement
    local stmt = db:prepare("SELECT name FROM sqlite_master")
    if stmt then
      db:create_collation("utf8_ncase", utf8 and utf8.ncasecmp or far.LStricmp)
      db:create_function("lower",  1, function(ctx,str) ctx:result_text(str:lower()) end)
      db:create_function("upper",  1, function(ctx,str) ctx:result_text(str:upper()) end)
      db:create_function("like",   2, func_like2)
      db:create_function("like",   3, func_like3)
      db:create_function("regexp", 2, func_regexp)
      stmt:finalize()
      return db -- and self:prepare_tokenizers() and self:prepare_collations() --> put them aside currently
    else
      db:close()
    end
  end
end


local function last_error(db)
  if db then
    local code = db:extended_errcode()
    local rc = ("Error %d(%d)"):format(code%0x100, code) -- primary/extended results
    if code ~= sql3.OK then
      rc = rc..": "..db:errmsg()
    end
    return rc
  else
    return "Error: Database not initialized"
  end
end


local function err_message(db, query)
  ErrMsg(last_error(db).."\n"..M.err_sql..":\n"..query)
end


local function get_row_count(db, aSchema, aObject)
  local count = nil
  local query = "SELECT count(*) FROM ".. Norm(aSchema).."."..Norm(aObject);
  local stmt = db:prepare(query)
  if stmt then
    if stmt:step()==sql3.ROW then
      count = stmt:get_value(0)
    end
    stmt:finalize()
  else
    -- TODO: this error is also issued when 'aObject' belongs to a VIEW
    --       but the table that the VIEW references does not exist.
    --       If this is the case then the error message should NOT be issued
    --       instead just return 0;
    err_message(db, query)
  end
  return count
end


local function get_objects_list(db, schema)
  local objects = {}
  -- Add master table
  objects[1] = {
    row_count = 0;
    name = "sqlite_master";
    type = ot_master;
  }

  -- Add tables/views
  local query = ("SELECT name,type FROM %s.sqlite_master"):format(Norm(schema))
  local stmt = db:prepare(query)
  if stmt then
    while stmt:step() == sql3.ROW do
      local obj = {
        row_count = 0;
        name = stmt:get_value(0);
        type = encode_object_type(stmt:get_value(1));
      }
      table.insert(objects, obj)
    end
    stmt:finalize()

    -- Get tables row count
    for _,v in ipairs(objects) do
      if v.type == ot_master or v.type == ot_table or v.type == ot_view then
        v.row_count = get_row_count(db, schema, v.name) or 0
      end
    end
    return objects
  else
    err_message(db, query)
  end
end


local function execute_query(db, query, show_message)
  if db:exec(query) == sql3.OK then
    return true
  end
  if show_message then
    err_message(db, query)
  end
  return false
end


local function read_columns_info(db, schema, object)
  local query = ( "pragma %s.table_info(%s)" ):format(Norm(schema), Norm(object))
  local stmt = db:prepare(query)
  if stmt then
    local columns = {}
    while stmt:step() == sql3.ROW do
      local affinity = "NUMERIC"
      local ct = stmt:get_value(2):lower()
      if     ct:find("int")                                        then affinity = "INTEGER"
      elseif ct:find("char") or ct:find("clob") or ct:find("text") then affinity = "TEXT"
      elseif ct:find("blob") or (ct == "")                         then affinity = "BLOB"
      elseif ct:find("real") or ct:find("floa") or ct:find("doub") then affinity = "REAL"
      end
      table.insert(columns, { name=stmt:get_value(1); affinity=affinity; })
    end
    stmt:finalize()
    return columns
  else
    err_message(db, query)
  end
end


local function get_creation_sql(db, aSchema, aObject)
  if aObject:lower() ~= "sqlite_master" then
    local query = ("SELECT sql FROM %s.sqlite_master WHERE name=?"):format(Norm(aSchema))
    local stmt = db:prepare(query)
    if stmt then
      local txt = stmt:bind(1,aObject)==sql3.OK and stmt:step()==sql3.ROW and stmt:get_value(0)
      stmt:finalize()
      return txt
    end
  end
end


local function get_object_type(db, schema, name)
  if name:lower() == "sqlite_master" then
    return "table"
  end
  local tp
  local query = ("SELECT type FROM %s.sqlite_master WHERE name=?"):format(Norm(schema))
  local stmt = db:prepare(query)
  if stmt then
    if stmt:bind(1, name)==sql3.OK and stmt:step()==sql3.ROW then
      tp = stmt:get_value(0):lower()
    end
    stmt:finalize()
  else
    err_message(db, query)
  end
  return tp or "unknown"
end


return {
  decode_object_type = decode_object_type;
  err_message        = err_message;
  execute_query      = execute_query;
  format_supported   = format_supported;
  get_creation_sql   = get_creation_sql;
  get_object_type    = get_object_type;
  get_objects_list   = get_objects_list;
  get_row_count      = get_row_count;
  last_error         = last_error;
  open               = open;
  read_columns_info  = read_columns_info;
}
