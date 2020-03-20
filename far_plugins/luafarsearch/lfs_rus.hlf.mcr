.Language=Russian,Russian (Русский)
.PluginContents=LuaFAR Поиск
.Options CtrlStartPosChar=¦

@Contents
$ #LuaFAR Search (версия #{VER_STRING})#
^#ВОЗМОЖНОСТИ#
 * Поиск и замена в редакторе.
 * Поиск и замена из панелей.
 * Регулярные выражения (4 библиотеки на выбор).
 * Пользовательские скрипты на языке Lua, с доступом к библиотеке
   LuaFAR, библиотекам регулярных выражений, а также к API плагина.
 * Меню плагина может дополняться пунктами пользователя, которые
   могут включать в себя "пресеты", тесты и т.д.   

 #Редактор#
   ~Меню~@EditorMenu@
   ~Поиск и замена~@OperInEditor@
   ~Многострочная замена~@MReplace@
 
 #Панели#
   ~Меню~@PanelMenu@
   ~Поиск и замена~@OperInPanels@
   ~Grep~@PanelGrep@
   ~Переименование~@Rename@
   ~Панель~@TmpPanel@
 
 #Разное#  
   ~Установки~@Configuration@
   ~Схемы~@Presets@
   ~Скрипты пользователя~@UserScripts@
 
 #Документация по использованию регулярных выражений#
   ~Регулярные выражения Far~@:RegExp@
   ~Oniguruma~@Oniguruma@
   ~PCRE~@PCRE@
   ~Синтаксис образца замены~@SyntaxReplace@

^#БИБЛИОТЕКИ, ИСПОЛЬЗУЕМЫЕ ПЛАГИНОМ#
 #Lua 5.1#                    : lua51.dll
 #LuaFAR#                     : luafar3.dll
 #Universal Charset Detector# : ucd.dll
 #Lrexlib#                    : rex_onig.dll, rex_pcre.dll, rex_pcre2.dll (опционально)
 #Oniguruma#                  : onig.dll (опционально)
 #PCRE#                       : pcre.dll (опционально)
 #PCRE2#                      : pcre2.dll (опционально)

@EditorMenu
$ #Меню плагина в Редакторе#
^#Пункты меню#

 #Искать#                              ¦Искать текст, используя установки, заданные в ~диалоге~@OperInEditor@.
 
 #Заменить#                            ¦Заменить текст, используя установки, заданные в ~диалоге~@OperInEditor@.
 
 #Повторить#                           ¦Повторить последнюю операцию #Искать# или #Заменить#.
 
 #Повторить (обратный поиск)#          ¦Повторить последнюю операцию #Искать# или #Заменить#, в обратном направлении.
 
 #Искать слово под курсором#           ¦Искать слово под курсором, регистронезависимо.
 
 #Искать слово под курсором (назад)#   ¦Искать слово под курсором, регистронезависимо, в обратном направлении.
 
 #Многострочная замена#                ¦См. ~Многострочная замена в редакторе~@MReplace@

 #Переключить подсветку#               ¦Если плагин подсветил участки текста в редакторе, то эта подсветка будет выключена/включена.


 ~Содержание~@Contents@

@OperInEditor
$ #Работа в редакторе#
^#Установки диалога# 
 #Искать#
 Образец поиска.
 Если опция Регулярное Выражение включена, то образец поиска интерпретируется
как регулярное выражение, иначе - как обычный текст.

 #[ \ ]# и #[ / ]#
 Экранирует специальные символы в образце поиска или замены.

 #[x] Учитывать регистр#
 При поиске учитывается регистр символов.

 #[x] Регулярное выражение#
 Если включено, то строка поиска интерпретируется как регулярное выражение,
