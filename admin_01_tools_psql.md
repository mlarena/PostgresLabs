## **Использование psql**

### **Лабораторная работа: Основы подключения, навигации в psql**

**Задача:** Подключиться к базе данных PostgreSQL с помощью утилиты `psql`, проверить параметры текущего подключения и изучить список доступных баз данных.

**Решение:**
```bash
# 1. Подключение к БД (параметры по умолчанию)
psql
psql -h localhost -U postgres -d postgres

# 2. Проверка информации о подключении (внутри psql)
\conninfo
# Результат: You are connected to database "student" as user "student" via socket in "/var/run/postgresql" at port "5432".

# 3. Просмотр списка всех баз данных
\l

# 4. Подробный просмотр списка баз данных
\l+
```

---

### **Лабораторная работа 2: Форматирование вывода запросов**

**Задача:** Настроить различные форматы вывода результатов запросов (выравнивание, расширенный режим, отключение заголовков).

**Описание:**

\x — переключение расширенного формата
\x — переключить режим (вкл/выкл)
\x on — включить расширенный формат
\x off — выключить расширенный формат

\t — переключение отображения заголовков
\t — переключить режим
\t on — скрыть заголовки
\t off — показать заголовки

\a — переключение формата выравнивания
\a — переключить режим
\a on — невыровненный формат
\a off — выровненный формат

**Решение:**
```sql
-- 1. Исходный запрос (выравнивание включено)
SELECT schemaname, tablename FROM pg_tables LIMIT 3;

-- 2. Отключение выравнивания и заголовков
\t
\a
\pset fieldsep ' '
SELECT schemaname, tablename FROM pg_tables LIMIT 3;

-- 3. Включение расширенного формата
\x
SELECT * FROM pg_tables WHERE tablename = 'pg_class';

-- 4. Возврат к стандартным настройкам
\x
\t
\a
```

---

### **Лабораторная работа 3: Взаимодействие с операционной системой**

**Задача:** Научиться выполнять команды ОС из psql, сохранять результаты запросов в файлы и выполнять SQL-скрипты.

**Решение:**
```sql
-- 1. Выполнение команды ОС
\! pwd

-- 2. Сохранение результата запроса в файл
\o /tmp/tables_list.txt
SELECT tablename FROM pg_tables LIMIT 5;
\o

-- 3. Просмотр содержимого файла
\! cat /tmp/tables_list.txt

-- 4. Выполнение SQL-скрипта из файла
\i /tmp/my_script.sql
```

---

### **Лабораторная работа 4: Работа с переменными psql**

**Задача:** Освоить использование переменных psql, сохранение результатов запросов в переменные и применение условных конструкций.

**Решение:**
```sql
-- 1. Установка переменной
\set db_name 'student'

-- 2. Использование переменной
\echo Current database: :db_name

-- 3. Сохранение результата запроса в переменную
SELECT current_user AS current_user \gset
\echo Connected as :current_user

-- 4. Условные конструкции
\if :{?db_name}
    \echo Database variable is set to: :db_name
\else
    \echo Database variable is not set
\endif
```

---

### **Лабораторная работа 5: Настройка рабочей среды psql**

**Задача:** Настроить файл `.psqlrc` для персонализации рабочей среды - изменить приглашение, настроить постраничный просмотр и включить timing.

**Решение:**
```bash
# Создание файла конфигурации .psqlrc
cat > ~/.psqlrc << EOF
-- Настройка приглашения
\set PROMPT1 '%n@%/%R%x%# '
\set PROMPT2 '%n@%/%R%x%# '

-- Настройка постраничного просмотра
\setenv PSQL_PAGER 'less -XS'

-- Включение отображения времени выполнения
\timing on

-- Установка переменной для часто используемого запроса
\set top5 "SELECT tablename, pg_total_relation_size(schemaname||'.'||tablename) AS bytes FROM pg_tables ORDER BY bytes DESC LIMIT 5;"
EOF
```

После создания файла перезапустите psql для применения настроек.

---

### **Дополнительные задачи**

### **Задача 6: Автоматизация создания отчетов**

**Задача:** Создать скрипт, который автоматически генерирует отчет о самых больших таблицах в базе данных и сохраняет его в файл с timestamp.

