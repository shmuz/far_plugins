﻿.Language=Russian,Russian (Русский)
.PluginContents=LuaFAR для Редактора
.Options CtrlColorChar=\

@Contents
$ #LuaFAR для Редактора (версия #{VER_STRING}) - Содержание -#
 LuaFAR для Редактора - это набор утилит, производящих различные действия
по управлению работой в редакторе FAR'а. Утилиты написаны на языке Lua.

 В набор включены следующие утилиты:
     ~Сортировка строк~@SortLines@
     ~Формат блока~@Wrap@
     ~Многострочная замена~@MReplace@
     ~Сумма в блоке~@BlockSum@
     ~Выражение Lua~@LuaExpression@
     ~Скрипт Lua~@LuaScript@
     ~Диалог параметров скрипта~@ScriptParams@
 Пользователь может добавить свои утилиты: см. руководство.

 Специальные темы:
     ~Диалог конфигурации плагина~@PluginConfig@
     ~Перезагрузка пользовательского файла~@ReloadUserFile@

@LuaExpression
$ #Выражение Lua#
 #Возможности:#
   *  Вычисляет выражения, написанные на языке Lua.
   *  Работает с выделенным текстом (или с текущей строкой,
      если нет выделенного текста).
   *  Любые допустимые Lua-выражения, включая вызовы функций.
   *  Результат выражения может быть:
          - отредактирован в окне сообщения
          - вставлен в редактор
          - скопирован в буфер обмена
   *  Все функции из библиотеки #math# языка Lua доступны как
      глобальные, т.е. 'sqrt' можно использовать вместо 'math.sqrt'.

 #Пример:#
   Если на двух выделенных строках есть выражение:
           (75 - 10) / 13 + 2^5 + sqrt(100)
           + log10(100)
   то результат операции будет равен 49.

 ~Содержание~@Contents@

@LuaScript
$ #Скрипт Lua#
   Данная команда запускает на выполнение скрипт Lua из редактора Far.

   1. Если в ~параметрах~@ScriptParams@ скрипта включена опция "Внешний скрипт",
      то в качестве скрипта будет служить указанный там же файл.
   2. Иначе, скрипт - это текст, выделенный в текущем окне редактора
      Far.
   3. Если выделенного текста нет, то скрипт - это всё содержимое
      текущего окна редактора.

   Скрипт может запускаться с ~параметрами~@ScriptParams@, независимо от того,
что является источником скрипта.

 ~Содержание~@Contents@

@ScriptParams
$ #Диалог параметров скрипта#
   Опция #Внешний скрипт# определяет имя файла (скрипта Lua), который будет
запущен на исполнение. Если задано относительное имя файла, то началом отсчёта
считается директория, содержащая редактируемый файл. Если данная опция
отключена, скриптом будет являться либо выделенный, либо весь текст текущего
окна редактора, как описано в разделе ~Скрипт Lua~@LuaScript@.
   
   Диалог позволяет задать до 4 параметров, которые будут запомнены для
последующей передачи скрипту. Каждый параметр должен быть Lua-выражением.
Стринги должны быть заключены в кавычки, как это обычно делается в Lua.
Пустая строка ввода эквивалентна значению nil.

   Параметры проверяются на корректность синтаксиса, но их вычисление
откладывается до запуска скрипта. Поэтому, например, значение 47+ сразу
вызовет сообщение об ошибке, а значение 47+nil будет принято, но вызовет
ошибку при запуске скрипта.

   Параметры будут вычисляться и передаваться скрипту только если переключатель
#Передавать параметры скрипту# установлен.
   
   Команда #Исполнить# запоминает параметры и запускает скрипт на исполнение.
 
   Команда #Сохранить# запоминает параметры для последующих запусков скрипта.

 ~Содержание~@Contents@