иначе - как простой текст.

 #Библиотека#
 Выбор библиотеки регулярных выражений, которая будет производить поиск.
 Одна библиотека (~Far regex~@:RegExp@) встроена в Far Manager и всегда доступна.
 Для подключения других библиотек (~Oniguruma~@Oniguruma@, ~PCRE~@PCRE@ и #PCRE2#)
 в системе (на %PATH% или %FARHOME%) должны присутствовать следующие файлы:

   Oniguruma  : onig.dll
        PCRE  : pcre.dll
        PCRE2 : pcre2.dll
 
 #[x] Целые слова#
 Искать только целые слова.

 #[x] Игнорировать пробелы#
 Все буквальные пробелы в образце поиска удаляются перед началом операции.
Предварите пробел символом #\#, если пробел является интегральной частью
образца поиска.

 #Область поиска#
   #(•) Глобальная# - весь буфер редактора.
   #( ) Выделенная# - выделенный блок.

 #Начало поиска#
   #(•) Позиция курсора# - искать от курсора до края области поиска.
   #( ) Начало области#  - искать между краями области поиска.

 #[x] Искать по кругу#
 Искать по кругу в области поиска. #[?]# означает спросить пользователя.

 #[x] Обратный поиск#
 Искать в обратном направлении (справа налево, снизу вверх).

 #[x] Подсветить все#
 Подсветить все вхождения искомого текста в редакторе.

 #Заменить на#
 #[x] Режим функции#
 См. ~Синтаксис образца замены~@SyntaxReplace@.
 
 #[x] Удалять пустые строки#
 Если строка редактора после произведённой операции замены становится пустой,
она будет удалена.

 #[x] Удалять строки без вхождений#
 Если в строке не найдено ни одного вхождения, соответствующего образцу поиска,
строка будет удалена.

 #[x] Подтверждать замену#
 Выводить запрос пользователя на выполнение замены.

 #[x] Дополнительно#
 Разрешить дополнительные операции: Фильтр Строки, Начальный Код и
Конечный Код.

 #Фильтр Строки#
 *  Фильтр строки позволяет производить поиск или замену только
    на определённых строках, пропуская все остальные.
 *  Строка фильтра интерпретируется как #тело# Lua-функции
    (поэтому ключевое слово 'function', список параметров и ключевое
    слово 'end' должны быть опущены). Функция вызывается всякий раз
    при переходе на новую строку поиска. Если она возвращает true,
    то данная строка пропускается.
 *  Функция может использовать глобальные переменные, а также
    следующие предустановленные переменные:
    #s#   -- Текущая строка поиска (или её часть, при поиске в блоке)
    #n#   -- Номер строки поиска (номер начальной строки поиска = 1)
    #rex# -- Используемая библиотека регулярных выражений.

 #Начальный код#
 Код Lua, исполняемый перед началом процесса поиска:
   a) глобальные переменные и функции могут быть определены здесь
      и использованы далее #Фильтром Строки# и #Заменой# (в Режиме
      Функции).
   b) вызов #dofile (имя_файла)# может быть помещён здесь, с той же
      целью, что в предыдущем параграфе.

 #Конечный код#
 Код Lua, исполняемый после окончания процесса поиска. Может быть
использован для закрытия файла, открытого "Начальным кодом".

 #[ Схемы ]#
 Выводится меню для операций со ~схемами~@Presets@.

 #[ Подсчёт ]#
 Произвести поиск и подсчитать все вхождения найденного текста.

 #[ Все ]#
 Произвести поиск и вывести список всех строк, содержащих найденный текст.
Каждая строка списка содержит строку Редактора, в которой было найдено хотя
бы одно совпадение. ~Подробнее~@EditorShowAll@.

^#ОГРАНИЧЕНИЯ#
 Поиск производится в Редакторе построчно. Таким образом, вхождения
текста, занимающие более одной строки, не могут быть найдены.

^#СКРИПТЫ ПОЛЬЗОВАТЕЛЯ#
 Утилита может быть расширена с помощью ~Скриптов Пользователя~@UserScripts@.

 ~Содержание~@Contents@

@EditorShowAll
$ #Операция "Показать все вхождения"#
 Произвести поиск и вывести список всех строк, содержащих найденный текст.
Каждая строка списка содержит строку Редактора, в которой было найдено хотя
бы одно совпадение.

    #Enter#            Перейти к выделенной строке в редакторе.     
    #F6#               Показывать разные части длинных строк.       
    #F7#               Показать выделенную строку в окне сообщения. 
    #F8#               Закрыть список и открыть снова диалог поиска.
    #Ctrl-C#           Скопировать выделенную строку в буфер обмена.
    #Ctrl-Up#, #Ctrl-Down#, #Ctrl-Home#, #Ctrl-End#
                     Прокрутить редактор без закрытия списка.
    #Ctrl-Num0#        Восстановить позицию редактора после прокрутки.

 ~Содержание~@Contents@

@Configuration
$ #Установки#
 #[x] Использовать историю Far#
 Определяет, которую историю использовать в полях "Искать" и "Заменить на".
Может использоваться либо история Far, либо отдельная история плагина.
 
 #Имя лог-файла#
 Задать имя лог-файла, создаваемого утилитой ~Переименование~@Rename@.
