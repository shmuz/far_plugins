1. Description.
   Polygon - a Far Manager plugin based on SQLiteDB plugin by Artem Senichev.
   https://github.com/shmuz/far_plugins

2. License.
    GNU GPL. Because it is a derivative work from a GPL'ed plugin.


3. Requirements.
   - sqlite3.dll  (https://sqlite.org/)
   - lsqlite3.dll (https://github.com/shmuz/lsqlite3-s)


4. Changes with regards to the original SQLiteDB plugin.
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
