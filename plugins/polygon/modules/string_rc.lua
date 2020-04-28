local names = {
  "ps_title",
  "ps_title_short",
  "ps_title_ddl",
  "ps_title_pragma",

  "ps_cfg_add_pm",
  "ps_cfg_confirm_close",
  "ps_cfg_multidb_mode",
  "ps_cfg_prefix",
  "ps_cfg_user_modules",
  "ps_cfg_extensions",
  "ps_cfg_no_foreign_keys",
  "ps_cfg_no_secur_warn",

  "ps_pt_name",
  "ps_pt_type",
  "ps_pt_count",

  "ps_reading",
  "ps_execsql",

  "ps_insert_row_title",
  "ps_edit_row_title",
  "ps_drop_question",
  "ps_detach_question",

  "ps_exp_title",
  "ps_exp_main",
  "ps_exp_fmt",
  "ps_exp_fmt_text",
  "ps_exp_exp",
  "ps_exp_multiline",

  "ps_dump_title",
  "ps_dump_main",
  "ps_dump_dump",
  "ps_dump_dumpall",
  "ps_dump_rowids",
  "ps_dump_newlines",

  "ps_err_open",
  "ps_err_read",
  "ps_err_sql",
  "ps_err_readf",
  "ps_err_writef",
  "ps_err_del_norowid",
  "ps_err_edit_norowid",
  "ps_err_openfile",

  "ps_warning",
  "ps_save",
  "ps_cancel",
  "ps_ok",
  "ps_yes_no",
  "ps_overwrite",
  "ps_already_exists",
  "ps_confirm_close",

  "ps_title_select_columns",
  "ps_set_columns",
  "ps_reset_columns",

  "ps_panel_filter",

  "ps_module_not_found",
}

local indexes = {}
for i=1,#names do indexes[names[i]]=i-1; end

local GetMsg = far.GetMsg
return setmetatable( {},
  { __index = function(t,s) return GetMsg(indexes[s]) end } )
