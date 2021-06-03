-- coding: UTF-8

local sql3  = require "lsqlite3"
local M     = require "modules.string_rc"
local utils = require "modules.utils"

local SQLITE_MASTER = "sqlite_master"
local ErrMsg, Norm = utils.ErrMsg, utils.Norm

---- Custom tokenizer support
-- static sqlite3_tokenizer    _tokinizer = { nullptr };
-- static sqlite3_tokenizer_module  _tokinizer_mod;
-- int fts3_create(int, const char *const*, sqlite3_tokenizer** tokenizer) { *tokenizer = &_tokinizer; return 0; }
-- int fts3_destroy(sqlite3_tokenizer*) { return 0; }
-- int fts3_open(sqlite3_tokenizer*, const char*, int, sqlite3_tokenizer_cursor**) { return 0; }
-- int fts3_close(sqlite3_tokenizer_cursor*) { return 0; }
-- int fts3_next(sqlite3_tokenizer_cursor*, const char**, int*, int*, int*, int*) { return 0; }

---- Collation support
-- int db_collation(void*, int, const void*, int, const void*) { return 0; }
-- void db_collation_reg(void*, sqlite3* db, int text_rep, const char* name) { sqlite3_create_collation(db, name, text_rep, nullptr, &db_collation); }
-- void db_collation_reg16(void*, sqlite3* db, int text_rep, const void* name) { sqlite3_create_collation16(db, name, text_rep, nullptr, &db_collation); }


local sqlite = {
--! Database object types.
  ot_unknown = 0; -- Unknown type
  ot_master  = 1; -- Master table (sqlite_master)
  ot_table   = 2; -- Table
  ot_view    = 3; -- View
  ot_index   = 4; -- Index
  ot_trigger = 5; -- Trigger
}

local mt_sqlite = { __index=sqlite }


function sqlite.newsqlite()
  local self = setmetatable({}, mt_sqlite)
  return self
end


function sqlite:db()
  return self._db
end


function sqlite.format_supported(file_hdr) -- function not method
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


function sqlite:open(file_name)
  local db = sql3.open(file_name)
  if db then
    -- since sql3.open() won't fail on a non-DB file, let's work around that with a statement
    local stmt = db:prepare("select name from "..SQLITE_MASTER)
    if stmt then
      db:create_collation("utf8_ncase", utf8 and utf8.ncasecmp or far.LStricmp)
      db:create_function("lower",  1, function(ctx,str) ctx:result_text(str:lower()) end)
      db:create_function("upper",  1, function(ctx,str) ctx:result_text(str:upper()) end)
      db:create_function("like",   2, func_like2)
      db:create_function("like",   3, func_like3)
      db:create_function("regexp", 2, func_regexp)
      self._db = db
      stmt:finalize()
      return true -- and self:prepare_tokenizers() and self:prepare_collations() --> put them aside currently
    else
      db:close()
    end
  end
  return false
end


function sqlite:close()
  if self._db then
    self._db:close()
    self._db = nil
  end
end


function sqlite:last_error()
  if self._db then
    local code = self._db:extended_errcode()
    local rc = ("Error %d(%d)"):format(code%0x100, code) -- primary/extended results
    if code ~= sql3.OK then
      rc = rc..": "..self._db:errmsg()
    end
    return rc
  else
    return "Error: Database not initialized"
  end
end


function sqlite:SqlErrMsg(query)
  ErrMsg(self:last_error().."\n"..M.err_sql..":\n"..query)
end


function sqlite:get_objects_list(schema)
  local objects = {}
  -- Add master table
  objects[1] = {
    row_count = 0;
    name = SQLITE_MASTER;
    type = sqlite.ot_master;
  }

  -- Add tables/views
  local query = "SELECT name,type FROM "..Norm(schema).."."..SQLITE_MASTER
  local stmt = self._db:prepare(query)
  if stmt then
    while stmt:step() == sql3.ROW do
      local obj = {
        row_count = 0;
        name = stmt:get_value(0);
        type = sqlite.object_type_by_name(stmt:get_value(1));
      }
      table.insert(objects, obj)
    end
    stmt:finalize()

    -- Get tables row count
    for _,v in ipairs(objects) do
      if v.type == sqlite.ot_master or v.type == sqlite.ot_table or v.type == sqlite.ot_view then
        v.row_count = self:get_row_count(schema, v.name) or 0
      end
    end
    return objects
  else
    self:SqlErrMsg(query)
  end
end


function sqlite:execute_query(query, show_message)
  if self._db:exec(query) == sql3.OK then
    return true
  end
  if show_message then
    self:SqlErrMsg(query)
  end
  return false
end


