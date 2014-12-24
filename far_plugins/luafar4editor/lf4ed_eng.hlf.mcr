.Language=English,English
.PluginContents=LuaFAR for Editor
.Options CtrlColorChar=\

@Contents
$ #LuaFAR for Editor (version #{VER_STRING}) - Help Contents -#
 LuaFAR for Editor is a collection of utilities that implement various
actions controlling the work of FAR's Editor. The utilities are written in Lua
programming language.

 The following utilities are included:
     ~Sort Lines~@SortLines@
     ~Reformat Block~@Wrap@
     ~Block Sum~@BlockSum@
     ~Lua Expression~@LuaExpression@
     ~Lua Script~@LuaScript@
     ~Script Parameters dialog~@ScriptParams@
 More utilities can be added by the user: see the manual.

 Technical topics:
     ~Plugin's Configuration Dialog~@PluginConfig@
     ~Reload User File~@ReloadUserFile@

@LuaExpression
$ #Lua Expression#
 #Features:#
   *  Calculates Lua expressions.
   *  Works either on the selected text, or on the current line
      if no text is selected.
   *  Any valid Lua expression, including function calls.
   *  The expression result can be:
          - edited in a message box
          - inserted into the editor
          - copied to the clipboard
   *  All functions from the Lua #math# library are available as
      globals, e.g. 'sqrt' can be used instead of 'math.sqrt'.

 #Example:#
   If the expression on the following 2 lines is:
           (75 - 10) / 13 + 2^5 + sqrt(100)
           + log10(100)
   the result of the operation should be 49.

 ~Contents~@Contents@

@LuaScript
$ #Lua Script#
   This command runs a Lua script from a Far Editor window.

   1. If the "External script" option in the ~script parameters~@ScriptParams@
      dialog is checked then the script is the file specified
      therein.
   2. Else, the script is the text selected in the current Far Editor
      window.
   3. If no text is selected, the script is the whole current editor
      window contents.

   The script can be run with ~parameters~@ScriptParams@, regardless of what
is the script source.

 ~Contents~@Contents@

@ScriptParams
$ #Script Parameters dialog#
   The #External script# option lets specify the file (Lua script) that will
be run. If the file name does not contain absolute path, it considered to be
relative to the directory containing the edited file. If this option is not
checked then either selected or entire editor window text will serve as the
script, as described in the ~Lua Script~@LuaScript@ section.   
   
   The dialog allows to specify up to 4 parameters that will be stored and
passed to ~Lua Script~@LuaScript@ when it is invoked. Every parameter is a Lua
expression. This means in particular that strings must be enclosed in quotes,
as it's usual in Lua. An empty parameter line is equivalent to nil.

   The parameters are syntax-checked but their evaluation is delayed until
the script is actually invoked. Therefore, e.g. expression 47+ would
immediately raise an error, while expression 47+nil would be accepted but
would raise an error when the script is invoked.

   Parameters are evaluated and passed to the script only if
#Pass parameters to the script# checkbox is checked.

   The #Run# command stores the parameters and runs the script.
 
   The #Store# command stores the parameters for future script invocations.

 ~Contents~@Contents@

@BlockSum
$ #Block Sum#
 Calculates sum of numbers on several lines (one number per line).

   *  Works either on the selected block of text or the current line.

   *  For each line (or selected part of it), takes the first non-
      space character sequence and converts it to a number. The
      number can be followed by a non-word character. If some line
      cannot be meaningfully converted, it's value is considered to
      be 0.

   *  The result of the calculation can be:
          - inserted into the editor
          - copied to the clipboard

 #Example#

 Let's assume we have the following text in the editor:

        25.30  expense Jan 1
       156.75  expense Jan 2
         5.00  expense Jan 3
        71.30  expense Jan 4

 Select either the whole lines or just the column containing numbers
 to be summed up, then execute "Block Sum" operation.

 ~Contents~@Contents@

