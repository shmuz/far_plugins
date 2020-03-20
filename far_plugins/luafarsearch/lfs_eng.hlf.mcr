.Language=English,English
.PluginContents=LuaFAR Search
.Options CtrlStartPosChar=¦

@Contents
$ #LuaFAR Search (version #{VER_STRING})#
^#FEATURES#
 * Search and replace in the editor.
 * Search and replace from the panels.
 * Regular expressions (4 libraries to choose from).
 * User scripts in Lua language, with access to LuaFAR library,
   the regular expression libraries and to the plugin's API.
 * Plugin menus can be extended with user's items that may include
   "presets", test scripts, etc.

 #Editor#
   ~Menu~@EditorMenu@
   ~Search and replace~@OperInEditor@
   ~Multi-Line Replace~@MReplace@

 #Panels#
   ~Menu~@PanelMenu@
   ~Search and Replace~@OperInPanels@
   ~Grep~@PanelGrep@
   ~Rename~@Rename@
   ~Panel~@TmpPanel@

 #Other#
   ~Configuration~@Configuration@
   ~Presets~@Presets@
   ~User Scripts~@UserScripts@

 #Details on regular exression libraries#
   ~Far regular expressions~@:RegExp@
   ~Oniguruma~@Oniguruma@
   ~PCRE~@PCRE@
   ~Syntax of Replace pattern~@SyntaxReplace@

^#LIBRARIES USED BY THE PLUGIN#
 #Lua 5.1#                    : lua51.dll
 #LuaFAR#                     : luafar3.dll
 #Universal Charset Detector# : ucd.dll
 #Lrexlib#                    : rex_onig.dll, rex_pcre.dll, rex_pcre2.dll (optional)
 #Oniguruma#                  : onig.dll (optional)
 #PCRE#                       : pcre.dll (optional)
 #PCRE2#                      : pcre2.dll (optional)

@EditorMenu
$ #Plugin's menu in the Editor#
^#Menu items#

 #Find#                               ¦Find text using settings specified in the ~dialog~@OperInEditor@.
 
 #Replace#                            ¦Replace text using settings specified in the ~dialog~@OperInEditor@.
 
 #Repeat#                             ¦Repeat the last #Find# or #Replace# operation.
 
 #Repeat (reverse search)#            ¦Repeat the last #Find# or #Replace# operation, in the opposite direction.
 
 #Find word under cursor#             ¦Find the word under cursor, case insensitive.
 
 #Find word under cursor (reverse)#   ¦Find the word under cursor, case insensitive, in the opposite direction.
 
 #Multi-Line Replace#                 ¦See ~Multi-Line Replace in Editor~@MReplace@

 #Toggle Highlight#                   ¦If the plugin highlighted parts of editor text then that highlighting will be turned on/off.


 ~Contents~@Contents@

@OperInEditor
$ #Operation in Editor#
^#Dialog settings# 
 #Search for#
 The search pattern. If "Reg. Expression" option is checked then it is
interpreted as a regular expression, otherwise as a literal string.

 #[ \ ]# and #[ / ]#
 Escape special characters in the search pattern or replace pattern.

 #[x] Case sensitive#
 Toggle case sensitivity.

 #[x] Reg. Expression#
 If checked, then the string to search is treated as a regular expression,
otherwise as a literal string.

 #Regexp. Library#
 Select a regular expression library that will perform the search.
 One library (~Far regex~@:RegExp@) is embedded in Far Manager and is always available.
 The other libraries (~Oniguruma~@Oniguruma@, ~PCRE~@PCRE@ and #PCRE2#)
 need the following files to be present (either on %PATH% or on %FARHOME%):

   Oniguruma  : onig.dll
        PCRE  : pcre.dll
        PCRE2 : pcre2.dll

 #[x] Whole words#
 Search for whole words.

 #[x] Ignore spaces#
 All literal whitespace in the search pattern is deleted before the search
begins. Escape the whitespace with #\# if it is an integral part of the
pattern.

 #Scope# (where the search is conducted):
   #(•) Global search# - the scope is the whole editor buffer.
   #( ) Selected text# - the scope is the selected region.

 #Origin# (where the search begins):
   #(•) From cursor# - search from cursor to the scope border.
   #( ) Whole scope# - search between the scope borders.
 
 #[x] Wrap around#
 Wrap search around the scope. #[?]# means: ask the user.

 #[x] Reverse search#
 Search in reverse direction (right to left, bottom to top).

 #[x] Highlight All#
 Highlight all matches in the entire editor.

 #Replace with#
 #[x] Function mode#
 See ~Syntax of Replace pattern~@SyntaxReplace@.

 #[x] Delete empty lines#
 If some editor line becomes empty as a result of replace operation,
it will be deleted.

 #[x] Delete non-matched lines#
 If no match is found in a line then that line will be deleted.

 #[x] Confirm replacement#
 Ask user before making a replacement.

 #[x] Advanced#
 Enable the advanced features: Line Filter, Initial Code and Final Code.
 
 #Line Filter#
 *  Line Filter allows to conduct search or replace on some lines
    while skipping the others.
 *  The filter string is treated as a Lua chunk.
    It is called  whenever a new line is about to be searched.
    If it returns true then the line is skipped.
 *  The function can use global variables and the following
    preset variables:
    #s#   -- Current search line (or part of it in a block search)
    #n#   -- Search line number (the search start line is 1)
    #rex# -- The regex library loaded.

 #Initial code#
 Lua code that executes before the search process begins:
   a) global variables and functions can be initialized here and used
      further by the #Line Filter# and #Replace# (when in function mode).
   b) a #dofile (filename)# call can be placed here, for the same
      purpose as in the above paragraph.

 #Final code#
 Lua code that executes after the search process ends. It can be used for
closing a file that was opened by the "Initial" code.

 #[ Presets ]#
 A menu for operation with ~presets~@Presets@ is shown.

 #[ Count ]#
 Do search and count all occurrences of the found text.

 #[ Show All ]#
 Do search and show the list with all lines containing the found text.
Each line in the list contains an editor line where the search succeeded.
See ~more details~@EditorShowAll@.

^#LIMITATIONS#
 The search is done on per-line basis. Thus, if matching text is spread
across multiple lines, it will not be found.

^#USER SCRIPTS#
 The utility can be extended by the ~User Scripts~@UserScripts@.

 ~Contents~@Contents@

@EditorShowAll
$ #"Show All" operation#
 Do search and show the list with all lines containing the found text.
