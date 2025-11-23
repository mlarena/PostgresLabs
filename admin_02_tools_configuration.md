## **Конфигурирование сервера**

---

### **Лабораторная работа 1: Изучение основных параметров конфигурации**

**Задача:** Изучить текущие параметры конфигурации сервера и найти расположение основных конфигурационных файлов.

**Решение:**
```sql
-- 1. Найти расположение основного конфигурационного файла
SHOW config_file;

-- 2. Найти каталог данных (PGDATA)
SHOW data_directory;

-- 3. Просмотреть параметры аутентификации
SHOW hba_file;
SHOW ident_file;

-- 4. Посмотреть текущие настройки подключений
SHOW max_connections;
SHOW port;
SHOW listen_addresses;
```

---

### **Лабораторная работа 2: Работа с представлением pg_settings**

**Задача:** Изучить структуру представления pg_settings и найти параметры, требующие перезапуска сервера.

**Решение:**
```sql
-- 1. Изучить структуру представления
\d pg_settings

-- 2. Найти параметры, требующие перезапуска сервера
SELECT name, setting, unit, context 
FROM pg_settings 
WHERE context = 'postmaster'
LIMIT 10;

-- 3. Параметры, которые можно изменить в сеансе
SELECT name, setting, unit, context 
FROM pg_settings 
WHERE context IN ('user', 'superuser')
LIMIT 10;
```

---

### **Лабораторная работа 3: Анализ файлов конфигурации через pg_file_settings**

**Задача:** Изучить, какие параметры установлены в конфигурационных файлах и какие из них применены.

**Решение:**
```sql
-- 1. Просмотреть все настройки из конфигурационных файлов
SELECT sourceline, sourcefile, name, setting, applied, error
FROM pg_file_settings
LIMIT 15;

-- 2. Найти непримененные настройки
SELECT sourceline, sourcefile, name, setting, error
FROM pg_file_settings 
WHERE applied = false;

-- 3. Посмотреть дополнительные подключаемые файлы
SELECT DISTINCT sourcefile 
FROM pg_file_settings 
WHERE sourcefile LIKE '%conf.d%';
```

---

### **Лабораторная работа 4: Изменение параметров через дополнительные конфигурационные файлы**

**Задача:** Создать дополнительный конфигурационный файл и изменить параметр work_mem.

**Решение:**
```bash
# 1. Создаем дополнительный конфигурационный файл
sudo bash -c 'echo "work_mem = 16MB" > /etc/postgresql/16/main/conf.d/work_mem.conf'

# 2. Проверяем создание файла
sudo cat /etc/postgresql/16/main/conf.d/work_mem.conf
```

```sql
-- 3. Перечитываем конфигурацию
SELECT pg_reload_conf();

-- 4. Проверяем применение параметра
SELECT name, setting, unit, sourcefile, sourceline
FROM pg_settings 
WHERE name = 'work_mem';
```

---

### **Лабораторная работа 5: Работа с командой ALTER SYSTEM**

**Задача:** Использовать команду ALTER SYSTEM для изменения параметров через postgresql.auto.conf.

**Решение:**
```sql
-- 1. Устанавливаем параметр через ALTER SYSTEM
ALTER SYSTEM SET work_mem = '24MB';

-- 2. Просматриваем содержимое postgresql.auto.conf
SELECT pg_read_file('postgresql.auto.conf');

-- 3. Перечитываем конфигурацию
SELECT pg_reload_conf();

-- 4. Проверяем применение параметра
SELECT name, setting, unit, sourcefile, sourceline
FROM pg_settings 
WHERE name = 'work_mem';

-- 5. Сбрасываем параметр
ALTER SYSTEM RESET work_mem;
SELECT pg_reload_conf();
```

---

### **Лабораторная работа 6: Управление параметрами в текущем сеансе**

**Задача:** Научиться изменять параметры на уровне сеанса и транзакции.

**Решение:**
```sql
-- 1. Изменяем параметр на уровне сеанса
SET work_mem = '32MB';
SHOW work_mem;

-- 2. Используем функцию set_config
SELECT set_config('work_mem', '48MB', false);
SHOW work_mem;

-- 3. Работа с параметрами в транзакции
BEGIN;
SET LOCAL work_mem = '64MB';
SHOW work_mem;
COMMIT;

-- 4. Проверяем значение после транзакции
SHOW work_mem;

-- 5. Сбрасываем параметр
RESET work_mem;
```

---

### **Лабораторная работа 7: Обработка ошибок в конфигурационных файлах**

**Задача:** Создать ситуацию с ошибкой в конфигурационном файле и научиться ее диагностировать.

**Решение:**
```bash
# 1. Создаем файл с ошибкой (неправильное значение)
sudo bash -c 'echo "shared_buffers = invalid_value" > /etc/postgresql/16/main/conf.d/error.conf'
```