@BlockSum
$ #Сумма в блоке#
 Вычисляет сумму чисел, расположенных на отдельных строках (по одному числу
в строке).

   *  Работает с выделенным блоком текста, либо с текущей строкой.

   *  Для каждой строки (или её выделенной части), выделяет последо-
      вательность символов, начиная с первого непробельного, и прео-
      бразует её в число. Непосредственно за числом может следовать
      пробел либо другой разделитель. Если некоторую строку нельзя
      преобразовать в число, то её значение принимается равным нулю.

   *  Результат вычисления может быть:
          - вставлен в редактор
          - скопирован в буфер обмена

 #Пример#

 Пусть в редакторе есть следующий текст:

        25.30  расход за 1 янв.
       156.75  расход за 2 янв.
         5.00  расход за 3 янв.
        71.30  расход за 4 янв.

 Выделим все строки или только колонку чисел для суммирования,
 затем выполним операцию "Сумма в блоке".

 ~Содержание~@Contents@

@Wrap
$ #Формат блока#
 Эта функция позволяет выполнить две операции:
    a) переформатировать выделенный блок или текущую строку.
    b) вставить текст в начало строк выделенного блока или текущей
       строки.

 #Форматировать блок#
     Вначале выделенные строки соединяются в одну строку. Затем
     полученная строка разделяется с учётом значений в полях
     "Левый край" и "Правый край". Правый край выравнивается, если
     установлен соответствующий переключатель.

 #Обработать строки#

 Строки обрабатываются в соответствии с выражением Lua, находящимся
 в поле "Выражение". Выражение вычисляется для каждой строки блока.
   #*# Если тип результата - string, он заменяет содержимое строки.
   #*# Если тип результата - false/nil/ничего, строка удаляется.
   #*# В прочих случаях строка не изменяется.
 В выражении могут использоваться две специальных переменных:
   #N# - номер обрабатываемой строки в блоке
   #L# - содержимое обрабатываемой строки

 ~Содержание~@Contents@

@SortLines
$ #Сортировка строк#
^\1FОписание\-

 Утилита сортирует строки в выделенном блоке в соответствии с 3-мя критериями