Each line in the list contains an editor line where the search succeeded.

    #Enter#            Go to the selected line in the editor.
    #F6#               Show different parts of long lines.
    #F7#               Show the selected line in a message box.
    #F8#               Close the list and reopen the Search Dialog.
    #Ctrl-C#           Copy the selected line to the clipboard.
    #Ctrl-Up#, #Ctrl-Down#, #Ctrl-Home#, #Ctrl-End#
                     Scroll the editor not closing the list.
    #Ctrl-Num0#        Restore editor position after scrolling.

 ~Contents~@Contents@

@Configuration
$ #Configuration#
 #[x] Use Far history#
 Which history to use in "Search for" and "Replace with" fields.
Either Far history or this plugin's separate history can be used.
 
 #Log file name#
 Specify name of the log file, created by the ~Rename~@Rename@ utility.
The name can contain a date-time template #\D{...}# - see its description
in the ~Syntax of Replace pattern~@SyntaxReplace@ section.

 #[x] Process selected text if it exists#
 On invoking editor search or replace dialog, automatically set #Scope#
to #Selected text# if the editor contains selection.
  
 #[x] Select found text#
 Select found text in the editor.
 
 #[x] Show operation time#
 Show time taken by the operation
 
 #Pick search string from:#
 This setting determines how the #Search# field is initialized when the
Search or Replace dialog is opened. There are 3 options:
    #(•) Editor#        Word above cursor.
    #( ) History#       Search string taken from Far dialog history.
    #( ) Don't pick#    Search field is left empty.

 #Highlight Color#
 Select a highlight color for using with search option #Highlight All#.

 ~Contents~@Contents@

@Presets
$ #Presets#

 Pressing the #Presets# button from the Search or Replace dialog invokes a menu
for handling presets: create, load, rename and delete them.

 #Del#   - delete a preset
 #Enter# - load the selected preset into the dialog
 #Esc#   - close the menu and return to the dialog
 #F2#    - save the loaded preset under the same name
 #F6#    - rename a preset
 #Ins#   - save the current dialog settings as a new preset

 ~Contents~@Contents@

@UserScripts
$ #User Scripts#
 The plugin can execute Lua scripts added by the user. For details,
 see the chapter "User's utilities" of the plugin #LuaFAR for Editor#
 manual.

^#WHAT'S AVAILABLE TO USER SCRIPTS#

  #LIBRARIES:#
    *  The standard Lua libraries
    *  LuaFAR libraries
    *  #dialog#  (require "far2.dialog" , same as in LuaFAR for Editor)
    *  #history# (require "far2.history", same as in LuaFAR for Editor)
    *  #message# (require "far2.message", same as in LuaFAR for Editor)

  #FUNCTIONS:#
   ~lfsearch.EditorAction~@FuncEditorAction@
   ~lfsearch.MReplaceEditorAction~@FuncMReplaceEditorAction@
   ~lfsearch.SearchFromPanel~@FuncSearchFromPanel@
   ~lfsearch.ReplaceFromPanel~@FuncReplaceFromPanel@
   ~lfsearch.SetDebugMode~@FuncSetDebugMode@


 ~Contents~@Contents@

@FuncEditorAction
$ #lfsearch.EditorAction#
 #nFound, nReps = lfsearch.EditorAction (Operation, Data, SaveData)#

 #Operation# - one of predefined strings.
 The following operations correspond to the plugin menu items:

       "search"         :  search operation, with its dialog
       "replace"        :  replace operation, with its dialog
       "repeat"         :  repeat last operation
       "repeat_rev"     :  repeat last operation (reverse direction)
       "searchword"     :  search a word under cursor
       "searchword_rev" :  search a word under cursor (reverse)
       "config"         :  call Configuration Dialog

 The following operations do not display dialogs and the final message:

       "test:search"    :  search operation
       "test:count"     :  count matches in the text
       "test:showall"   :  show all matches
       "test:replace"   :  replace operation

 #Data# - a table with predefined fields. If a field is not present,
        its default value is used. The default value for booleans is
        `false'; for strings - an empty string. The value type can be
        deduced by from the 1-st letter of its name: b=boolean;
        f=function; n=number; s=string.

       "sSearchPat"      : search pattern
       "sReplacePat"     : replace pattern
       "sRegexLib"       : regular expression library, either of:
                           "far" (default), "oniguruma", "pcre" or "pcre2"
       "sScope"          : search scope: "global" (default) or
                           "block"
       "sOrigin"         : search origin: "cursor" (default) or
                           "scope"
       "bWrapAround"     : wrap search around the scope;
                           it is taken into account only if
                           sScope=="global" and sOrigin=="cursor"

       "bCaseSens"       : case sensitive search
       "bRegExpr"        : regular expression mode
       "bWholeWords"     : whole word search
       "bExtended"       : ignore whitespace in regexp
       "bSearchBack"     : search in reverse direction

       "bRepIsFunc"      : Function mode
       "bDelEmptyLine"   : delete empty line after replacement
       "bDelNonMatchLine": delete line with no matches found
       "bConfirmReplace" : call fUserChoiceFunc to confirm
                           replacement

       "bAdvanced"       : enable Line filter, Initial function
                           and Final function

       "sFilterFunc"     : Line filter function

       "sInitFunc"       : Initial function
       "sFinalFunc"      : Final function

       "fUserChoiceFunc" :
         A function called by the program when a match is found
         and a user decision is needed. The function is called only
         when bConfirmReplace is true.
         The parameters are (all are strings): sTitle, sFound, sReps.
         The valid return value is either of:
             "yes", "all", "no", "cancel".
         If the function is not supplied, the default user choice
         dialog is displayed.

 #SaveData# - put #Data# in the Search/Replace dialog histories.

 #nFound, nReps# - numbers of matches found and replacements made,
                 respectively.
 If the search or replace dialog is invoked and cancelled by the user
 then the function returns nil.

 ~Contents~@Contents@

@FuncMReplaceEditorAction
$ #lfsearch.MReplaceEditorAction#
 #nFound, nReps = lfsearch.MReplaceEditorAction (Operation, Data)#

 #Operation# - one of predefined strings.

       "replace"        :  replace operation
       "count"          :  count matches in the text

 #Data# - a table with predefined fields. If a field is not present,
        its default value is used. The default value for booleans is
        `false'; for strings - an empty string. The value type can be
        deduced by from the 1-st letter of its name: b=boolean;
        f=function; n=number; s=string.

       "sSearchPat"      : search pattern
       "sReplacePat"     : replace pattern
       "sRegexLib"       : regular expression library, either of:
                           "far" (default), "oniguruma", "pcre" or "pcre2"

       "bCaseSens"       : case sensitive search
       "bRegExpr"        : regular expression mode
       "bWholeWords"     : whole word search
       "bExtended"       : ignore whitespace in regexp

       "bFileAsLine"     : "." matches any character including "\n"
       "bMultiLine"      : "^" and "$" match respectively beginning
                           and end in every line

       "bRepIsFunc"      : Function mode

       "bAdvanced"       : enable Initial function and Final function
       "sInitFunc"       : Initial function
       "sFinalFunc"      : Final function

 #nFound, nReps# - numbers of matches found and replacements made,
                 respectively.

 ~Contents~@Contents@

