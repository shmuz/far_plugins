1. Description.
   Polygon - a Far Manager plugin based on SQLiteDB plugin by Artem Senichev.
   https://github.com/shmuz/far_plugins

2. License.
    GNU GPL. Because it is a derivative work from a GPL'ed plugin.


3. Requirements.
   - sqlite3.dll
   - a modified version of lsqlite3.dll (with added method get_column_type())


4. Reference of keyboard actions when the plugin's panel is active.

   View       : Key         : Action
   -----------------------------------------------------------------------------
   All views  : CtrlA, F7   : Do nothing but prevent native FAR action
   All views  : F6          : Open Editor for editing an "SQLite query"

   DB View    : F3          : View contents of table under cursor
   DB View    : F4          : View create statement of table under cursor
   DB View    : ShiftF4     : View pragma statements
   DB View    : F5          : Invoke "Data export" dialog for table under cursor

   Table View : F4, Enter   : Invoke "Edit row" dialog for row under cursor
   Table View : ShiftF4     : Invoke "Insert row" dialog
   -----------------------------------------------------------------------------


5. Reference of command line actions when the plugin's panel is active.

   View       : Key         : Action
   -----------------------------------------------------------------------------
   All views  : Enter       : Execute an "SQLite query"
   -----------------------------------------------------------------------------


6. Changes with regards to the original SQLiteDB plugin.
    1. [change ] SQLite library is not embedded into plugin: external sqlite3.dll is required.
    2. [change ] Plugin exports files in UTF-8 encoding rather than UTF-16.
    3. [fix    ] DB file is not left locked by the plugin if another plugin is selected to open this DB.
    4. [fix    ] Normal work with selection when the panel displays a table contents.
    5. [add    ] Option "Honor foreign keys" (Settings dialog).
    6. [add    ] Option "Preserve line feeds" (Data Export dialog). This option preserves new lines in CSV-export.
    7. [add    ] Plugin can enter into "WITHOUT ROWID" tables (insert is supported; edit and delete are not).
    8. [add    ] Plugin can enter into and modify tables that have a "rowid"-named column that is not INTEGER PRIMARY KEY.
    9. [improve] Data Export dialog: change extension in the file name field when CSV/Text selection changes.
   10. [improve] Eliminate flickering with the progress window.