**Решение:**
```sql
-- Создаем переменную с именем файла отчета
\set report_file '/tmp/db_report_' `date +%Y%m%d_%H%M%S` '.txt'

-- Сохраняем отчет в файл
\o :report_file
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
\o

\echo Report saved to: :report_file
\! cat :report_file
```

### **Задача 7: Динамическое выполнение SQL**

**Задача:** Используя команду `\gexec`, динамически сгенерировать и выполнить SQL-запросы для получения количества записей в каждой таблице из схемы `pg_catalog`.

**Решение:**
```sql
-- Генерируем и сразу выполняем запросы подсчета записей
SELECT format('SELECT %L as table_name, count(*) as record_count FROM %I.%I;', 
              tablename, 
              schemaname, 
              tablename)
FROM pg_tables 
WHERE schemaname = 'pg_catalog' 
LIMIT 5
\gexec
```


### **Задача 8: Обработка ошибок в транзакциях (исправленная)**

**Задача:** Исследовать различные сценарии обработки ошибок в транзакциях с включенной и выключенной опцией `ON_ERROR_ROLLBACK`.

**Решение:**
```sql
-- 1. Создаем тестовую базу данных для экспериментов
\! psql -c "CREATE DATABASE test_transactions;"
\c test_transactions

-- 2. Сценарий с выключенной опцией (по умолчанию)
\set ON_ERROR_ROLLBACK off

BEGIN;
CREATE TABLE test_table (id serial primary key, name text);
-- Специально делаем ошибку в синтаксисе
INSERTINTO test_table (name) VALUES ('test');
-- Попытка продолжить работу (не сработает)
INSERT INTO test_table (name) VALUES ('test2');
COMMIT; -- Фактически выполнится ROLLBACK

-- Проверяем - таблица не должна существовать
\dt test_table

-- 3. Сценарий с включенной опцией
\set ON_ERROR_ROLLBACK on

BEGIN;
CREATE TABLE test_table2 (id serial primary key, name text);
-- Снова делаем ошибку
INSERTINTO test_table2 (name) VALUES ('test');
-- Теперь можно продолжить работу
INSERT INTO test_table2 (name) VALUES ('test2');
COMMIT; -- Транзакция завершится успешно

-- Проверяем результат
SELECT * FROM test_table2;

-- Убираем за собой
\c postgres
\! psql -c "DROP DATABASE test_transactions;"
```

---

### **Упражнение 9: Автодополнение и история команд**

**Задача:** Освоить использование автодополнения Tab и работу с историей команд в psql.

**Решение:**
```sql
-- 1. Использование автодополнения
-- Наберите \d и нажмите Tab дважды для просмотра всех команд начинающихся с \d
\d

-- 2. Наберите SE и нажмите Tab для автодополнения до SELECT
SE[TAB]

-- 3. Работа с историей команд
-- Вывести последние 10 команд из истории
\s 10

-- 4. Сохранить историю в файл
\s /tmp/psql_history.txt

-- 5. Выполнить команду из истории по номеру
-- Сначала посмотрим историю
\s
-- Затем выполним команду под номером N
\! psql -c "SELECT version();"  -- запомним номер этой команды в истории
```

### **Упражнение 10: Мета-команды для работы с системным каталогом**

**Задача:** Изучить различные варианты команды `\d` для получения информации об объектах базы данных.

**Решение:**
```sql
-- 1. Подключимся к базе данных и исследуем системные объекты
\c student

-- 2. Просмотр всех доступных схем
\dn

-- 3. Просмотр всех таблиц в текущей базе данных
\dt

-- 4. Просмотр таблиц в определенной схеме
\dt pg_catalog.*

-- 5. Детальная информация о конкретной таблице
\d pg_tables

-- 6. Просмотр индексов
\di

-- 7. Просмотр представлений (views)
\dv

-- 8. Просмотр функций
\df

-- 9. Просмотр последовательностей (sequences)
\ds

-- 10. Просмотр прав доступа
\dp pg_tables

-- Показать справку по всем командам psql
\?	

-- Открыть редактор для написания/редактирования запроса
\e	

-- \i file.sql	Выполнить SQL-команды из файла
\i file.sql

-- \o file.txt	Перенаправить вывод в файл
\o file.txt


```