@FuncSearchFromPanel
$ #lfsearch.SearchFromPanel
 #tFound = lfsearch.SearchFromPanel (Data, bWithDialog)#

 #Data# - a table with predefined fields. If a field is not present,
        its default value is used. The default value for booleans is
        `false'; for strings - an empty string. The value type can be
        deduced by from the 1-st letter of its name: b=boolean;
        f=function; n=number; s=string.

       "sFileMask"       : file mask
       "sSearchPat"      : search pattern
       "sRegexLib"       : regular expression library, either of:
                           "far" (default), "oniguruma", "pcre" or "pcre2"

       "bRegExpr"        : regular expression mode
       "bCaseSens"       : case sensitive search
       "bWholeWords"     : whole word search
       "bMultiPatterns"  : multiple patterns mode
       "bExtended"       : ignore whitespace in regexp
       "bFileAsLine"     : file as a line
       "bInverseSearch"  : inverse search       
       "bSearchFolders"  : search for folders
       "bSearchSymLinks" : search in symbolic links

       "sSearchArea"     : either of: "FromCurrFolder", "OnlyCurrFolder",
                           "SelectedItems", "RootFolder", "NonRemovDrives",
                           "LocalDrives", "PathFolders"

 #bWithDialog# - whether the dialog should be invoked. 
 
 #tFound# - a table (array) with names of the found files.

 
 ~Contents~@Contents@

@FuncReplaceFromPanel
$ #lfsearch.ReplaceFromPanel
 #lfsearch.ReplaceFromPanel (Data, bWithDialog)#

 #Data# - a table with predefined fields. If a field is not present,
        its default value is used. The default value for booleans is
        `false'; for strings - an empty string. The value type can be
        deduced by from the 1-st letter of its name: b=boolean;
        f=function; n=number; s=string.

       "sFileMask"       : file mask
       "sSearchPat"      : search pattern
       "sReplacePat"     : replace pattern
       "sRegexLib"       : regular expression library, either of:
                           "far" (default), "oniguruma", "pcre" or "pcre2"

       "bRepIsFunc"      : function mode
       "bMakeBackupCopy" : make backup copy
       "bConfirmReplace" : confirm replacement
       "bRegExpr"        : regular expression mode
       "bCaseSens"       : case sensitive search
       "bWholeWords"     : whole word search
       "bExtended"       : ignore whitespace in regexp
       "bSearchSymLinks" : search in symbolic links

       "sSearchArea"     : either of: "FromCurrFolder", "OnlyCurrFolder",
                           "SelectedItems", "RootFolder", "NonRemovDrives",
                           "LocalDrives", "PathFolders"

       "bAdvanced"       : Enable Initial function and Final function
       "sInitFunc"       : Initial function
       "sFinalFunc"      : Final function

 #bWithDialog# - whether the dialog should be invoked. 
 
 #returns:# nothing.

 
 ~Contents~@Contents@

@FuncSetDebugMode
$ #lfsearch.SetDebugMode#
^#lfsearch.SetDebugMode (On)#

 The function turns debug mode on or off.
 When debug mode is on:
 - The main plugin Lua file is reloaded prior to every #export.Open()#
   call.
 - Function #require# works without cache.


 ~Contents~@Contents@

@PanelMenu
$ #Plugin's menu in Panels#
^#Menu items#

 #Find#                         ¦Find text according to ~dialog~@OperInPanels@.
 
 #Replace#                      ¦Replace text according to ~dialog~@OperInPanels@.
 
 #Grep#                         ¦Find all text occurrences according to ~dialog~@PanelGrep@ and place results in a file.
 
 #Rename#                       ¦Rename files and directories according to ~dialog~@Rename@.

 #Panel#                        ¦Open the ~temporary panel~@TmpPanel@ of the plugin.


 ~Contents~@Contents@

@OperInPanels
$ #Search and Replace in Panels#
^#Dialog settings# 
 #File mask#
 The syntax is identical to Far-style ~file masks~@:FileMasks@.

 #* Search for#
 #* Replace with#
 #* Function mode#
 #* Confirm replacement#
 #* Case sensitive#
 #* Whole words#
 #* Regular Expression#
 #* Ignore spaces#
 #* Regexp library#
 #* Initial code#
 #* Final code#
 These settings are the same as in ~Operation in Editor~@OperInEditor@.

 #[x] Make backup copy# (only in "Replace" dialog)
 If a file was modified as a result of the replace operation,
 the backup of the original file is created.
 
 #[x] Multiple patterns# (only in "Find" dialog)
 Several patterns can be specified at once in the "Search for" field.
   #*# The patterns are separated with spaces.
   #*# If a pattern contains spaces or begins with either of
     #+#, #-# or #"# then it should be enclosed in double quotes,
     and any double quote that is part of the pattern should be
     doubled.
   #*# If a pattern MUST match in a file add a prefix #+# to it.
   #*# If a pattern MUST NOT match in a file add a prefix #-# to it.
   #*# From all the patterns having no prefix: at least one of them
     must match in a file.
   #*# Example:
       foo bar -foobar +"my school" -123 +456

 #[x] File as a line# (only in "Find" dialog)
 When this option is active, a dot ("#.#") in the search pattern
 matches line feeds and carriage returns as any other characters.

 #[x] Inverse search# (only in "Find" dialog)
 If a text search pattern is specified then only files containing
 no matches will be listed.

 #Encodings# (only in "Find" dialog)
 Choose the code page or pages for searching in the text.
 There are 3 possibilities:

   #*# Some code page from the list is selected: the search is performed using
only that code page.
 
   #*# "Default code pages" is selected.
The search is performed using the predefined set of code pages:
{ OEM, ANSI, 1200, 1201, 65000, 65001 }.

   #*# "Checked code pages" is selected and some code pages are checked