Имя может включать в себя шаблон даты-времени #\D{...}# - см. его описание
в разделе ~Синтаксис образца замены~@SyntaxReplace@.
 
 #[x] Обрабатывать выделение, если оно есть#
 При вызове в редакторе диалога поиска или замены, автоматически установить
#Область поиска# в состояние #Выделенная#, если редактор содержит выделение.
  
 #[x] Выделять найденный текст#
 Выделять найденный текст в редакторе.
 
 #[x] Показывать время операции#
 Показывать время исполнения операции.
 
 #Подставлять строку поиска из:#
 Определяет начальное значение поля #Поиск# при вызове диалога Поиска
или Замены. Есть 3 варианта:
    #(•) Редактор#          слово под курсором.
    #( ) История#           строка поиска из истории диалогов Фара.
    #( ) Не подставлять#    оставить поле Поиск пустым.

 #Цвет подсветки#
 Выбор цвета подсветки при использовании опции поиска #Подсветить все#.

 ~Содержание~@Contents@

@Presets
$ #Схемы#
 В диалогах поиска и замены имеется кнопка #Схемы#, при нажатии на которую
появляется меню, позволяющее манипулировать с наборами установок диалогов
(схемами), как с единым целым: создавать, загружать, переименовывать и удалять.

 #Del#   - удалить схему
 #Enter# - загрузить выбранную схему в диалог
 #Esc#   - закрыть меню и вернуться в диалог
 #F2#    - сохранить загруженную схему под прежним именем
 #F6#    - переименовать схему
 #Ins#   - сохранить текущие установки диалога как новую схему

 ~Содержание~@Contents@

@UserScripts
$ #Скрипты пользователя#
 Плагин может исполнять скрипты Lua, добавляемые пользователем. Это
 делается так же, как и в плагине #LuaFAR for Editor#. Смотрите главу
 "User's utilities" справочного руководства указанного плагина.

^#ЧЕМ РАСПОЛАГАЮТ СКРИПТЫ ПОЛЬЗОВАТЕЛЯ#

  #БИБЛИОТЕКИ:#
    *  Стандартные библиотеки Lua
    *  Библиотеки LuaFAR
    *  #dialog#  (require "far2.dialog"; тот же модуль,
                что применяется в LuaFAR for Editor)
    *  #history# (require "far2.history"; тот же модуль,
                что применяется в LuaFAR for Editor)
    *  #message# (require "far2.message"; тот же модуль,
                что применяется в LuaFAR for Editor)

  #ФУНКЦИИ:#
   ~lfsearch.EditorAction~@FuncEditorAction@
   ~lfsearch.MReplaceEditorAction~@FuncMReplaceEditorAction@
   ~lfsearch.SearchFromPanel~@FuncSearchFromPanel@
   ~lfsearch.ReplaceFromPanel~@FuncReplaceFromPanel@
   ~lfsearch.SetDebugMode~@FuncSetDebugMode@


 ~Содержание~@Contents@

