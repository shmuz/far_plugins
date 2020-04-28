.Language=English,English
.PluginContents=LuaFAR History
.Options CtrlColorChar=\

@Contents
$ #LuaFAR History (version #{VER_STRING}) - Help Contents -#
 #LuaFAR History# is a plugin for displaying histories of commands,
folders, and viewed/edited files.

 When a history list is displayed, its items can be filtered by filtering
patterns entered from the keyboard. The pattern is displayed in the window
title. There are 4 switchable filtering methods available:

 - DOS patterns (#*# and #?#)
 - Lua patterns
 - FAR regular expressions
 - Plain text

 #Keyboard control:#

 \3BAll histories\-
   #F5#                 Switch filtering method.
   #F6#                 In items not fitting into window width:
                      toggle ellipsis between (0,1,2,3)/3 of width.
   #F7#                 Show item in message box.
   #F8#                 Turn "xlat-filter" on/off
                      (two patterns are searched simultaneously).
   #F9#                 Set filter to the last used value.
   #Ctrl-Enter#         Copy item to command line.
   #Ctrl-C#, #Ctrl-Ins#   Copy item to clipboard.
   #Ctrl-Shift-Ins#     Copy all filtered items to clipboard.
   #Shift-Del#          Delete item from the history.
   #Ctrl-Del#           Delete all filtered items from the history.
   #Del#                Clear filter.
   #Ctrl-V#, #Shift-Ins#  Set filter to clipboard value.
   #Ctrl-Alt-X#         Apply XLat conversion on filter and also
                      switch the keyboard layout.
   #Ctrl-I#             Inverse sort order.
   #Alt-F8#             Switch to Commands history.
   #Alt-F11#            Switch to View/Edit history.
   #Alt-F12#            Switch to Folders history.
   #Ins#                Check the item (it protects from deleting by Ctrl-Del or Ctrl-F8)

 \3BCommands history\-
   #Enter#              Execute.
   #Shift-Enter#        Execute in a new window.

 \3BView/Edit history\-
   #F3#                 View.
   #F4#                 Edit.
   #Alt-F3#             View modally, return to the menu.
   #Alt-F4#             Edit modally, return to the menu.
   #Enter#              View or edit.
   #Shift-Enter#        View or edit (item position is not changed).
   #Ctrl-PgUp#          Go to the file (in active panel).
   #Ctrl-PgDn#          Go to the file (in active panel) and open it.
   #Ctrl-F8#            Delete non-existent items

 \3BFolders history\-
   #Enter#              Change directory (active panel).
   #Shift-Enter#        Change directory (passive panel).
   #Ctrl-F8#            Delete non-existent items

 \3BLocate file\-
   #Enter#              Locate file in the active panel.
   #F3#                 View.
   #F4#                 Edit.
   #Alt-F3#             View modally, return to the menu.
   #Alt-F4#             Edit modally, return to the menu.

 Technical topics:
     ~Plugin's Configuration Dialog~@PluginConfig@

@PluginConfig
$ #Plugin's Configuration Dialog#
 #Max. History Size#

    Maximal amount of records:

   #Commands#           in the history of commands
   #View/Edit#          in the history of viewed/edited files
   #Folders#            in the history of folders

 #Window properties#

    These options affect history window.

   #[x] Dynamic Resize#

    With this option checked, history window will change its size
according to amount and content of records in the history.

   #[x] Auto Center#

    With this option checked, history window will be shown centered
in FAR window.

 ~Contents~@Contents@