in the list. The search is performed using the checked code pages.
(A page can be checked in the list by pressing Space or Ins).
 
 #Search area#
 Choose where to look for files and directories:
   #*# From the current folder
   #*# The current folder only
   #*# Selected files and folders
   #*# From the root of current disk
   #*# In all non-removable drives
   #*# In all local drives
   #*# In PATH folders

 #[x] Directory filter#  #[ Tune ]#
 Enable use of directory filter. 
 Show ~Directory filter dialog~@DirectoryFilter@.

 #[x] File filter#       #[ Tune ]#
 Enable use of file filter.
 Show ~Filters Menu~@:FiltersMenu@.

 #[x] Search for folders# (only in "Find" dialog)
 Specify whether folders should be found or not.

 #[x] Search in symbolic links#
 Specify whether to search in symbolic links or not.

 #[ Configuration ]# (only in "Find" dialog)
 Envoke ~configuration dialog~@SearchResultsPanel@ for search results panel.

 ~Contents~@Contents@

@SearchResultsPanel
$ #Search results panel#
 The plugin uses an embedded temporary panel for displaying its search results.
The settings of the temporary panel can be tuned in the configuration dialog.

^#Dialog settings# 
 #Column types#
 #Column widths#
 #Status line column types#
 #Status line column widths#
 #Full screen mode#
 Read about these settings in the help file of standard TmpPanel plugin.

 #Sort mode and order#
 Specify the sort mode (0...15; 0=default sort mode) then comma then the sort
order (0=direct order, 1=inverse order).

 #Preserve contents#
 Remember the panel contents on closing the panel. When it is opened later
its contents is restored.

 ~Contents~@Contents@

@Oniguruma
$ #Oniguruma Regular Expressions Version 5.9.1    2007/09/05#

syntax: ONIG_SYNTAX_RUBY (default)


#1. Syntax elements#

  \       escape (enable or disable meta character meaning)
  |       alternation
  (...)   group
  [...]   character class


#2. Characters#

  \t           horizontal tab (0x09)
  \v           vertical tab   (0x0B)
  \n           newline        (0x0A)
  \r           return         (0x0D)
  \b           back space     (0x08)
  \f           form feed      (0x0C)
  \a           bell           (0x07)
  \e           escape         (0x1B)
  \nnn         octal char            (encoded byte value)
  \xHH         hexadecimal char      (encoded byte value)
  \x{7HHHHHHH} wide hexadecimal char (character code point value)
  \cx          control char          (character code point value)
  \C-x         control char          (character code point value)
  \M-x         meta  (x|0x80)        (character code point value)
  \M-\C-x      meta control char     (character code point value)

 (* \b is effective in character class [...] only)


#3. Character types#

  .        any character (except newline)

  \w       word character

           Not Unicode:
             alphanumeric, "_" and multibyte char.

           Unicode:
             General_Category -- (Letter|Mark|Number|Connector_Punctuation)

  \W       non word char

  \s       whitespace char

           Not Unicode:
             \t, \n, \v, \f, \r, \x20

           Unicode:
             0009, 000A, 000B, 000C, 000D, 0085(NEL),
             General_Category -- Line_Separator
                              -- Paragraph_Separator
                              -- Space_Separator

  \S       non whitespace char

  \d       decimal digit char

           Unicode: General_Category -- Decimal_Number

  \D       non decimal digit char

  \h       hexadecimal digit char   [0-9a-fA-F]

  \H       non hexadecimal digit char


  Character Property

    * \p{property-name}
    * \p{^property-name}    (negative)
    * \P{property-name}     (negative)

    property-name:

     + works on all encodings
       Alnum, Alpha, Blank, Cntrl, Digit, Graph, Lower,
       Print, Punct, Space, Upper, XDigit, Word, ASCII,

     + works on EUC_JP, Shift_JIS
       Hiragana, Katakana

     + works on UTF8, UTF16, UTF32
       Any, Assigned, C, Cc, Cf, Cn, Co, Cs, L, Ll, Lm, Lo, Lt, Lu,
       M, Mc, Me, Mn, N, Nd, Nl, No, P, Pc, Pd, Pe, Pf, Pi, Po, Ps,
       S, Sc, Sk, Sm, So, Z, Zl, Zp, Zs,
       Arabic, Armenian, Bengali, Bopomofo, Braille, Buginese, Buhid,
       Canadian_Aboriginal, Cherokee, Common, Coptic, Cypriot,
       Cyrillic, Deseret, Devanagari, Ethiopic, Georgian, Glagolitic,
       Gothic, Greek, Gujarati, Gurmukhi, Han, Hangul, Hanunoo,
       Hebrew, Hiragana, Inherited, Kannada, Katakana, Kharoshthi,
       Khmer, Lao, Latin, Limbu, Linear_B, Malayalam, Mongolian,
       Myanmar, New_Tai_Lue, Ogham, Old_Italic, Old_Persian, Oriya,
       Osmanya, Runic, Shavian, Sinhala, Syloti_Nagri, Syriac,
       Tagalog, Tagbanwa, Tai_Le, Tamil, Telugu, Thaana, Thai,
       Tibetan, Tifinagh, Ugaritic, Yi



#4. Quantifier#

  greedy

    ?       1 or 0 times
    *       0 or more times
    +       1 or more times
    {n,m}   at least n but not more than m times
    {n,}    at least n times
    {,n}    at least 0 but not more than n times ({0,n})
    {n}     n times

  reluctant

    ??      1 or 0 times
    *?      0 or more times
    +?      1 or more times
    {n,m}?  at least n but not more than m times
    {n,}?   at least n times
    {,n}?   at least 0 but not more than n times (== {0,n}?)

  possessive (greedy and does not backtrack after repeated)

    ?+      1 or 0 times
    *+      0 or more times
    ++      1 or more times

    ({n,m}+, {n,}+, {n}+ are possessive op. in ONIG_SYNTAX_JAVA only)

    ex. /a*+/ === /(?>a*)/


#5. Anchors#

  ^       beginning of the line
  $       end of the line
  \b      word boundary
  \B      not word boundary
  \A      beginning of string
  \Z      end of string, or before newline at the end
  \z      end of string
  \G      matching start position