@Wrap
$ #Reformat Block#
 This function can perform either of two operations:
    a) reformat selected block, or current line.
    b) process lines in selected block, or current line.

 #Reformat Block#

 First, the selected lines are joined into one line.
 Then that line is split according to the values in "Start column"
 and "End column" boxes. Right text border is justified if the
 corresponding checkbox is checked.

 #Process Lines#

 Lines are processed according to a Lua expression appearing in the
 "Expression" edit box. The expression is evaluated for every line of
 the block.
   #*# If its value is a string, it replaces that line's contents.
   #*# If its value is false/nil/nothing, the line is deleted.
   #*# Otherwise, the line remains unchanged.
 Two special variables are available to the expression:
   #N# - number of the processed line within the block
   #L# - contents of the processed line

 ~Contents~@Contents@

@SortLines
$ #Sort Lines#
^\1FDescription\-

 The utility sorts lines in the selected block according to up to 3 sorting
criteria at a time.

 #Expressions#

    User specifies what kind of sorting is needed by means of
    expressions. An expression takes an editor line as its input and
    results in a value meaning the "weight" of this line to be used
    in comparison with other lines. When two lines are compared, the
    line having lesser "weight" will be placed above the other one,
    unless the corresponding #Reverse# checkbox is checked.

    Expressions must be valid Lua language expressions resulting
    in either a number or a string. However, to use the most common
    sorting operations, no knowledge of Lua is required (see examples
    below). When results are strings, they are compared either case-
    sensitively or case-insensitively, according to the state of
    #Case sensit.# checkbox.

    User types in expressions in one or more of the #Expr.# fields
    of the dialog. Each of these 3 fields can be enabled or disabled;
    when multiple fields are used, upper fields have higher sorting
    priority.

  #"Case sensit." checkbox#
    If the results of expression evaluations are of string type,
    they are compared by the special functions. Most of the time,
    the function CompareStringW is used, and in a separate case -
    the function wcscmp.    
    The three-state switch #Case sensit.# controls string compare.
    When the switch is in the state [ ] or [x], the plugin passes
    the predetermined flag values to the function CompareStringW.
    When the switch is in the state [?], the flags are specified
    by the user, preceding the expression and enclosed in colons.
    The flag values are listed below:
        #c#   NORM_IGNORECASE
        #k#   NORM_IGNOREKANATYPE
        #n#   NORM_IGNORENONSPACE
        #s#   NORM_IGNORESYMBOLS
        #w#   NORM_IGNOREWIDTH
        #S#   SORT_STRINGSORT
        #1#   Use wcscmp rather than CompareStringW. This flag must
            not be used in conjunction with other flags.
    Examples of flag specification:
        #:cns:#
        #:1:#
        #::# (may be omitted)
 
