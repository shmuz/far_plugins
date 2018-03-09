local names = {
  "ps_title",
  "ps_title_short",
  "ps_title_ddl",
  "ps_title_pragma",

  "ps_cfg_add_pm",
  "ps_cfg_prefix",
  "ps_cfg_foreign_keys",

  "ps_pt_name",
  "ps_pt_type",
  "ps_pt_count",

  "ps_reading",
  "ps_execsql",

  "ps_insert_row_title",
  "ps_edit_row_title",
  "ps_drop_question",

  "ps_exp_title",
  "ps_exp_main",
  "ps_exp_fmt",
  "ps_exp_fmt_text",
  "ps_exp_exp",
  "ps_exp_multiline",

  "ps_err_open",
  "ps_err_read",
  "ps_err_sql",
  "ps_err_readf",
  "ps_err_writef",
  "ps_err_del_norowid",
  "ps_err_edit_norowid",

  "ps_save",
  "ps_cancel",
}

local indexes = {}
for i=1,#names do indexes[names[i]]=i-1; end

local GetMsg = far.GetMsg
return setmetatable( {},
  { __index = function(t,s) return GetMsg(indexes[s]) end } )