function sqlite:read_columns_info(schema, object)
  local query = ( "pragma %s.table_info(%s)" ):format(Norm(schema), Norm(object))
  local stmt = self._db:prepare(query)
  if stmt then
    local columns = {}
    while stmt:step() == sql3.ROW do
      local affinity
      local ct = stmt:get_value(2):lower()
      if     ct:find("int")                                        then affinity = "INTEGER"
      elseif ct:find("char") or ct:find("clob") or ct:find("text") then affinity = "TEXT"
      elseif ct:find("blob") or (ct == "")                         then affinity = "BLOB"
      elseif ct:find("real") or ct:find("floa") or ct:find("doub") then affinity = "REAL"
      else                                                              affinity = "NUMERIC"
      end
      table.insert(columns, { name=stmt:get_value(1); affinity=affinity; })
    end
    stmt:finalize()
    return columns
  else
    self:SqlErrMsg(query)
  end
end


function sqlite:get_row_count(aSchema, aObject)
  local count = nil
  local query = "select count(*) from ".. Norm(aSchema).."."..Norm(aObject);
  local stmt = self._db:prepare(query)
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
    self:SqlErrMsg(query)
  end
  return count
end


function sqlite:get_creation_sql(aSchema, aObject)
  local txt = false
  if aObject:lower() ~= SQLITE_MASTER:lower() then
    local query = ("select sql from %s.%s where name=?"):format(Norm(aSchema), SQLITE_MASTER)
    local stmt = self._db:prepare(query)
    if stmt then
      txt = stmt:bind(1,aObject)==sql3.OK and stmt:step()==sql3.ROW and stmt:get_value(0)
      stmt:finalize()
    end
  end
  return txt
end


function sqlite:get_object_type(schema, name)
  if name:lower() == "sqlite_master" then
    return "sqlite_master"
  end
  local tp
  local query = "SELECT type FROM ".. Norm(schema).."."..SQLITE_MASTER .." WHERE name=?"
  local stmt = self._db:prepare(query)
  if stmt then
    if stmt:bind(1, name)==sql3.OK and stmt:step()==sql3.ROW then
      tp = stmt:get_value(0):lower()
    end
    stmt:finalize()
  else
    self:SqlErrMsg(query)
  end
  return tp or "unknown"
end


local object_types = {
  table   = sqlite.ot_table;
  view    = sqlite.ot_view;
  index   = sqlite.ot_index;
  trigger = sqlite.ot_trigger;
}
function sqlite.object_type_by_name(type_name)
  return object_types[type_name:lower()] or sqlite.ot_unknown
end


--[=[
-- bool sqlite::prepare_tokenizers() const
function sqlite:prepare_tokenizers()
  -- Initialize dummy tokenizer
  if (!_tokinizer.pModule) {
    _tokinizer_mod.iVersion = 0;
    _tokinizer_mod.xCreate = &fts3_create;
    _tokinizer_mod.xDestroy = &fts3_destroy;
    _tokinizer_mod.xOpen = &fts3_open;
    _tokinizer_mod.xClose = &fts3_close;
    _tokinizer_mod.xNext = &fts3_next;
    _tokinizer.pModule = &_tokinizer_mod;
  }

  -- Read tokenizers names and register it as dummy stub
  sqlite_statement stmt(_db);
  if (stmt.prepare("select sql from " SQLITE_MASTER " where type='table'") != SQLITE_OK)
    return false;
  while (stmt.step_execute() == SQLITE_ROW) {
    const wchar_t* cs = stmt.get_text(0);
    if (!cs)
      continue;
    wstring crt_sql = cs;
    transform(crt_sql.begin(), crt_sql.end(), crt_sql.begin(), ::tolower);
    if (crt_sql.find("fts3") == string::npos)
      continue;
    const wchar_t* tok = "tokenize ";
    const size_t tok_pos = crt_sql.find(tok);
    if (tok_pos == string::npos)
      continue;
    const size_t tok_name_b = tok_pos + wcslen(tok);
    const size_t tok_name_e = crt_sql.find_first_of(", )", tok_name_b);
    if (tok_name_e == string::npos)
      continue;
    const wstring tokenizer_name = wstring(cs).substr(tok_name_b, tok_name_e - tok_name_b);
    -- Register tokenizer
    static const sqlite3_tokenizer_module* ptr = &_tokinizer_mod;
    sqlite_statement stmt_rt(_db);
    if (stmt_rt.prepare("select fts3_tokenizer(?, ?)") != SQLITE_OK ||
      stmt_rt.bind(1, tokenizer_name.c_str()) != SQLITE_OK ||
      stmt_rt.bind(2, &ptr, sizeof(ptr)) != SQLITE_OK ||
      stmt_rt.step_execute() != SQLITE_OK)
      return false;
  }

  return true;
end


bool sqlite::prepare_collations() const
{
  return
    sqlite3_collation_needed16(_db, nullptr, &db_collation_reg16) == SQLITE_OK &&
    sqlite3_collation_needed(_db, nullptr, &db_collation_reg) == SQLITE_OK;
}

]=]

return sqlite