@FuncEditorAction
$ #lfsearch.EditorAction#
 #nFound, nReps = lfsearch.EditorAction (Operation, Data, SaveData)#

 #Operation# - одна из предопределённых операций.
 Следующие операции соответствуют пунктам меню плагина:

       "search"         :  операция поиска, со своим диалогом
       "replace"        :  операция замены, со своим диалогом
       "repeat"         :  повтор последней операции
       "repeat_rev"     :  повтор последней операции (обратное напр.)
       "searchword"     :  искать слово под курсором
       "searchword_rev" :  искать слово под курсором (назад)
       "config"         :  вызов диалога конфигурации

 Следующие операции не выводят диалогов и заключительного сообщения:

       "test:search"    :  операция поиска
       "test:count"     :  подсчёт всех вхождений в тексте
       "test:showall"   :  показ всех вхождений
       "test:replace"   :  операция замены

 #Data# - Таблица с предопределёнными полями. Если какое-либо поле
        отсутствует, применяется значение по умолчанию для данного
        поля. Для булевых переменных это - `false'; для строк -
        пустая строка. Тип переменной может быть определён по 1-й
        букве её имени: b=boolean; f=function; n=number; s=string.

       "sSearchPat"      : образец поиска
       "sReplacePat"     : образец замены
       "sRegexLib"       : библиотека регулярных выражений:
                           "far" (по умолчанию), "oniguruma",
                           "pcre" или "pcre2"
       "sScope"          : область поиска: "global" (по умолчанию)
                           или "block"
       "sOrigin"         : начало поиска: "cursor" (по умолчанию)
                           или "scope"
       "bWrapAround"     : искать по кругу в области поиска;
                           параметр учитывается только если
                           sScope=="global" и sOrigin=="cursor"

       "bCaseSens"       : регистрозависимый поиск
       "bRegExpr"        : режим регулярных выражений
       "bWholeWords"     : искать только целые слова
       "bExtended"       : игнорировать пробелы в рег.выражениях
       "bSearchBack"     : искать в обратном направлении

       "bRepIsFunc"      : режим функции
       "bDelEmptyLine"   : удалять пустые строки после замены
       "bDelNonMatchLine": удалять строки без найденных вхождений
       "bConfirmReplace" : вызывать fUserChoiceFunc для подтверждения
                           замены

       "bAdvanced"       : включить фильтр строки, начальную функцию
                           и конечную функцию

       "sFilterFunc"     : функция фильтра строки

       "sInitFunc"       : начальная функция
       "sFinalFunc"      : конечная функция

       "fUserChoiceFunc" :
         Функция, вызываемая программой, когда найдено вхождение,
         и требуется решение пользователя. Функция вызывается только
         если установлен флаг bConfirmReplace.
         Параметры (все - строки): sTitle, sFound, sReps.
         Возвращаемое значение должно быть одним из:
             "yes", "all", "no", "cancel".
         Если функция не задана, программа применяет свой обычный
         диалог пользовательского выбора.

 #SaveData# - сохранить #Data# в истории диалогов поиска/замены.

 #nFound, nReps# - количество найденных вхождений и произведённых
                 замен, соответственно.
 Если выводится диалог поиска или замены, то при отмене операции
 пользователем функция возвращает nil.

 ~Содержание~@Contents@

@FuncMReplaceEditorAction
$ #lfsearch.MReplaceEditorAction#
 #nFound, nReps = lfsearch.MReplaceEditorAction (Operation, Data)#

 #Operation# - одна из предопределённых операций.

       "replace"        :  операция замены
       "count"          :  подсчёт всех вхождений в тексте

 #Data# - Таблица с предопределёнными полями. Если какое-либо поле
        отсутствует, применяется значение по умолчанию для данного
        поля. Для булевых переменных это - `false'; для строк -
        пустая строка. Тип переменной может быть определён по 1-й
        букве её имени: b=boolean; f=function; n=number; s=string.

       "sSearchPat"      : образец поиска
       "sReplacePat"     : образец замены
       "sRegexLib"       : библиотека регулярных выражений:
                           "far" (по умолчанию), "oniguruma",
                           "pcre" или "pcre2"

       "bCaseSens"       : регистрозависимый поиск
       "bRegExpr"        : режим регулярных выражений
       "bWholeWords"     : искать только целые слова
       "bExtended"       : игнорировать пробелы в рег.выражениях

       "bFileAsLine"     : "." соответствует любому символу,
                           включая "\n"
       "bMultiLine"      : "^" and "$" соответствуют началу и концу
                           каждой строки

       "bRepIsFunc"      : режим функции

       "bAdvanced"       : включить начальную функцию и конечную
                           функцию
       "sInitFunc"       : начальная функция
       "sFinalFunc"      : конечная функция

 #nFound, nReps# - количество найденных вхождений и произведённых
                 замен, соответственно.

 ~Содержание~@Contents@

