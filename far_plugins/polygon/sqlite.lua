local sql3 = require "lsqlite3"

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


function sqlite:get_objects_list(objects)
  -- Add master table
  local master_table = {
    row_count = 0;
    name = SQLITE_MASTER;
    type = sqlite.ot_master;
  }
  table.insert(objects, master_table)

  -- Add tables/views
  local stmt = self._db:prepare("select name,type from "..SQLITE_MASTER)
  if not stmt then
    return false
  end
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
      local query = "select count(*) from " .. v.name:normalize() .. ";"
      local stmt = self._db:prepare(query)
      if stmt then
        if stmt:step() == sql3.ROW then
          v.row_count = stmt:get_value(0)
        end
        stmt:finalize()
      end
    end
  end
  return true
end


function sqlite:execute_query(query)
  return self._db:exec(query) == sql3.OK
end


function sqlite:read_column_description(object_name)
  local query = "pragma table_info(" .. object_name:normalize() .. ")"
  local stmt = self._db:prepare(query)
  if stmt then
    local columns = {}
    while stmt:step() == sql3.ROW do
      local col = { name = stmt:get_value(1); }
      table.insert(columns, col)

      local ct = stmt:get_value(2):upper()
      if ct:find("INT") then
        col.type = sql3.INTEGER
      elseif ct:find("CHAR") or ct:find("CLOB") or ct:find("TEXT") then
        col.type = sql3.TEXT
      elseif ct:find("BLOB") or (ct == "") then
        col.type = sql3.BLOB
      elseif ct:find("REAL") or ct:find("FLOA") or ct:find("DOUB") then
        col.type = sql3.FLOAT
      else
        col.type = sql3.INTEGER
      end
    end

    stmt:finalize()
    return columns
  end
end


function sqlite:get_row_count(object_name)
  local count = false
  local query = "select count(*) from ".. object_name:normalize() .. ";";
  local stmt = self._db:prepare(query)
  if stmt then
    count = stmt:step()==sql3.ROW and stmt:get_value(0)
    stmt:finalize()
  end
  return count
end


function sqlite:get_creation_sql(object_name)
  local txt = false
  if object_name:lower() ~= SQLITE_MASTER:lower() then
    local stmt = self._db:prepare("select sql from " .. SQLITE_MASTER .. " where name=?")
    if stmt then
      txt = stmt:bind(1,object_name)==sql3.OK and stmt:step()==sql3.ROW and stmt:get_value(0)
      stmt:finalize()
    end
  end
  return txt
end


function sqlite:get_object_type(object_name)
  if object_name:lower() == SQLITE_MASTER:lower() then
    return sqlite.ot_master
  end

  local tp = sqlite.ot_unknown
  local stmt = self._db:prepare("select type from ".. SQLITE_MASTER .." where name=?")
  if stmt then
    if stmt:bind(1, object_name)==sql3.OK and stmt:step()==sql3.ROW then
      tp = sqlite.object_type_by_name(stmt:get_value(0))
    end
    stmt:finalize()
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