#Variables and functions#

    Expressions can use the following convenience variables
    and functions:
       #a#     : text of a line participating in sorting
       #i#     : number of a line (1 = the upper selected line)
       #I#     : total number of lines in selection (a constant)
       #C(n)#  : the n-th column of #a#
       #L(s)#  : convert arbitrary string s to lower case
       #N(s)#  : convert arbitrary string s to number
       #LC(n)# : convert n-th column of #a# to lower case;
               same as L(C(n))
       #NC(n)# : convert n-th column of #a# to number; same as N(C(n))

    More variables and functions can be added by the user (see
    #Load File# section below).

 #Vertical blocks#

    If a block of text was selected by using Alt key ("vertical"
    blocks), then the expressions in fields #Expr.1# - #Expr.3# will
    operate on selected parts of lines rather than on whole lines.
    What is sorted, however, depends on the state of the
    #Only selected# checkbox. If it is checked then only selected
    parts of lines will be sorted, otherwise - whole lines.

 #Column Pattern#

    "Column" is part of Editor line defined by a Far ~regex pattern~@:RegExp@ in
    the #Column Pattern# field. By default, a column is a sequence of
    non-space characters. Press the #Default# button to restore the
    default pattern.

 #Load File#

    Sometimes, lines have complex structure and sorting must be
    done in accordance to some complex rules. This utility handles
    such cases by allowing to add functions from Lua scripts on the
    disk. Such function parses the structure in question and
    returns a number or a string representing the "weight" of the
    input data to be used in sorting.

    Type in the full pathname of the needed script in the #Load File#
    dialog field. This script will be run before the sorting begins.
    Global functions provided by the script can be used in the #Expr.#
    fields of the dialog.

^\1FSimple Examples (no knowledge of Lua is required)\-

 #Example 1:#   a          [ ] Reverse
    Sort lines alphabetically, case insensitive.

 #Example 2:#   a          [x] Reverse
    Sort lines alphabetically, case insensitive, in reverse order.

 #Example 3:#   a          [x] Case sensit.
    Sort lines alphabetically, case sensitive.

 #Example 4:#   :1:a       [?] Case sensit.
    Sort lines alphabetically using function wcscmp.

 #Example 5:#   C(2)
    Sort lines according to alphabetical order in the 2-nd column.

 #Example 6:#   N(a)
    Sort lines (containing one number per line) numerically.

 #Example 7:#   NC(3)
    Sort lines according to numerical order in the 3-rd column.

 #Example 8:#   C(2)      [ ] Reverse
              NC(1)     [x] Reverse
              C(4)      [x] Reverse   [x] Case sensit.
    Sort lines according to:
       (a) alphabetical order in the 2-nd column - highest priority;
       (b) reverse numerical order in the 1-st column - lower
           priority;
       (c) reverse alphabetical order in the 4-th column; case
           sensitive - lowest priority;

 #Example 9:#   NC(2) * NC(3)
    Sort lines according to product of numbers of 2-nd and 3-rd
    columns.

^\1FAdvanced Examples (knowledge of Lua is required)\-

 #Example 10:#   a:sub(10,20)
    Sort lines according to alphabetical order in the substring
    [10,20].

 #Example 11:#  a:match"{.-}" or ""
    Sort lines according to alphabetical order within the 1-st {}.

 #Example 12:#  a:len()
    Sort lines according to their lengths.

 #Example 13:#  a:reverse()
    Sort lines in the alphabetical order of their reversed values.

 #Example 14:#  math.max(NC(1), NC(2), NC(3))
    Sort lines according to the maximum number in their first three
    columns.

 #Example 15:#  -i
    Inverse order of lines in the selection.

 #Example 16:#  i%2==0 and i-1 or i+1
    Swap lines in every pair of lines in the selection.

 #Example 17:#  i%2==1 and i-I or i
    First place all lines with odd line numbers, then all lines with even ones.

 ~Contents~@Contents@

@PluginConfig
$ #Plugin's Configuration Dialog#
 #[x] Always reload default script#

    Default script (or "main" script) is a file that contains Lua handlers of
the exported plugin functions. This script is run when FAR calls
#SetStartupInfoW#, making the handlers available to the plugin.
    With this option checked, the default script will be additionally run
every time FAR calls #OpenW# function. This is handy when the default script
needs to be debugged.

 #[x] Always reload on 'require'#

    When Lua code 'require's some library first time, it is loaded from the
disk. Subsequent 'require's of the same library return it from the memory.
With this option checked, libraries are always loaded from the disk (this may
be needed when debugging a library).

 #[x] Use 'strict' mode#

    With this option turned on, the plugin does not allow access to
"undeclared" global variables.

 #[x] Return to Main menu#

    When a utility that was activated via the main menu finishes its execution,
the main menu is displayed again.

 ~Contents~@Contents@

@ReloadUserFile
$ #Reload User File#
    If the file #_usermenu.lua# exists in the plugin directory, it will be run.
This may be needed if _usermenu.lua or one of the files containing event
handlers were edited by the user.

    For details on file _usermenu.lua and event handlers, see the manual.

 ~Contents~@Contents@
