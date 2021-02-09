local names = {
  "title",
  "title_short",
  "title_ddl",
  "title_pragma",

  "cfg_add_pm",
  "cfg_confirm_close",
  "cfg_multidb_mode",
  "cfg_prefix",
  "cfg_user_modules",
  "cfg_extensions",
  "cfg_no_foreign_keys",
  "cfg_no_secur_warn",

  "pt_name",
  "pt_type",
  "pt_count",

  "reading",
  "execsql",

  "insert_row_title",
  "edit_row_title",
  "drop_question",
  "detach_question",

  "exp_title",
  "exp_main",
  "exp_fmt",
  "exp_fmt_csv",
  "exp_fmt_text",
  "exp_exp",
  "exp_multiline",

  "dump_title",
  "dump_main",
  "dump_dump",
  "dump_dumpall",
  "dump_rowids",
  "dump_newlines",

  "err_open",
  "err_read",
  "err_sql",
  "err_readf",
  "err_writef",
  "err_del_norowid",
  "err_edit_norowid",
  "err_openfile",

  "warning",
  "save",
  "cancel",
  "ok",
  "yes_no",
  "overwrite",
  "already_exists",
  "confirm_close",

  "title_select_columns",
  "set_columns",
  "reset_columns",

  "panel_filter",

  "module_not_found",
}

local indexes = {}
for i=1,#names do indexes[names[i]]=i-1; end

local GetMsg = far.GetMsg
return setmetatable( {},
  { __index = function(t,s) return GetMsg(indexes[s]) end } )