#6. Character class#

  ^...    negative class (lowest precedence operator)
  x-y     range from x to y
  [...]   set (character class in character class)
  ..&&..  intersection (low precedence at the next of ^)

    ex. [a-w&&[^c-g]z] ==> ([a-w] AND ([^c-g] OR z)) ==> [abh-w]

  * If you want to use '[', '-', ']' as a normal character
    in a character class, you should escape these characters by '\'.


  POSIX bracket ([:xxxxx:], negate [:^xxxxx:])

    Not Unicode Case:

      alnum    alphabet or digit char
      alpha    alphabet
      ascii    code value: [0 - 127]
      blank    \t, \x20
      cntrl
      digit    0-9
      graph    include all of multibyte encoded characters
      lower
      print    include all of multibyte encoded characters
      punct
      space    \t, \n, \v, \f, \r, \x20
      upper
      xdigit   0-9, a-f, A-F
      word     alphanumeric, "_" and multibyte characters


    Unicode Case:

      alnum    Letter | Mark | Decimal_Number
      alpha    Letter | Mark
      ascii    0000 - 007F
      blank    Space_Separator | 0009
      cntrl    Control | Format | Unassigned | Private_Use |
               Surrogate
      digit    Decimal_Number
      graph    [[:^space:]] && ^Control && ^Unassigned && ^Surrogate
      lower    Lowercase_Letter
      print    [[:graph:]] | [[:space:]]
      punct    Connector_Punctuation | Dash_Punctuation |
               Close_Punctuation | Final_Punctuation |
               Initial_Punctuation | Other_Punctuation |
               Open_Punctuation
      space    Space_Separator | Line_Separator | Paragraph_Separator
               | 0009 | 000A | 000B | 000C | 000D | 0085
      upper    Uppercase_Letter
      xdigit   0030 - 0039 | 0041 - 0046 | 0061 - 0066
               (0-9, a-f, A-F)
      word     Letter | Mark | Decimal_Number | Connector_Punctuation