```sql
-- 2. Пытаемся перечитать конфигурацию
SELECT pg_reload_conf();

-- 3. Проверяем ошибки в pg_file_settings
SELECT sourceline, sourcefile, name, setting, applied, error
FROM pg_file_settings 
WHERE error IS NOT NULL;

-- 4. Исправляем ошибку через ALTER SYSTEM (альтернативный способ)
ALTER SYSTEM SET shared_buffers = '256MB';
SELECT pg_reload_conf();

-- 5. Удаляем проблемный файл
\! sudo rm /etc/postgresql/16/main/conf.d/error.conf
```

---

### **Лабораторная работа 8: Работа с пользовательскими параметрами**

**Задача:** Создать и использовать пользовательские параметры для хранения настроек приложения.

**Решение:**
```sql
-- 1. Создаем пользовательский параметр
SET app.theme = 'dark';
SET app.language = 'ru';

-- 2. Читаем пользовательские параметры
SELECT current_setting('app.theme');
SELECT current_setting('app.language');

-- 3. Безопасное чтение с обработкой отсутствия параметра
SELECT current_setting('app.nonexistent', true);

-- 4. Использование в запросах
SELECT 
    current_setting('app.theme') as theme,
    current_setting('app.language') as language;

-- 5. Установка через функцию с проверкой
SELECT set_config('app.version', '1.0.0', false);
```

---

### **Лабораторная работа 9: Анализ приоритетов конфигурационных параметров**

**Задача:** Исследовать приоритеты различных методов установки параметров.

**Решение:**
```sql
-- 1. Устанавливаем параметр разными способами
ALTER SYSTEM SET work_mem = '8MB';
SELECT pg_reload_conf();

-- 2. Проверяем текущее значение
SHOW work_mem;

-- 3. Изменяем в сеансе
SET work_mem = '16MB';
SHOW work_mem;

-- 4. Изменяем в транзакции
BEGIN;
SET LOCAL work_mem = '32MB';
SHOW work_mem;
COMMIT;

-- 5. Анализируем источники значений
SELECT name, setting, source, sourcefile, sourceline
FROM pg_settings 
WHERE name = 'work_mem';
```

---

### **Лабораторная работа 10: Мониторинг изменений конфигурации**

**Задача:** Создать систему мониторинга изменений важных параметров конфигурации.

**Решение:**
```sql
-- 1. Создаем таблицу для отслеживания изменений
CREATE TABLE config_changes (
    id serial PRIMARY KEY,
    parameter_name text,
    old_value text,
    new_value text,
    change_time timestamptz DEFAULT now(),
    changed_by text DEFAULT current_user
);

-- 2. Функция для отслеживания изменений work_mem
CREATE OR REPLACE FUNCTION track_work_mem_change()
RETURNS void AS $$
DECLARE
    current_val text;
    last_val text;
BEGIN
    SELECT setting INTO current_val FROM pg_settings WHERE name = 'work_mem';
    SELECT new_value INTO last_val FROM config_changes 
    WHERE parameter_name = 'work_mem' 
    ORDER BY change_time DESC LIMIT 1;
    
    IF last_val IS NULL OR last_val != current_val THEN
        INSERT INTO config_changes (parameter_name, old_value, new_value)
        VALUES ('work_mem', last_val, current_val);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. Проверяем работу
SELECT track_work_mem_change();
SELECT * FROM config_changes;
```

---

### **Лабораторная работа 11: Оптимизация параметров памяти**

**Задача:** Проанализировать и оптимизировать параметры памяти для текущей системы.

**Решение:**
```sql
-- 1. Анализируем текущие настройки памяти
SELECT 
    name,
    setting,
    unit,
    category,
    short_desc
FROM pg_settings 
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size')
ORDER BY name;

-- 2. Рассчитываем рекомендуемые значения на основе размера ОЗУ
SELECT 
    'shared_buffers' as parameter,
    setting as current_value,
    '25% of RAM' as recommendation,
    (SELECT setting::numeric * 0.25 
     FROM pg_settings WHERE name = 'shared_buffers') as suggested_value
FROM pg_settings 
WHERE name = 'shared_buffers';

-- 3. Устанавливаем оптимизированные значения (если нужно)
-- ALTER SYSTEM SET shared_buffers = '1GB';
-- SELECT pg_reload_conf();
```

---

### **Лабораторная работа 12: Управление параметрами логирования**

**Задача:** Настроить параметры логирования для лучшей диагностики проблем.