@FuncSearchFromPanel
$ #lfsearch.SearchFromPanel
 #tFound = lfsearch.SearchFromPanel (Data, bWithDialog)#

 #Data# - Таблица с предопределёнными полями. Если какое-либо поле
        отсутствует, применяется значение по умолчанию для данного
        поля. Для булевых переменных это - `false'; для строк -
        пустая строка. Тип переменной может быть определён по 1-й
        букве её имени: b=boolean; f=function; n=number; s=string.

       "sFileMask"       : маска файла
       "sSearchPat"      : образец поиска
       "sRegexLib"       : библиотека регулярных выражений:
                           "far" (по умолчанию), "oniguruma",
                           "pcre" или "pcre2"

       "bRegExpr"        : режим регулярных выражений
       "bCaseSens"       : регистрозависимый поиск
       "bWholeWords"     : искать только целые слова
       "bMultiPatterns"  : режим нескольких выражений
       "bExtended"       : игнорировать пробелы в рег.выражениях
       "bFileAsLine"     : файл как строка
       "bInverseSearch"  : инверсный поиск
       "bSearchFolders"  : искать папки
       "bSearchSymLinks" : искать в символических ссылках

       "sSearchArea"     : одно из: "FromCurrFolder", "OnlyCurrFolder",
                           "SelectedItems", "RootFolder", "NonRemovDrives",
                           "LocalDrives", "PathFolders"

 #bWithDialog# - нужно ли вызывать диалог.
 
 #tFound# - таблица (массив) с именами найденных файлов.

 
 ~Содержание~@Contents@

@FuncReplaceFromPanel
$ #lfsearch.ReplaceFromPanel
 #nFound, nReps = lfsearch.ReplaceFromPanel (Data, bWithDialog)#

 #Data# - Таблица с предопределёнными полями. Если какое-либо поле
        отсутствует, применяется значение по умолчанию для данного
        поля. Для булевых переменных это - `false'; для строк -
        пустая строка. Тип переменной может быть определён по 1-й
        букве её имени: b=boolean; f=function; n=number; s=string.

       "sFileMask"       : маска файла
       "sSearchPat"      : образец поиска
       "sReplacePat"     : образец замены
       "sRegexLib"       : библиотека регулярных выражений:
                           "far" (по умолчанию), "oniguruma",
                           "pcre" или "pcre2"

       "bRepIsFunc"      : режим функции
       "bMakeBackupCopy" : сохранять копию
       "bConfirmReplace" : подтверждать замену
       "bRegExpr"        : режим регулярных выражений
       "bCaseSens"       : регистрозависимый поиск
       "bWholeWords"     : искать только целые слова
       "bExtended"       : игнорировать пробелы в рег.выражениях
       "bSearchSymLinks" : искать в символических ссылках

       "sSearchArea"     : одно из: "FromCurrFolder", "OnlyCurrFolder",
                           "SelectedItems", "RootFolder", "NonRemovDrives",
                           "LocalDrives", "PathFolders"

       "bAdvanced"       : включить начальную функцию и конечную функцию
       "sInitFunc"       : начальная функция
       "sFinalFunc"      : конечная функция

 #bWithDialog# - нужно ли вызывать диалог.
 
 #возвращает:# ничего.

 
 ~Содержание~@Contents@

@FuncSetDebugMode
$ #lfsearch.SetDebugMode#
^#lfsearch.SetDebugMode (On)#

 Функция включает или выключает режим отладки.
 Когда режим отладки включен:
 - Главный Lua-файл плагина перезагружается перед каждым вызовом
   #export.Open()#.
 - Функция #require# работает без кэша.

 ~Содержание~@Contents@

@PanelMenu
$ #Меню плагина в панелях
^#Пункты меню#

 #Искать#                       ¦Искать текст, используя установки, заданные в ~диалоге~@OperInPanels@.
 
 #Заменить#                     ¦Заменить текст, используя установки, заданные в ~диалоге~@OperInPanels@.
 
 #Grep#                         ¦Произвести поиск, используя указанные ~параметры~@PanelGrep@, и вывести результаты в файл.
 
 #Переименовать#                ¦Переименовать файлы и папки, используя установки, заданные в ~диалоге~@Rename@.

 #Панель#                       ¦Открыть ~временную панель~@TmpPanel@ плагина.


 ~Содержание~@Contents@

@OperInPanels
$ #Поиск и замена в панелях#
^#Установки диалога# 
 #Маска файла#
 Синтаксис идентичен ~Маскам файлов~@:FileMasks@ в стиле Фара.

 #* Искать#
 #* Заменить на#
 #* Режим функции#
 #* Подтверждать замену#
 #* Учитывать регистр#
 #* Целые слова#
 #* Регулярное выражение#
 #* Игнорировать пробелы#
 #* Библиотека#
 #* Начальный код#
 #* Конечный код#
 Эти установки аналогичны ~диалогу в редакторе~@OperInEditor@.

 #[x] Сохранять копию# (только в диалоге "Замена")
 Если файл был изменён в результате операции замены, создаётся
 резервная копия оригинального файла.

 #[x] Несколько выражений# (только в диалоге "Поиск")
 Несколько выражений могут быть указаны одновременно в поле "Искать".
   #*# Выражения отделены друг от друга пробелами.
   #*# Если любое из выражений содержит пробелы или начинается с одного
     из символов #+#, #-# или #"#, то оно должно быть заключено
     в двойные кавычки, и каждая двойная кавычка, являющаяся частью
     выражения, должна быть удвоена.
   #*# Если выражение ДОЛЖНО быть найдено в файле, предварите его
     префиксом #+#.
   #*# Если выражение НЕ ДОЛЖНО быть найдено в файле, предварите его
     префиксом #-#.
   #*# Из всех выражений без префикса хотя бы одно должно быть найдено
     в файле.
   #*# Пример:
       foo bar -foobar +"my school" -123 +456

 #[x] Файл как строка# (только в диалоге "Поиск")
 Когда эта опция включена, точка ("#.#") в регулярном выражении поиска
 находит переводы строки и возвраты каретки, как и любые прочие
 символы.

 #[x] Инверсный поиск# (только в диалоге "Поиск")
 Если указано выражение для поиска текста, то будет выдан список
 файлов, не содержащих ни одного вхождения искомого текста.

 #Кодировки# (только в диалоге "Поиск")
 Выберите одну или более кодовых страниц для поиска в тексте.
 Имеется 3 возможности:

   #*# Выбрана некоторая кодовая страница из списка: поиск будет производиться