#7. Extended groups#

  (?##...)            comment

  (?imx-imx)         option on/off
                         i: ignore case
                         m: multi-line (dot(.) match newline)
                         x: extended form
  (?imx-imx:subexp)  option on/off for subexp

  (?:subexp)         not captured group
  (subexp)           captured group

  (?=subexp)         look-ahead
  (?!subexp)         negative look-ahead
  (?<=subexp)        look-behind
  (?<!subexp)        negative look-behind

                     Subexp of look-behind must be fixed character
                     length. But different character length is
                     allowed in top level alternatives only.
                     ex. (?<=a|bc) is OK. (?<=aaa(?:b|cd)) is not
                     allowed.

                     In negative-look-behind, captured group isn't
                     allowed, but shy group(?:) is allowed.

  (?>subexp)         atomic group
                     don't backtrack in subexp.

  (?<name>subexp), (?'name'subexp)
                     define named group
                     (All characters of the name must be a word
                     character.)

                     Not only a name but a number is assigned like a
                     captured group.

                     Assigning the same name as two or more subexps
                     is allowed. In this case, a subexp call can not
                     be performed although the back reference is
                     possible.


#8. Back reference#

  \n          back reference by group number (n >= 1)
  \k<n>       back reference by group number (n >= 1)
  \k'n'       back reference by group number (n >= 1)
  \k<-n>      back reference by relative group number (n >= 1)
  \k'-n'      back reference by relative group number (n >= 1)
  \k<name>    back reference by group name
  \k'name'    back reference by group name

  In the back reference by the multiplex definition name,
  a subexp with a large number is referred to preferentially.
  (When not matched, a group of the small number is referred to.)

  * Back reference by group number is forbidden if named group is
    defined in the pattern and ONIG_OPTION_CAPTURE_GROUP is not
    setted.


  back reference with nest level

    level: 0, 1, 2, ...

    \k<n+level>     (n >= 1)
    \k<n-level>     (n >= 1)
    \k'n+level'     (n >= 1)
    \k'n-level'     (n >= 1)

    \k<name+level>
    \k<name-level>
    \k'name+level'
    \k'name-level'

    Destinate relative nest level from back reference position.

    ex 1.

      /\A(?<a>|.|(?:(?<b>.)\g<a>\k<b+0>))\z/.match("reer")

    ex 2.

      r = Regexp.compile(<<'__REGEXP__'.strip, Regexp::EXTENDED)
      (?<element> \g<stag> \g<content>* \g<etag> ){0}
      (?<stag> < \g<name> \s* > ){0}
      (?<name> [a-zA-Z_:]+ ){0}
      (?<content> [^<&]+ (\g<element> | [^<&]+)* ){0}
      (?<etag> </ \k<name+1> >){0}
      \g<element>
      __REGEXP__

      p r.match('<foo>f<bar>bbb</bar>f</foo>').captures



#9. Subexp call ("Tanaka Akira special")#

  \g<name>    call by group name
  \g'name'    call by group name
  \g<n>       call by group number (n >= 1)
  \g'n'       call by group number (n >= 1)
  \g<-n>      call by relative group number (n >= 1)
  \g'-n'      call by relative group number (n >= 1)

  * left-most recursive call is not allowed.
     ex. (?<name>a|\g<name>b)   => error
         (?<name>a|b\g<name>c)  => OK

  * Call by group number is forbidden if named group is defined in the pattern
    and ONIG_OPTION_CAPTURE_GROUP is not setted.

  * If the option status of called group is different from calling position
    then the group's option is effective.

    ex. (?-i:\g<name>)(?i:(?<name>a)){0}  match to "A"


#10. Captured group#

  Behavior of the no-named group (...) changes with the following conditions.
  (But named group is not changed.)

  case 1. /.../     (named group is not used, no option)

     (...) is treated as a captured group.

  case 2. /.../g    (named group is not used, 'g' option)

     (...) is treated as a no-captured group (?:...).

  case 3. /..(?<name>..)../   (named group is used, no option)

     (...) is treated as a no-captured group (?:...).
     numbered-backref/call is not allowed.

  case 4. /..(?<name>..)../G  (named group is used, 'G' option)

     (...) is treated as a captured group.
     numbered-backref/call is allowed.

  where
    g: ONIG_OPTION_DONT_CAPTURE_GROUP
    G: ONIG_OPTION_CAPTURE_GROUP

  ('g' and 'G' options are argued in ruby-dev ML)

 ~Contents~@Contents@

@PCRE
$ #PCRE REGULAR EXPRESSION SYNTAX SUMMARY#

 The full syntax and semantics of the regular expressions that are
supported by PCRE are described in the pcrepattern documentation.
This document contains just a quick-reference summary of the syntax.

#QUOTING#

  \x         where x is non-alphanumeric is a literal x
  \Q...\E    treat enclosed characters as literal


#CHARACTERS#

  \a         alarm, that is, the BEL character (hex 07)
  \cx        "control-x", where x is any character
  \e         escape (hex 1B)
  \f         formfeed (hex 0C)
  \n         newline (hex 0A)
  \r         carriage return (hex 0D)
  \t         tab (hex 09)
  \ddd       character with octal code ddd, or backreference
  \xhh       character with hex code hh
  \x{hhh..}  character with hex code hhh..


#CHARACTER TYPES#

  .          any character except newline;
               in dotall mode, any character whatsoever
  \C         one byte, even in UTF-8 mode (best avoided)
  \d         a decimal digit
  \D         a character that is not a decimal digit
  \h         a horizontal whitespace character
  \H         a character that is not a horizontal whitespace
             character
  \N         a character that is not a newline
  \p{xx}     a character with the xx property
  \P{xx}     a character without the xx property
  \R         a newline sequence
  \s         a whitespace character
  \S         a character that is not a whitespace character
  \v         a vertical whitespace character
  \V         a character that is not a vertical whitespace character
  \w         a "word" character
  \W         a "non-word" character
  \X         an extended Unicode sequence

 In PCRE, by default, \d, \D, \s, \S, \w, and \W recognize only ASCII
characters, even in UTF-8 mode. However, this can be changed by
setting the PCRE_UCP option.


#GENERAL CATEGORY PROPERTIES FOR \p and \P#

  C          Other
  Cc         Control
  Cf         Format
  Cn         Unassigned
  Co         Private use
  Cs         Surrogate

  L          Letter
  Ll         Lower case letter
  Lm         Modifier letter
  Lo         Other letter
  Lt         Title case letter
  Lu         Upper case letter
  L&         Ll, Lu, or Lt

  M          Mark
  Mc         Spacing mark
  Me         Enclosing mark
  Mn         Non-spacing mark

  N          Number
  Nd         Decimal number
  Nl         Letter number
  No         Other number

  P          Punctuation
  Pc         Connector punctuation
  Pd         Dash punctuation
  Pe         Close punctuation
  Pf         Final punctuation
  Pi         Initial punctuation
  Po         Other punctuation
  Ps         Open punctuation

  S          Symbol
  Sc         Currency symbol
  Sk         Modifier symbol
  Sm         Mathematical symbol
  So         Other symbol

  Z          Separator
  Zl         Line separator
  Zp         Paragraph separator
  Zs         Space separator


#PCRE SPECIAL CATEGORY PROPERTIES FOR \p and \P#

  Xan        Alphanumeric: union of properties L and N
  Xps        POSIX space: property Z or tab, NL, VT, FF, CR
  Xsp        Perl space: property Z or tab, NL, FF, CR
  Xwd        Perl word: property Xan or underscore


#SCRIPT NAMES FOR \p AND \P#

 Arabic, Armenian, Avestan, Balinese, Bamum, Bengali, Bopomofo,
Braille, Buginese, Buhid, Canadian_Aboriginal, Carian, Cham,
Cherokee, Common, Coptic, Cuneiform, Cypriot, Cyrillic, Deseret,
Devanagari, Egyptian_Hieroglyphs, Ethiopic, Georgian, Glagolitic,
Gothic, Greek, Gujarati, Gurmukhi, Han, Hangul, Hanunoo, Hebrew,
Hiragana, Imperial_Aramaic, Inherited, Inscriptional_Pahlavi,
Inscriptional_Parthian, Javanese, Kaithi, Kannada, Katakana,
Kayah_Li, Kharoshthi, Khmer, Lao, Latin, Lepcha, Limbu, Linear_B,
Lisu, Lycian, Lydian, Malayalam, Meetei_Mayek, Mongolian, Myanmar,
New_Tai_Lue, Nko, Ogham, Old_Italic, Old_Persian, Old_South_Arabian,
Old_Turkic, Ol_Chiki, Oriya, Osmanya, Phags_Pa, Phoenician, Rejang,
Runic, Samaritan, Saurashtra, Shavian, Sinhala, Sundanese,
Syloti_Nagri, Syriac, Tagalog, Tagbanwa, Tai_Le, Tai_Tham, Tai_Viet,
Tamil, Telugu, Thaana, Thai, Tibetan, Tifinagh, Ugaritic, Vai, Yi.

#CHARACTER CLASSES#

  [...]       positive character class
  [^...]      negative character class
  [x-y]       range (can be used for hex characters)
  [[:xxx:]]   positive POSIX named set
  [[:^xxx:]]  negative POSIX named set

  alnum       alphanumeric
  alpha       alphabetic
  ascii       0-127
  blank       space or tab
  cntrl       control character
  digit       decimal digit
  graph       printing, excluding space
  lower       lower case letter
  print       printing, including space
  punct       printing, excluding alphanumeric
  space       whitespace
  upper       upper case letter
  word        same as \w
  xdigit      hexadecimal digit

 In PCRE, POSIX character set names recognize only ASCII characters
by default, but some of them use Unicode properties if PCRE_UCP is
set. You can use \Q...\E inside a character class.


#QUANTIFIERS#

  ?           0 or 1, greedy
  ?+          0 or 1, possessive
  ??          0 or 1, lazy
  *           0 or more, greedy
  *+          0 or more, possessive
  *?          0 or more, lazy
  +           1 or more, greedy
  ++          1 or more, possessive
  +?          1 or more, lazy
  {n}         exactly n
  {n,m}       at least n, no more than m, greedy
  {n,m}+      at least n, no more than m, possessive
  {n,m}?      at least n, no more than m, lazy
  {n,}        n or more, greedy
  {n,}+       n or more, possessive
  {n,}?       n or more, lazy


#ANCHORS AND SIMPLE ASSERTIONS#

  \b          word boundary
  \B          not a word boundary
  ^           start of subject
               also after internal newline in multiline mode
  \A          start of subject
  $           end of subject
               also before newline at end of subject
               also before internal newline in multiline mode
  \Z          end of subject
               also before newline at end of subject
  \z          end of subject
  \G          first matching position in subject


#MATCH POINT RESET#

  \K          reset start of match


#ALTERNATION#

  expr|expr|expr...


#CAPTURING#

  (...)           capturing group
  (?<name>...)    named capturing group (Perl)
  (?'name'...)    named capturing group (Perl)
  (?P<name>...)   named capturing group (Python)
  (?:...)         non-capturing group
  (?|...)         non-capturing group; reset group numbers for
                   capturing groups in each alternative


#ATOMIC GROUPS#

  (?>...)         atomic, non-capturing group


#COMMENT#

  (?##....)        comment (not nestable)


#OPTION SETTING#

  (?i)            caseless
  (?J)            allow duplicate names
  (?m)            multiline
  (?s)            single line (dotall)
  (?U)            default ungreedy (lazy)
  (?x)            extended (ignore white space)
  (?-...)         unset option(s)

 The following are recognized only at the start of a pattern or after
one of the newline-setting options with similar syntax:

  (*UTF8)         set UTF-8 mode (PCRE_UTF8)
  (*UCP)          set PCRE_UCP (use Unicode properties for \d etc)


#LOOKAHEAD AND LOOKBEHIND ASSERTIONS#

  (?=...)         positive look ahead
  (?!...)         negative look ahead
  (?<=...)        positive look behind
  (?<!...)        negative look behind

 Each top-level branch of a look behind must be of a fixed length.


#BACKREFERENCES#

  \n              reference by number (can be ambiguous)
  \gn             reference by number
  \g{n}           reference by number
  \g{-n}          relative reference by number
  \k<name>        reference by name (Perl)
  \k'name'        reference by name (Perl)
  \g{name}        reference by name (Perl)
  \k{name}        reference by name (.NET)
  (?P=name)       reference by name (Python)


#SUBROUTINE REFERENCES (POSSIBLY RECURSIVE)#

  (?R)            recurse whole pattern
  (?n)            call subpattern by absolute number
  (?+n)           call subpattern by relative number
  (?-n)           call subpattern by relative number
  (?&name)        call subpattern by name (Perl)
  (?P>name)       call subpattern by name (Python)
  \g<name>        call subpattern by name (Oniguruma)
  \g'name'        call subpattern by name (Oniguruma)
  \g<n>           call subpattern by absolute number (Oniguruma)
  \g'n'           call subpattern by absolute number (Oniguruma)
  \g<+n>          call subpattern by relative number (PCRE extension)
  \g'+n'          call subpattern by relative number (PCRE extension)
  \g<-n>          call subpattern by relative number (PCRE extension)
  \g'-n'          call subpattern by relative number (PCRE extension)


#CONDITIONAL PATTERNS#

  (?(condition)yes-pattern)
  (?(condition)yes-pattern|no-pattern)

  (?(n)...        absolute reference condition
  (?(+n)...       relative reference condition
  (?(-n)...       relative reference condition
  (?(<name>)...   named reference condition (Perl)
  (?('name')...   named reference condition (Perl)
  (?(name)...     named reference condition (PCRE)
  (?(R)...        overall recursion condition
  (?(Rn)...       specific group recursion condition
  (?(R&name)...   specific recursion condition
  (?(DEFINE)...   define subpattern for reference
  (?(assert)...   assertion condition


#BACKTRACKING CONTROL#

The following act immediately they are reached:

  (*ACCEPT)       force successful match
  (*FAIL)         force backtrack; synonym (*F)

 The following act only when a subsequent match failure causes a
backtrack to reach them. They all force a match failure, but they
differ in what happens afterwards. Those that advance the
start-of-match point do so only if the pattern is not anchored.

  (*COMMIT)       overall failure, no advance of starting point
  (*PRUNE)        advance to next starting character
  (*SKIP)         advance start to current matching position
  (*THEN)         local failure, backtrack to next alternation


#NEWLINE CONVENTIONS#

 These are recognized only at the very start of the pattern or after
a (*BSR_...) or (*UTF8) or (*UCP) option.

  (*CR)           carriage return only
  (*LF)           linefeed only
  (*CRLF)         carriage return followed by linefeed
  (*ANYCRLF)      all three of the above
  (*ANY)          any Unicode newline sequence


#WHAT \R MATCHES#

 These are recognized only at the very start of the pattern or after
a (*...) option that sets the newline convention or UTF-8 or UCP
mode.

  (*BSR_ANYCRLF)  CR, LF, or CRLF
  (*BSR_UNICODE)  any Unicode newline sequence


#CALLOUTS#

  (?C)      callout
  (?Cn)     callout with data n


#SEE ALSO#

 pcrepattern(3), pcreapi(3), pcrecallout(3), pcrematching(3),
pcre(3).

#AUTHOR#

 Philip Hazel
 University Computing Service
 Cambridge CB2 3QH, England.

#REVISION#

 Last updated: 12 May 2010
 Copyright c 1997-2010 University of Cambridge.

 ~Contents~@Contents@

@SyntaxReplace
$ #Syntax of Replace pattern#
 If Regular Expression option is checked then:
    *  #$1#-#$9# and #$A#-#$Z# are used for specifying submatches (groups).
       #$0# stands for the whole match.
    *  #${name}# is used for specifying named groups
       (supported only with Oniguruma and PCRE libraries).
    *  Literal dollar signs (#$#) and backslashes (#\#) must be escaped
       with #\#
    *  Other punctuation marks may or may not be escaped with #\#

    *  The following escape sequences can be used as they are easier
       to put into a dialog field than their character equivalents:
       #\a#        alarm (hex 07)
       #\e#        escape (hex 1B)
       #\f#        formfeed (hex 0C)
       #\n#        linefeed (hex 0A)
       #\r#        carriage return (hex 0D)
       #\t#        tab (hex 09)
       #\xhhhh#    character with hex code #hhhh#

    *  The following escape sequences control text case:
       #\L#        turn the following text into lower case
       #\U#        turn the following text into upper case
       #\E#        end the scope of the last \L or \U
       #\l#        turn the next character into lower case
       #\u#        turn the next character into upper case

       \L and \U elements can be nested. Their scope extends till
       a matching \E (or till the end of the replace pattern).

    *  The following escape sequences insert numbering:
       #\R#           insert count: current number of replacements
       #\R{#offset#}#   as above, but incremented by specified offset,
                    e.g. \R{20} or \R{-10}
       #\R{#offset#,#width#}# as above, but inserted with the specified
                    width (zeros are added at the beginning),
                    e.g. \R{20,4} or \R{-10,4}

    *  The following sequence inserts current date and/or time:
       #\D{#format#}#   Format should correspond to the syntax
                    of argument of Lua-function os.date,
                    e.g. \D{%Y-%m-%d}

    *  The following works only in ~Rename~@Rename@ utility.
       #\N#           File name, without extension
       #\X#           File extension (the dot not included)
 
 If the Function mode option is selected, then the text in this field is
treated as the body of a Lua function (see below).

 #[x] Function mode#
 *  The replace pattern is treated as the #body# of a Lua function
    (so the keyword 'function', parameter list and the keyword 'end'
    must be omitted). The function is called whenever a match occurs.

 *  The function can use the following preset variables:
       #T#   - a table containing captured submatches
          #T[0]#          - whole match
          #T[1], ...#     - numbered submatches
          #T[name1], ...# - named submatches
       #M#   - number of the current match (1-based)
       #R#   - number of the current replacement (1-based)
       #LN#  - line number in editor or file (1-based)
       #rex# - regex library loaded
 
 *  The function can set and modify global variables and use them
    during its current and future invocations (within the current
    search).
 
 *  Let's assume the function returned two values: #ret1# and #ret2#.
    These values are processed as follows:
    
    In all utilities:    
    *  #type(ret1)=="string" or type(ret1)=="number"# :
       ret1 is used as the substituting text.
    *  #ret1==nil or ret1==false#  : no replacement is done.
    *  undocumented type of #ret1# : no replacement is done.
    
    In per-line replacing utilities from editor and panels:
    *  #ret1==true#: the line along with end-of-line is deleted.
         - not relevant for "multi-line replace" and "rename"
           utilities.
         - when replacing from panels, deleted is only that part of
           the line that was yet not placed into the output file.
    
    In replacing utilities from editor and panels:
    *  #ret2==true#: immediate termination of the current search and
                   replace operation.
         - only in automatic mode (with no user's confirmation).
         - not relevant for "rename" utility.

 ~Contents~@Contents@

@MReplace
$ #Multi-Line Replace in Editor#
 The utility searches and replaces inside several lines of text in the editor.
Those lines should be selected before the operation begins. The kind of
selection (stream or vertical) does not matter, if even one position in a line
is selected, the whole line participates in the operation.

 If there is no selection, the operation is performed on the whole editor
contents.

 In the search stage, lines of text are concatenated with \n between them,
no matter what the real line break sequences are. In the replace stage,
the default line break sequences are inserted.

 All replacements take place at once with no prompt for the user. In the
similar way they all can be cancelled at once by pressing Ctrl-Z.

^#Dialog settings# 
 #Search for#
 The search pattern.

 #Replace with#
 See ~Syntax of Replace pattern~@SyntaxReplace@.

 #[x] Regular Expression#
 If checked, then the string to search is treated as a
~regular expression~@:RegExp@, otherwise as a literal string.

 #[x] Case sensitive#
 Toggles case sensitivity.

 #[x] Whole words#
 Search for whole words.

 #[x] Ignore spaces#
 All literal whitespace in the search pattern is deleted before the search
begins. Escape the whitespace with #\# if it is an integral part of the
pattern.

 #[x] File as a line#
 If checked then #.# (dot) in regular expressions matches any character,
including \r and \n.
 
 #[x] Multiline mode#
 If checked then #^# and #$# in regular expressions match correspondingly
beginnings and ends of every line.

 ~Contents~@Contents@

@Rename
$ #Rename#
 The utility is intended for renaming files and directories. It works from
panels.

 Call the utility from the plugin's menu. The "LF Rename" dialog will be
displayed.

 #File mask:#
 Only files and directories matching the given mask will be renamed.
The syntax is identical to Far-style ~file masks~@:FileMasks@.
 File mask has nothing to do with the search scope, e.g. the name of a
directory to be recursively searched does not have to match the mask.

 #(•) Search in all#
 Items for renaming and directories for recursion are searched among
all items of the active panel.
 
 #( ) Search in selected#
 Items for renaming and directories for recursion are searched only among
selected items of the active panel. If there are no selected items then
the item under panel cursor is processed.

 #[x] Rename files#
 #[x] Rename folders#
 Either one or both attributes can be specified.

 #[x] Process subfolders#
 If the search scope contains directories, do search under those directories
and their subdirectories as well.

 #Search for:#
 This field should contain a ~Far regex~@:RegExp@ pattern that will be
matched against every selected file or directory name. The matching is case
insensitive.

 #Replace with:#
 See ~Syntax of Replace pattern~@SyntaxReplace@.

 #[x] Function mode#
 Same mode as such in replace in editor.

 #[x] Log file#
 A log file will be created. The file is created in the form
of a Lua-script that when being run renames files and directories to their
previous names, i.e. it reverts the renaming done by the plugin.
 In order to do that, run either
      #lfs: -r<logfile>#
 or (equivalently)
      #lua: @@<logfile>#

 ~Contents~@Contents@

@PanelGrep
$ #Grep#
 Perform a search in accordance to specified parameters and then output results to a file.
The file is automatically opened in the editor after the search is finished.

 Most dialog elements have the same functions as in ~search and replace~@OperInPanels@ dialogs.

 The dialog elements listed below are specific for this dialog:

 #Skip#
 This is a pattern that specifies what text to skip during the operation.
 This feature is turned off when the field is empty.
     For example:
 We want to find the word #new# in the C++ code but not in comments like this: #//...new...#.
 To achieve that we specify pattern #\bnew\b# as the search pattern
and pattern #\/\/.*# as the skip pattern.
 
 #[x] Show line numbers#
 Each output line contains line number it has in the searched file.

 #[x] Highlight matches#
 Line numbers and found matches are colored. The colors can be selected in the configuration dialog.

 #[x] Inverse search#
 Find lines that does not contain the given search pattern.

 #Context Lines Before#
 Output the specified number of lines in the searched file preceding a matched line.

 #Context Lines After#
 Output the specified number of lines in the searched file following a matched line.

 ~Contents~@Contents@

@TmpPanel
$ #Panel#
 Open a panel similar to that of standard TmpPanel plugin.

 ~Contents~@Contents@

@DirectoryFilter
$ #Directory filter#
^#Dialog settings# 

 #Directory search mask#
 The search of files for inclusion in the list and processing will be done
only within those directories whose names match the given mask.
 (If this field is left empty then the search will be done in all directories).

   #[x] Process path#
   If this option is set then the given mask will be matched against
   the full directory path otherwise against the directory name only.

 #Directory exclude mask#
 If a directory matches the given mask then the directory contents (files
and subdirectories of any nesting depth) will not be included in the list
and will not be processed.
 (If the given field is left empty then directories will not be excluded).

   #[x] Process path#
   If this option is set then the given mask will be matched against
   the full directory path otherwise against the directory name only.

 The syntax of masks is identical to Far-style ~file masks~@:FileMasks@.

 ~Contents~@Contents@