### **Упражнение 11: Работа с шаблонами и фильтрацией в мета-командах**

**Задача:** Научиться использовать шаблоны для фильтрации вывода мета-команд.

**Решение:**
```sql
-- 1. Поиск всех таблиц, начинающихся на 'pg_'
\dt pg_*

-- 2. Поиск всех объектов в схеме pg_catalog, содержащих 'stat'
\dt pg_catalog.*stat*

-- 3. Поиск функций, содержащих 'count'
\df *count*

-- 4. Просмотр системных таблиц информации о таблицах
\dt pg_catalog.pg_*table

-- 5. Поиск представлений, начинающихся на 'pg_stat'
\dv pg_stat*

-- 6. Комбинированный поиск с разными типами объектов
-- Создадим несколько тестовых объектов для демонстрации
CREATE TABLE test_users (id serial, name text);
CREATE VIEW test_users_view AS SELECT * FROM test_users;
CREATE FUNCTION test_func() RETURNS int AS 'SELECT 1' LANGUAGE sql;

-- Поиск всех созданных тестовых объектов
\d test_*

-- 7. Удаление тестовых объектов
DROP VIEW test_users_view;
DROP FUNCTION test_func();
DROP TABLE test_users;
```

### **Упражнение 12: Форматирование вывода с помощью \pset**

**Задача:** Освоить различные варианты форматирования вывода с помощью команды `\pset`.

**Решение:**
```sql
-- 1. Текущие настройки форматирования
\pset

-- 2. Изменение стиля границ таблиц
\pset border 0
SELECT * FROM pg_tables LIMIT 3;

\pset border 1
SELECT * FROM pg_tables LIMIT 3;

\pset border 2
SELECT * FROM pg_tables LIMIT 3;

-- 3. Изменение формата вывода на HTML
\pset format html
\o /tmp/output.html
SELECT * FROM pg_tables LIMIT 3;
\o
\! echo "HTML output saved to /tmp/output.html"

-- 4. Возврат к выровненному формату
\pset format aligned

-- 5. Настройка отображения NULL значений
\pset null '(NULL)'
SELECT schemaname, tablename, tablespace FROM pg_tables WHERE tablespace IS NULL LIMIT 3;

-- 6. Настройка разделителя полей для CSV
\pset format csv
\pset fieldsep ';'
\o /tmp/tables.csv
SELECT schemaname, tablename FROM pg_tables LIMIT 5;
\o
\! head -n 3 /tmp/tables.csv

-- 7. Возврат к стандартным настройкам
\pset format aligned
\pset border 2
\pset null ''
```

### **Упражнение 13: Создание сложных скриптов с переменными**

**Задача:** Создать многоразовый скрипт с использованием переменных и условных конструкций.

**Решение:**
```sql
-- 1. Создаем скрипт для анализа размера таблиц
\set analysis_script '
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||\'.\'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||\'.\'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||\'.\'||tablename) - 
                   pg_relation_size(schemaname||\'.\'||tablename)) as indexes_size
FROM pg_tables 
WHERE schemaname NOT LIKE \'pg_%\' AND schemaname != \'information_schema\'
ORDER BY pg_total_relation_size(schemaname||\'.\'||tablename) DESC
LIMIT 10;
'

-- 2. Выполняем скрипт с разными настройками форматирования
\pset title 'Top 10 Largest Tables'
:analysis_script

-- 3. Создаем условный скрипт для разных окружений
\set env 'production'

\if :{?env}
    \if :env = 'production'
        \echo 'Running in PRODUCTION mode - limited output'
        SELECT schemaname, tablename FROM pg_tables LIMIT 3;
    \else
        \echo 'Running in DEVELOPMENT mode - full output'
        SELECT schemaname, tablename FROM pg_tables LIMIT 10;
    \endif
\else
    \echo 'Environment not set'
\endif
```

---

### **Упражнение 14: Создание отчета о состоянии базы данных**

**Задача:** Создать комплексный скрипт для генерации отчета о состоянии базы данных, который включает информацию о размерах объектов, активности и настройках.