с использованием только данной страницы.
 
   #*# Выбран пункт "Кодовые страницы по умолчанию". Поиск будет производиться
с использованием следующего набора кодовых страниц:
{ OEM, ANSI, 1200, 1201, 65000, 65001 }.

   #*# Выбран пункт "Отмеченные кодовые страницы", и некоторые кодовые страницы
отмечены в списке. Поиск будет производиться с использованием данных кодовых
страниц. (Кодовая страница может быть отмечена в списке нажатием Space или Ins).
 
 #Область поиска#
 Выберите область поиска для файлов и папок:
   #*# От текущей папки
   #*# Только в текущей папке
   #*# Выделенные файлы и папки
   #*# От корневой папки диска
   #*# Во всех несъёмных дисках
   #*# Во всех локальных дисках
   #*# В папках на PATH 

 #[x] Фильтр папок#   #[ Настроить ]#
 Разрешить использование фильтра папок. 
 Вызвать ~диалог фильтра папок~@DirectoryFilter@.

 #[x] Фильтр файлов#  #[ Настроить ]#
 Разрешить использование фильтра файлов.
 Вызвать ~меню фильтров~@:FiltersMenu@.

 #[x] Искать папки# (только в диалоге "Поиск")
 Укажите, нужно ли искать папки.

 #[x] Искать в символич. ссылках#
 Укажите, нужно ли искать в символических ссылках.

 #[ Установки ]# (только в диалоге "Поиск")
 Вызвать ~диалог конфигурации~@SearchResultsPanel@ панели результатов поиска.

 ~Содержание~@Contents@

@SearchResultsPanel
$ #Панель результатов поиска#
 Плагин использует встроенную временную панель для вывода результатов
поиска. Установки временной панели настраиваются в диалоге конфигурации.

^#Установки диалога#
 #Типы колонок#  
 #Ширина колонок#
 #Типы колонок строки статуса#
 #Ширина колонок строки статуса#
 #Полноэкранный режим#
 Данные установки описаны в файле справки стандартного плагина TmpPanel.

 #Режим и порядок сортировки#
 Укажите режим сортировки (0...15; 0=сортировка по умолчанию),
затем через запятую укажите порядок сортировки (0=прямой, 1=обратный).

 #Сохранять содержимое#
 Запоминать список файлов в панели при её закрытии. Если впоследствии открыть
панель, данный список файлов будет снова отображён.

 ~Содержание~@Contents@

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

 ~Содержание~@Contents@

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

 ~Содержание~@Contents@

