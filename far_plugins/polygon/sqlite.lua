local sql3 = require "lsqlite3"
local Params = ...
local M = Params.M

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

local SQLITE_MASTER = "sqlite_master"


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
  return 1 == string.find(file_hdr, "^SQLite format 3%z")
end


function sqlite:open(file_name)
  local db = sql3.open(file_name)
  if db then
    -- since sql3.open() won't fail on a non-DB file, let's work around that with a statement
    local stmt = db:prepare("select name from "..SQLITE_MASTER)
    if stmt then
      stmt:finalize()
      self._db = db
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
    local code = self._db:errcode()
    local rc = "Error: ["..code.."]"
    if code ~= sql3.OK then
      rc = rc.." "..self._db:errmsg()
    end
    return rc
  else
    return "Error: Database not initialized"
  end
end


function sqlite:SqlErrMsg(query)
  ErrMsg(M.ps_err_sql.."\n"..query.."\n"..self:last_error())
end


function sqlite:get_objects_list(schema)
  local objects = {}
  -- Add master table
  local master_table = {
    row_count = 0;
    name = SQLITE_MASTER;
    type = sqlite.ot_master;
  }
  table.insert(objects, master_table)

  -- Add tables/views
  local schema_norm = schema:norm()
  local query = "select name,type from "..schema_norm.."."..SQLITE_MASTER
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
        v.row_count = self:get_row_count(schema, v.name)
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


function sqlite:read_column_description(schema, object)
  local query = "pragma "..schema:norm()..".".."table_info(" .. object:norm() .. ")"
  local stmt = self._db:prepare(query)
  if stmt then
    local columns = {}
    while stmt:step() == sql3.ROW do
      local col = { name = stmt:get_value(1); }
      table.insert(columns, col)

      local ct = stmt:get_value(2):lower()
      if ct:find("int") then
        col.affinity = "INTEGER"
      elseif ct:find("char") or ct:find("clob") or ct:find("text") then
        col.affinity = "TEXT"
      elseif ct:find("blob") or (ct == "") then
        col.affinity = "BLOB"
      elseif ct:find("real") or ct:find("floa") or ct:find("doub") then
        col.affinity = "REAL"
      else
        col.affinity = "NUMERIC"
      end
    end

    stmt:finalize()
    return columns
  else
    self:SqlErrMsg(query)
  end
end


function sqlite:get_row_count(aSchema, aObject)
  local count = 0
  local query = "select count(*) from ".. aSchema:norm().."."..aObject:norm();
  local stmt = self._db:prepare(query)
  if stmt then
    count = stmt:step()==sql3.ROW and stmt:get_value(0)
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
    local query = ("select sql from %s.%s where name=?"):format(aSchema:norm(), SQLITE_MASTER)
    local stmt = self._db:prepare(query)
    if stmt then
      txt = stmt:bind(1,aObject)==sql3.OK and stmt:step()==sql3.ROW and stmt:get_value(0)
      stmt:finalize()
    end
  end
  return txt
end


function sqlite:get_object_type(schema, name)
  if name:lower() == SQLITE_MASTER:lower() then
    return sqlite.ot_master
  end
  local tp = sqlite.ot_unknown
  local query = "select type from ".. schema:norm().."."..SQLITE_MASTER .." where name=?"
  local stmt = self._db:prepare(query)
  if stmt then
    if stmt:bind(1, name)==sql3.OK and stmt:step()==sql3.ROW then
      tp = sqlite.object_type_by_name(stmt:get_value(0))
    end
    stmt:finalize()
  else
    self:SqlErrMsg(query)
  end
  return tp
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