**Решение:**
```sql
-- 1. Создаем переменные для отчета
\set report_title 'Database Health Report'
\set report_date `date "+%Y-%m-%d %H:%M:%S"`
\set output_file '/tmp/db_health_report_' `date +%Y%m%d_%H%M%S` '.txt'

-- 2. Начинаем запись в файл отчета
\o :output_file

-- 3. Заголовок отчета
\echo === :report_title ===
\echo Generated at: :report_date
\echo Database: :DBNAME
\echo User: :USER
\echo =====================================
\echo

-- 4. Размеры баз данных
\echo 1. DATABASE SIZES:
\echo ------------------
SELECT 
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

\echo

-- 5. Крупнейшие таблицы
\echo 2. LARGEST TABLES:
\echo ------------------
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                  pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;

\echo

-- 6. Активность подключений
\echo 3. ACTIVE CONNECTIONS:
\echo ----------------------
SELECT 
    datname,
    usename,
    client_addr,
    state,
    query_start
FROM pg_stat_activity 
WHERE state IS NOT NULL;

\echo

-- 7. Завершаем запись в файл
\o

-- 8. Информируем пользователя
\echo Report saved to: :output_file
\echo

-- 9. Показываем начало отчета для preview
\! head -n 20 :output_file
```

---

### **Упражнение 15: Автоматизация рутинных задач с помощью функций psql**

**Задача:** Создать набор удобных функций-оберток для часто выполняемых административных задач.

**Решение:**
```sql
-- 1. Функция для быстрой проверки размера таблицы
\set size_of '
\set table_name :1
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||\'.\'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||\'.\'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||\'.\'||tablename) - 
                  pg_relation_size(schemaname||\'.\'||tablename)) as index_size
FROM pg_tables 
WHERE tablename = \':table_name\';
'

-- 2. Функция для поиска таблиц по шаблону имени
\set find_table '
\set pattern :1
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE tablename LIKE \'%:pattern%\'
ORDER BY schemaname, tablename;
'

-- 3. Функция для проверки блокировок
\set check_locks '
SELECT 
    locktype,
    relation::regclass,
    mode,
    granted
FROM pg_locks 
WHERE relation IS NOT NULL
LIMIT 10;
'

-- 4. Функция для просмотра последних запросов
\set recent_queries '
SELECT 
    usename,
    query,
    query_start
FROM pg_stat_activity 
WHERE state = \'active\' 
AND query != \'<IDLE>\'
ORDER BY query_start DESC
LIMIT 5;
'

-- 5. Демонстрация использования функций
\echo "1. Проверка размера таблицы pg_class:"
:size_of 'pg_class'

\echo
\echo "2. Поиск таблиц с 'stat' в имени:"
:find_table 'stat'

\echo
\echo "3. Проверка текущих блокировок:"
:check_locks

\echo
\echo "4. Последние активные запросы:"
:recent_queries

-- 6. Создаем универсальную функцию-помощник
\set help_admin '
\echo "Доступные административные команды:"
\echo "  :size_of 'table_name'     - размер таблицы"
\echo "  :find_table 'pattern'     - поиск таблиц по шаблону"
\echo "  :check_locks              - проверка блокировок"
\echo "  :recent_queries           - последние запросы"
'

-- 7. Сохраняем функции в .psqlrc для постоянного использования
\set save_functions 'echo "\n-- Admin functions\n\set size_of '\''\\set table_name :1\nSELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||\\'\\'.\\'\\'||tablename)) as total_size\nFROM pg_tables WHERE tablename = \\'\\':table_name\\'\\';'\''\n\n\set find_table '\''\\set pattern :1\nSELECT schemaname, tablename, tableowner\nFROM pg_tables WHERE tablename LIKE \\'\\'%:pattern%\\'\\'\nORDER BY schemaname, tablename;'\''\n\n\set check_locks '\''SELECT locktype, relation::regclass, mode, granted\nFROM pg_locks WHERE relation IS NOT NULL LIMIT 10;'\''\n\n\set recent_queries '\''SELECT usename, query, query_start\nFROM pg_stat_activity WHERE state = \\'\\'active\\'\\' AND query != \\'\\'<IDLE>\\'\\'\nORDER BY query_start DESC LIMIT 5;'\''" >> ~/.psqlrc'

\echo
\echo "Для сохранения функций выполните:"
\echo :save_functions
```