**Решение:**
```sql
-- 1. Анализируем текущие настройки логирования
SELECT name, setting, short_desc
FROM pg_settings 
WHERE name LIKE 'log%' 
   OR name LIKE '%logging%'
ORDER BY name;

-- 2. Настраиваем расширенное логирование через ALTER SYSTEM
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = 'on';
ALTER SYSTEM SET log_line_prefix = '%m [%p] %q%u@%d ';

-- 3. Перечитываем конфигурацию
SELECT pg_reload_conf();

-- 4. Проверяем применение настроек
SELECT name, setting 
FROM pg_settings 
WHERE name IN ('log_statement', 'log_duration', 'log_line_prefix');

-- 5. Возвращаем настройки по умолчанию (после тестирования)
ALTER SYSTEM RESET log_statement;
ALTER SYSTEM RESET log_duration;
SELECT pg_reload_conf();
```

---

### **Лабораторная работа 13: Создание отчета о конфигурации**

**Задача:** Создать комплексный отчет о текущей конфигурации сервера.

**Решение:**
```sql
-- 1. Создаем представление для отчета
CREATE VIEW config_report AS
SELECT 
    category,
    name as parameter,
    setting as current_value,
    unit,
    context,
    source,
    short_desc as description
FROM pg_settings 
WHERE source IS NOT NULL 
   AND source != 'default'
ORDER BY category, name;

-- 2. Генерируем отчет
SELECT * FROM config_report;

-- 3. Детальный отчет по измененным параметрам
SELECT 
    name,
    setting as current_value,
    boot_val as default_value,
    reset_val as session_default,
    source,
    sourcefile,
    sourceline,
    pending_restart
FROM pg_settings 
WHERE source != 'default' 
   OR setting != boot_val
ORDER BY source, name;

-- 4. Параметры, требующие перезапуска
SELECT name, setting, pending_restart
FROM pg_settings 
WHERE pending_restart = true;
```

---

### **Лабораторная работа 14: Автоматизация управления конфигурацией**

**Задача:** Создать набор функций для автоматизации управления конфигурацией.

**Решение:**
```sql
-- 1. Функция для безопасного изменения параметров
CREATE OR REPLACE FUNCTION safe_alter_system(param_name text, param_value text)
RETURNS text AS $$
BEGIN
    EXECUTE format('ALTER SYSTEM SET %I TO %L', param_name, param_value);
    PERFORM pg_reload_conf();
    
    RETURN format('Parameter %s set to %s', param_name, param_value);
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('ERROR: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- 2. Функция для сброса параметра
CREATE OR REPLACE FUNCTION reset_parameter(param_name text)
RETURNS text AS $$
BEGIN
    EXECUTE format('ALTER SYSTEM RESET %I', param_name);
    PERFORM pg_reload_conf();
    
    RETURN format('Parameter %s reset to default', param_name);
END;
$$ LANGUAGE plpgsql;

-- 3. Тестируем функции
SELECT safe_alter_system('work_mem', '32MB');
SELECT reset_parameter('work_mem');
```

---

### **Лабораторная работа 15: Диагностика проблем с конфигурацией**

**Задача:** Создать инструменты для диагностики и решения проблем с конфигурацией.

**Решение:**
```sql
-- 1. Функция для проверки корректности конфигурации
CREATE OR REPLACE FUNCTION validate_configuration()
RETURNS TABLE(parameter text, status text, message text) AS $$
BEGIN
    -- Проверяем параметры с ошибками
    RETURN QUERY
    SELECT 
        fs.name::text,
        'ERROR'::text,
        fs.error::text
    FROM pg_file_settings fs
    WHERE fs.error IS NOT NULL;

    -- Проверяем параметры, требующие перезапуска
    RETURN QUERY
    SELECT 
        ps.name::text,
        'RESTART REQUIRED'::text,
        'Parameter changed in config file but requires restart'::text
    FROM pg_settings ps
    WHERE ps.pending_restart = true;

    -- Проверяем конфликтующие настройки
    RETURN QUERY
    SELECT 
        'work_mem vs shared_buffers'::text,
        'WARNING'::text,
        'Check memory allocation between parameters'::text
    WHERE (SELECT setting::numeric FROM pg_settings WHERE name = 'work_mem') > 
          (SELECT setting::numeric FROM pg_settings WHERE name = 'shared_buffers') * 0.1;
END;
$$ LANGUAGE plpgsql;

-- 2. Запускаем диагностику
SELECT * FROM validate_configuration();

-- 3. Создаем отчет о проблемах
CREATE OR REPLACE VIEW config_issues AS
SELECT 
    name as parameter_name,
    setting as current_value,
    boot_val as default_value,
    source as config_source,
    pending_restart,
    context
FROM pg_settings 
WHERE pending_restart = true 
   OR source != 'default'
   OR setting != boot_val;

-- 4. Просматриваем проблемы
SELECT * FROM config_issues ORDER BY pending_restart DESC, parameter_name;
```

Каждая лабораторная работа охватывает определенный аспект конфигурирования PostgreSQL - от базового изучения параметров до продвинутых техник автоматизации и диагностики.