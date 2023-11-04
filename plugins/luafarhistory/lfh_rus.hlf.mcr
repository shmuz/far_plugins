﻿.Language=Russian,Russian (Русский)
.PluginContents=LuaFAR History
.Options CtrlColorChar=\

@Contents
$ #LuaFAR History (версия #{VER_STRING}) - Содержание -#
 #LuaFAR History# - это плагин, предназначенный для отображения
историй команд, папок и редактирования/просмотра файлов.

 При показе списка истории, его пункты могут быть отфильтрованы при помощи
ввода пользователем шаблона фильтрации, отображаемого в заголовке окна.
Имеется 4 переключаемые метода фильтрации:

 - Шаблоны DOS (#*# и #?#)
 - Шаблоны Lua
 - Регулярные выражения FAR
 - Простой текст

 #Клавиатурное управление:#

 \3BВсе истории\-
   #F5#                 Переключить метод фильтрации.
   #F6#                 Для пунктов меню с текстом, не умещающимся
                      в ширину окна: переключать троеточие между
                      позициями, соответствующими (0,1,2,3)/3 ширины.
   #F7#                 Показать текущий пункт в окошке сообщения.
   #F8#                 Включить/выключить "xlat-фильтр"
                      (поиск по двум шаблонам одновременно).
   #F9#                 Установить фильтр в последнее использовавшееся значение.
   #Ctrl-Enter#         Скопировать текущий пункт в командную строку.
   #Ctrl-C#, #Ctrl-Ins#   Скопировать текущий пункт в буфер обмена.
   #Ctrl-Shift-Ins#     Скопировать все отфильтрованные пункты в буфер обмена.
   #Shift-Del#          Удалить текущий пункт из истории.
   #Ctrl-Del#           Удалить все отфильтрованные пункты из истории.
   #Del#                Очистить фильтр.
   #Ctrl-V#, #Shift-Ins#  Установить фильтр значением строки из буфера обмена.
   #Ctrl-Alt-X#         Применить преобразование XLat в фильтре и
                      одновременно переключить раскладку клавиатуры.
   #Ctrl-I#             Инвертировать порядок сортировки.
   #Ins#                Пометить текущий пункт (не будет удаляться по Ctrl-Del и Ctrl-F8)

 \3BИстория команд\-
   #Enter#              Выполнить.
   #Shift-Enter#        Выполнить в новом окне.

 \3BИстория просмотра/редактирования\-
   #F3#                 Смотреть.
   #F4#                 Редактировать.
   #Alt-F3#             Смотреть модально, вернуться в меню.
   #Alt-F4#             Редактировать модально, вернуться в меню.
   #Enter#              Смотреть или редактировать.
   #Shift-Enter#        Смотреть или редактировать (положение в меню
                      не изменяется).
   #Ctrl-PgUp#          Перейти к файлу (на активной панели).
   #Ctrl-PgDn#          Перейти к файлу (на активной панели) и открыть его.
   #Ctrl-F8#            Удалить несуществующие пункты

 \3BИстория папок\-
   #Enter#              Перейти к папке (на активной панели).
   #Shift-Enter#        Перейти к папке (на пассивной панели).
   #Ctrl-F8#            Удалить несуществующие пункты

 \3BНайти файл\-
   #Enter#              Позиционировать курсор на файл в активной панели.
   #F3#                 Смотреть.
   #F4#                 Редактировать.
   #Alt-F3#             Смотреть модально, вернуться в меню.
   #Alt-F4#             Редактировать модально, вернуться в меню.

 Специальные темы:
     ~Диалог конфигурации плагина~@PluginConfig@

@PluginConfig
$ #Диалог конфигурации плагина#
 \3BМаксимальный размер истории\-
   Максимальное количество записей:
   #Команды#            в истории команд
   #Ред./Просмотр#      в истории редактирования/просмотра
   #Папки#              в истории папок

 \3BСвойства окна\-
   #[x] Динамический размер#
       Когда выбрана эта опция, окно истории будет менять размер
       в зависимости от количества и содержимого записей в истории.
   #[x] Центрировать#
       Когда выбрана эта опция, окно истории будет отображено в центре
       окна FAR.

 \3BПрочие свойства\-
   #Формат даты#
       Выбор формата дат, показываемых в сепараторах.
   #[x] Сохранять текущий элемент#
       Сохранять текущий элемент выделенным (если возможно) при изменении
       значения фильтра.

 ~Содержание~@Contents@

@ConfigMenu
$ #Меню настроек плагина#
  Меню позволяет выбрать для последующей настройки:
  #-# ~Диалог конфигурации плагина~@PluginConfig@
  #-# Каждый из трёх списков исключений

 ~Содержание~@Contents@

@ExclusionMenu
$ #Меню исключений#
  #Ins#    Добавить новый шаблон исключения в список
  #Del#    Удалить шаблон исключения из списка
  #F4#     Редактировать шаблон исключения

 ~Содержание~@Contents@

@ExclusionDialog
$ #Диалог редактирования шаблона исключения#
  Здесь можно добавить или отредактировать шаблон (регулярное выражение FAR).
  Если элемент истории соответствует данному шаблону, он не будет добавлен в историю.
  На существующие элементы истории этот механизм не влияет.

 ~Содержание~@Contents@