сортировки одновременно.

 #Выражения#

    Пользователь указывает требуемый вид сортировки с помощью
    выражений. Выражение получает на входе строку редактора и выдаёт
    значение, соответствующее "весу" этой строки, для использования в
    сравнении с другими строками. Когда сравниваются две строки,
    строка с меньшим "весом" будеть помещена выше, чем другая, если
    не установлен переключатель #Реверс#.

    Выражения должны быть допустимыми на языке Lua выражениями,
    дающими в результате число или строку. Тем не менее, для
    использования большинства обычных операций сортировки знания
    языка Lua не требуется (см. примеры ниже). Если результаты
    вычислений - строки, они сравниваются либо с учётом регистра,
    либо без учёта, в зависимости от состояния переключателя
    #Учит.регистр#.

    Пользователь набирает выражения в одном или нескольких полях
    #Выраж.# диалога. Каждое из этих 3-х полей может быть разрешено
    или запрещено; когда используются несколько полей, верхние из них
    обладают более высоким приоритетом сортировки.

 #Переключатель "Учит.регистр"#
    Если в результате вычисления выражений получились величины типа
    string, они сравниваются между собой с помощью специальных функ-
    ций. Как правило, используется функция CompareStringW, в отдель-
    ном случае - функция wcscmp.
    Трёхпозиционный переключатель #Учит.регистр# управляет сравнением
    строк. Если переключатель находится в состоянии [ ] или [x], то
    плагин передаёт функции CompareStringW заранее предустановленные
    значения управляющих флагов.
    Если же переключатель находится в состоянии [?], то флаги задают-
    ся пользователем перед выражением, обрамлённые двоеточиями.
    Ниже следуют значения флагов:
        #c#   NORM_IGNORECASE
        #k#   NORM_IGNOREKANATYPE
        #n#   NORM_IGNORENONSPACE
        #s#   NORM_IGNORESYMBOLS
        #w#   NORM_IGNOREWIDTH
        #S#   SORT_STRINGSORT
        #1#   Использовать wcscmp вместо CompareStringW. Данный флаг
            не должен использоваться совместно с другими флагами.    
    Примеры задания флагов:
        #:cns:#
        #:1:#
        #::# (может быть опущено)
 
 #Переменные и функции#

    В выражениях могут использоваться следующие полезные переменные и функции:
       #a#     : текст строки, участвующей в сортировке
       #i#     : номер строки (1 = верхняя выделенная строка)
       #I#     : общее количество выделенных строк (константа)
       #C(n)#  : n-ая колонка #a#
       #L(s)#  : привести произвольную строку s к нижнему регистру
       #N(s)#  : преобразовать произвольную строку s в число
       #LC(n)# : привести n-ую колонку #a# к нижнему регистру;
               эквивалентно L(C(n))
       #NC(n)# : преобразовать n-ую колонку #a# в число; эквивалентно
               N(C(n))

    Пользователь может добавить свои переменные и функции (см. раздел
    #Загрузить файл# ниже).

 #Вертикальные блоки#

    Если блок текста выделен с помощью клавиши Alt ("вертикальные"
    блоки), то выражения в полях #Выраж.1# - #Выраж.3# будут
    оперировать выделенными частями строк, а не целыми строками.
    Однако то, что подлежит сортировке, зависит от состояния
    переключателя #Только выделенное#. Если он отмечен, то
    сортируются только выделенные части строк, иначе - строки
    целиком.

 #Шаблон колонки#

    "Колонка" - часть строки редактора, определяемая шаблоном
    ~регулярного выражения~@:RegExp@ Far в поле #Шаблон колонки#. По умолчанию,
    колонка - это последовательность непробельных символов. Нажмите
    кнопку #Сброс#, чтобы восстановить шаблон по умолчанию.

 #Загрузить файл#

    Иногда строки имеют сложную структуру и сортировка должна быть
    выполнена в соответствии с некоторыми сложными правилами.
    Утилита обрабатывает такие случаи, позволяя добавлять функции из
    скриптов Lua на диске. Такая функция разбирает соответствующую
    структуру и возвращает число или строку, представляющую собой
    "вес" введённых данных, используемых в сортировке.

    Введите полный путь до нужного скрипта в поле #Загрузить файл#
    диалога. Этот скрипт будет запущен перед началом сортировки.
    Глобальные функции, предоставляемые скриптом, могут
    использоваться в полях #Выраж.# диалога.

^\1FПростые примеры (знание языка Lua не требуется)\-

 #Пример 1:#   a          [ ] Реверс
    Сортировка строк по алфавиту, без учёта регистра.

 #Пример 2:#   a          [x] Реверс
    Сортировка строк по алфавиту, без учёта регистра, в обратном
    порядке.

 #Пример 3:#   a          [x] Учит.регистр
    Сортировка строк по алфавиту, с учётом регистра.

 #Пример 4:#   :1:a       [?] Учит.регистр
    Сортировка строк по алфавиту, с использованием функции wcscmp.

 #Пример 5:#   C(2)
    Сортировка строк в алфавитном порядке 2-й колонки.

 #Пример 6:#   N(a)
    Численная сортировка строк (содержащих по одному числу в строке)

 #Пример 7:#   NC(3)
    Сортировка строк в "числовом" порядке 3-й колонки.

 #Пример 8:#   C(2)      [ ] Реверс
             NC(1)     [x] Реверс
             C(4)      [x] Реверс   [x] Учит.регистр
    Сортировка строк:
       (a) в алфавитном порядке 2-й колонки - высокий приоритет;
       (b) в обратном числовом порядке 1-й колонки - низкий
           приоритет;
       (c) в обратном алфавитном порядке 4-й колонки с учётом
           регистра - низший приоритет;

 #Пример 9:#   NC(2) * NC(3)
    Сортировка строк согласно произведению чисел 2-й и 3-й колонок.

^\1FРасширенные примеры (требуется знание языка Lua)\-

 #Пример 10:#   a:sub(10,20)
    Сортировка строк в алфавитном порядке подстроки [10,20].

 #Пример 11:#  a:match"{.-}" or ""
    Сортировка строк в алфавитном порядке текста, обрамлённого скобками {}.

 #Пример 12:#  a:len()
    Сортировка строк в соответствии с их длиной.

 #Пример 13:#  a:reverse()
    Сортировка строк в алфавитном порядке их зеркального отображения.

 #Пример 14:#  math.max(NC(1), NC(2), NC(3))
    Сортировка строк в соответствии с максимальным значением их первых трёх
колонок.

 #Пример 15:#  -i
    Изменить порядок строк в блоке на обратный.

 #Пример 16:#  i%2==0 and i-1 or i+1
    Переставить местами строки в каждой паре строк блока.

 #Пример 17:#  i%2==1 and i-I or i
    Поместить сначала все строки с нечётными номерами строк, затем все строки
с чётными номерами.

 ~Содержание~@Contents@

@PluginConfig
$ #Диалог конфигурации плагина#
 #[x] Перезагружать главный скрипт#

    Главный скрипт (или скрипт по умолчанию) - это файл, который содержит
Lua-обработчики экспортируемых плагином функций. Этот скрипт запускается,
когда FAR вызывает #SetStartupInfoW#, позволяя плагину получить доступ к
обработчикам.
    Когда выбрана эта опция, скрипт по умолчанию будет также выполняться
тогда, когда FAR вызывает функцию #OpenW#. Это удобно, когда требуется
выполнять отладку главного скрипта.

 #[x] Перезагружать по 'require'#

    При первой загрузке некоторой библиотеки с помощью 'require',
она загружается с диска в память. Последующие вызовы 'require' для этой
библиотеки возвращают её уже из памяти. Когда выбрана эта опция, библиотеки
всегда будут загружаться с диска (это может потребоваться для отладки библиотек).

 #[x] Режим 'strict'#

    Когда выбрана эта опция, плагин не позволит получить доступ к "необъявленным"
глобальным переменным.

 #[x] Возвращаться в главное меню#

    Когда утилита, вызванная через главное меню, закончит выполнение,
главное меню появится снова.

 ~Содержание~@Contents@

@ReloadUserFile
$ #Перезагрузка пользовательского файла#
    Если в папке плагина есть файл #_usermenu.lua#, он будет запущен на исполнение.
Перезагрузка _usermenu.lua может потребоваться, если один или несколько файлов,
содержащих обработчики событий, были изменены пользователем.

    Подробности по файлу _usermenu.lua и обработчикам событий приведены в
руководстве.

 ~Содержание~@Contents@

@MReplace
$ #Многострочная замена#
^#- Описание -#
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
 Если опция Регулярное Выражение включена, то образец поиска интерпретируется
как ~регулярное выражение~@:RegExp@, иначе - как обычный текст.

 #Заменить на#
 Образец замены.
 Если включена опция Регулярное Выражение, то:
    *  #$1#-#$9#, #$A#-#$Z# используются для обозначения частичных
       совпадений (групп). #$0# обозначает полное совпадение.
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
       #\xhhhh#    символ с шестнадцатиричным кодом #hhhh#

 #Учит. регистр#
 Включает чувствительность к регистру символов.

 #Целые слова#
 Искать только целые слова.

 #Регул. выражение#
 Если включено, то строка поиска интерпретируется как
~регулярное выражение~@:RegExp@, иначе - как простой текст.

 #Игнор. пробелы#
 Все буквальные пробелы в образце поиска удаляются перед началом операции.
Предварите пробел символом #\#, если пробел является интегральной частью
образца поиска.

 #Файл как строка#
 Если включено, то #.# (точка) в регулярном выражении находит любой символ,
включая \r и \n.
 
 #Многострочный режим#
 Если включено, то #^# и #$# в регулярном выражении находят соответственно
начало и конец каждой строки.

 ~Содержание~@Contents@