@SyntaxReplace
$ #Синтаксис образца замены#
 Если включена опция Регулярное Выражение, то:
    *  #$1#-#$9# и #$A#-#$Z# используются для обозначения частичных
       совпадений (групп). #$0# обозначает полное совпадение.
    *  #${name}# используется для обозначения именованных групп
       (поддерживается только для библиотек Oniguruma и PCRE).
    *  Буквальные знаки доллара (#$#) и обратные слеши (#\#) должны
       быть предварены знаком #\#.
    *  Прочие символы пунктуации могут быть предварены символом #\#
       (хотя это не обязательно).

       Некоторые символы могут быть обозначены последовательностями
       других символов, так как последние легче ввести в поле
       диалога:
       #\a#        alarm (hex 07)
       #\e#        escape (hex 1B)
       #\f#        новая страница (hex 0C)
       #\n#        новая строка (hex 0A)
       #\r#        возврат каретки (hex 0D)
       #\t#        табуляция (hex 09)
       #\xhhhh#    символ с шестнадцатеричным кодом #hhhh#

    *  Следующие последовательности позволяют управлять регистром
       текста:
       #\L#        преобразовать последующий текст в нижний регистр
       #\U#        преобразовать последующий текст в верхний регистр
       #\E#        конец области действия последнего \L или \U
       #\l#        преобразовать следующий символ в нижний регистр
       #\u#        преобразовать следующий символ в верхний регистр

       Операторы \L и \U могут быть вложенными. Их область действия
       простирается до соответствующего \E (или до конца образца
       замены).

    *  Следующие последовательности вставляют нумерацию:
       #\R#           вставить текущее значение счётчика замен
       #\R{#смещение#}# то же, но с заданным смещением, например:
                    \R{20} или \R{-10}
       #\R{#смещение#,#ширина#}# то же, но вставить с заданной шириной
                    текста (в начале добавляются нули),
                    например: \R{20,4} или \R{-10,4}

    *  Данная последовательность вставляет текущую дату и/или время:
       #\D{#формат#}#   Формат должен соответствовать синтаксису
                    аргумента Lua-функции os.date,
                    например: \D{%Y-%m-%d}

    *  Данная последовательность работает только в утилите
       ~Переименование~@Rename@.
       #\N#           Имя файла, без расширения
       #\X#           Расширение файла (не включая точку)

 Если включен Режим функции, то текст в этом поле интерпретируется как тело
функции Lua (см. ниже).

 #[x] Режим функции#
 *  Образец замены интерпретируется как #тело# Lua-функции
    (поэтому ключевое слово 'function', список параметров и ключевое
    слово 'end' должны быть опущены).
    Функция вызывается каждый раз, когда находится совпадение.
 
 *  Функция может использовать следующие предустановленные переменные:
       #T#   - таблица, содержащая совпадения
          #T[0]#          - полное совпадение
          #T[1], ...#     - частичные совпадения, нумерованные группы
          #T[name1], ...# - именованные группы
       #M#   - номер текущего совпадения (отсчёт от 1)
       #R#   - номер текущей замены (отсчёт от 1)
       #LN#  - номер строки в редакторе или файле (отсчёт от 1)
       #rex# - используемая библиотека регулярных выражений
 
 *  Функция может создавать и модифицировать глобальные переменные
    и использовать их в течение её текущего и будущих вызовов
    (в рамках данной операции поиска).

 *  Допустим, функция вернула два значения: #ret1# и #ret2#. Эти значения
    будут обработаны следующим образом:
    
    Во всех утилитах:    
    *  #type(ret1)=="string" or type(ret1)=="number"# :
       ret1 используется в качестве текста замены.
    *  #ret1==nil or ret1==false#     : замена не производится
    *  недокументированный тип #ret1# : замена не производится
    
    В утилитах построчной замены из редактора и панелей:
    *  #ret1==true# : удаляется строка вместе с переводом строки
         - к утилитам "многострочная замена" и "переименование" это
           не относится.
         - при замене из панелей удаляется только та часть строки,
           которая ещё не была записана в выходной файл.
    
    В утилитах замены из редактора и панелей:
    *  #ret2==true# : немедленное завершение операции поиска и замены
         - только в автоматическом (без подтверждения пользователем)
           режиме работы.
         - к утилите "переименование" это не относится.
    
 ~Содержание~@Contents@

@MReplace
$ #Многострочная замена в редакторе#
 Данная утилита производит поиск и замену в нескольких строках текста редактора.
Эти строки должны быть выделены перед началом операции. Тип выделения (поточный
или вертикальный) значения не имеет: если хотя бы одна позиция в строке
выделена, то данная строка участвует в операции целиком.

 Если выделения нет, то операция производится над всем содержимым редактора.

 На стадии поиска строки текста склеиваются с вставкой \n между ними,
независимо от того, какой тип перевода строки есть у данной строки. На стадии
замены вставляются переводы строк по умолчанию.

 Все замены производятся сразу, без подтверждения пользователя. Так же сразу
они все могут быть отменены нажатием Ctrl-Z.

^#Установки диалога# 
 #Искать#
 Образец поиска.

 #Заменить на#
 См. ~Синтаксис образца замены~@SyntaxReplace@.

 #[x] Регулярное выражение#
 Если включено, то строка поиска интерпретируется как
~регулярное выражение~@:RegExp@, иначе - как простой текст.

 #[x] Учитывать регистр#
 Включает чувствительность к регистру символов.

 #[x] Целые слова#
 Искать только целые слова.

 #[x] Игнорировать пробелы#
 Все буквальные пробелы в образце поиска удаляются перед началом операции.
Предварите пробел символом #\#, если пробел является интегральной частью
образца поиска.

 #[x] Файл как строка#
 Если включено, то #.# (точка) в регулярном выражении находит любой символ,
включая \r и \n.
 
 #[x] Многострочный режим#
 Если включено, то #^# и #$# в регулярном выражении находят соответственно
начало и конец каждой строки.

 ~Содержание~@Contents@

@Rename
$ #Переименование#
 Данная утилита предназначена для переименования файлов и папок. Она работает
из панелей.

 Вызовите утилиту из меню плагина. Появится диалог "LF Rename".

 #Маска файла:#
 Переименовываться будут только файлы и папки, соответствующие заданной маске.
Синтаксис идентичен ~Маскам файлов~@:FileMasks@ в стиле Far Manager.
 Значение маски файла не связано с областью поиска, например: имя папки, от
которой будет производиться рекурсивный поиск, может не соответствовать маске.

 #(•) Искать во всех#
 Поиск элементов для переименования и папок для рекурсивного поиска
производится среди всех элементов активной панели.
 
 #( ) Искать в выделенных#
 Поиск элементов для переименования и папок для рекурсивного поиска
производится только среди выделенных элементов активной панели. Если
выделенных элементов нет, обрабатывается элемент под курсором панели. 

 #[x] Переименовывать файлы#
 #[x] Переименовывать папки#
 Можно указать либо один, либо оба атрибута.

 #[x] Обработать подпапки#
 Если в области поиска есть папки, то поиск элементов для переименования
будет производиться и внутри этих папок и их подпапок.
 
 #Искать:#
 Это поле должно содержать ~Регулярное выражение Far~@:RegExp@, которое будет
сопоставлено с именем каждого выделенного файла или папки. Сопоставление -
регистронезависимое.

 #Заменить на:#
 См. ~Синтаксис образца замены~@SyntaxReplace@.

 #[x] Режим функции#
 Аналогично этому режиму при замене в редакторе.
 
 #[x] Лог-файл#
 Создать лог-файл. Файл создаётся в формате Lua-скрипта, который, будучи исполнен, переименует
файлы и папки в их прежние имена, то есть отменит переименование, произведённое плагином.
 Для этого нужно выполнить команду
      #lfs: -r<logfile>#
 или (равноценно)
      #lua: @@<logfile>#

 ~Содержание~@Contents@

@PanelGrep
$ #Grep#
 Произвести поиск согласно указанных параметров и вывести результаты в файл.
Этот файл автоматически открывается в редакторе по завершению поиска.

 Большинство элементов диалога имеет те же функции, что и в диалогах ~поиска и замены~@OperInPanels@.

 Нижеперечисленные элементы являются специфическими для данного диалога:
 
 #Пропускать#
 Это выражение, определяющее, какой текст нужно пропускать во время операции.
 Данная функция выключена, если поле пустое.
     Пример:
 Требуется найти вхождения слова #new# в C++ коде,
но не в комментариях наподобие #//...new...#.
 Для этого определяем выражение #\bnew\b# как образец поиска
и выражение #\/\/.*# как образец пропуска.

 #[x] Показывать номера строк#
 Каждая строка вывода содержит номер строки в исходном файле.

 #[x] Подсветить вхождения#
 Номера строк и найденные вхождения помечаются цветом. Цвета можно настроить в диалоге конфигурации.

 #[x] Инверсный поиск#
 Искать строки, которые не содержат заданного образца поиска.

 #Строк контекста, перед:#
 Выводимое количество строк исходного файла, предшествующих строке с вхождением.

 #Строк контекста, после:#
 Выводимое количество строк исходного файла, следующих за строкой с вхождением.

 ~Содержание~@Contents@

@TmpPanel
$ #Панель#
 Открыть панель, подобную панели стандартного плагина TmpPanel.

 ~Содержание~@Contents@

@DirectoryFilter
$ #Фильтр папок#
^#Установки диалога# 

 #Маска папок#
 Поиск файлов для включения в список и обработки будет производиться
только в папках, имя которых соответствует данной маске.
 (Если данное поле оставить пустым, то поиск будет производиться во всех папках).

   #[x] Обрабатывать путь#
   Если опция установлена, то данная маска будет проверяться
   на соответствие полному пути папки, иначе - только имени папки.

 #Маска исключения папок#
 Если папка соответствует данной маске, то её содержимое (файлы
и подпапки всех уровней вложенности) не будет включаться в список и обрабатываться.
 (Если данное поле оставить пустым, то папки исключаться не будут).

   #[x] Обрабатывать путь#
   Если опция установлена, то данная маска будет проверяться
   на соответствие полному пути папки, иначе - только имени папки.

 Синтаксис масок идентичен ~Маскам файлов~@:FileMasks@ в стиле Фара.

 ~Содержание~@Contents@
