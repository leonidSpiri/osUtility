chcp 65001
@echo off
setlocal enabledelayedexpansion


:: Поиск подключенной флешки
set "flash_drive="
for /f "tokens=2 delims==" %%d in ('wmic logicaldisk where drivetype^=2 get deviceid /value') do (
    set "flash_drive=%%d"
)

if not defined flash_drive (
    echo Не найдена подключенная флешка.                                                                                         
    goto :end_script
)

echo Найдена флешка: %flash_drive%
set "flash_letter=%flash_drive:~0,1%"

set "flash_path=%flash_drive%\"

:menu
cls
echo Выберите функцию:
echo 1. Архивация и удаление
echo 2. Очистка временных файлов
echo 3. Восстановление данных из архива

set /p choice=Введите номер функции (1-3):

if "%choice%"=="1" goto archive_and_delete
if "%choice%"=="2" goto clean_temp_files
if "%choice%"=="3" goto restore_from_archive

:archive_and_delete
cls
echo *** Функция "Архивация и удаление" ***


set "free_space=Unknown"

for /f "tokens=3" %%a in ('dir /-c "%flash_path%"') do (
    set "free_space=%%a"
)

:: Подсчет размера пользовательской папки в MB
set "appdata_user_folder_size_bytes=0"
for /r "%USERPROFILE%\AppData\Local\" %%f in (*) do (
    set /a "appdata_user_folder_size_bytes+=%%~zf"
)

set "user_folder_size_bytes=0"
for /r "%USERPROFILE%" %%f in (*) do (
    set /a "user_folder_size_bytes+=%%~zf"
)
set /a "user_folder_size_mb=(user_folder_size_bytes - appdata_user_folder_size_bytes) / 1024 / 1024"


:: Проверка места на флешке
set /a "free_space_mb=free_space / 1024"


echo Размер флешки: %free_space_mb% MB
echo Размер пользовательской папки: %user_folder_size_mb% MB
pause

if %free_space_mb% lss %user_folder_size_mb% (
    echo Недостаточно свободного места на флешке для архивации.
    goto :end_script
)


set "test_file=%USERPROFILE%\testfile.txt"

if not exist "%flash_letter%:\backup" (
    mkdir "%flash_letter%:\backup"
)

:: Замер времени на создание тестового файла
echo Замер времени на копирование тестового файла...
set start_time=!time: =0!
fsutil file createnew "%test_file%" 52428800 >nul 2>&1
for /r "%test_file%" %%f in (*) do (
    set /a "folder_size_bytes+=%%~zf"
)
set /a "folder_size_mb=user_folder_size_bytes / 1024 / 1024"
fsutil file createnew "%test_file%" 52428800 >nul 2>&1
copy /Y "%test_file%" "%flash_letter%:\testfile.txt" >nul
set end_time=!time: =0!
set /a "time_difference_seconds=((1!end_time:~0,2!-100)*3600 + (1!end_time:~3,2!-100)*60 + (1!end_time:~6,2!-100)) - ((1!start_time:~0,2!-100)*3600 + (1!start_time:~3,2!-100)*60 + (1!start_time:~6,2!-100))"
echo Время на копирование тестового файла: %time_difference_seconds% секунд.
set /a "speed=51 / time_difference_seconds"
echo Средняя пропускная скрость %speed% MB/S
set /a "time=user_folder_size_mb / speed"
:: Пользовательское подтверждение
set /p "confirm=Готовы ли вы ждать %time% секунд? (y/n): "
if /i "%confirm%" neq "y" goto :end_script

:: Архивация пользовательской папки
echo Архивация пользовательской папки...
powershell -Command "Compress-Archive -Path \"%USERPROFILE%\" -DestinationPath \"%flash_letter%:\\backup\\archive.zip\"" >nul 2>&1

:: Проверка успешной архивации
if errorlevel 1 (
    echo Архивация не удалась. Проверьте наличие свободного места на флешке.
    goto :end_script
) else (
    echo Архивация успешно завершена.
    echo Проверка архива...
    fc /b "%USERPROFILE%\testfile.txt" "%flash_letter%:\testfile.txt" >nul
    if errorlevel 1 (
        echo Проверка не пройдена. Архив не идентичен оригиналу.
        goto :end_script
    ) else (
        echo Проверка пройдена. Удаление тестового файла...
        del /Q "%test_file%"
        echo Удаление файлов и папок с компьютера...
        rmdir /s /q "%USERPROFILE%\Downloads"
 	rmdir /s /q "%USERPROFILE%\Documents"
	rmdir /s /q "%USERPROFILE%\Desktop"
 	rmdir /s /q "%USERPROFILE%\Music"
	rmdir /s /q "%USERPROFILE%\Videos"
	rmdir /s /q "%USERPROFILE%\Pictures"
        echo Готово!
    )
)

:end_script
pause
goto :eof




:clean_temp_files
cls
echo *** Функция "Очистка временных файлов" ***

:: Дополнительные операции по очистке могут быть добавлены по необходимости
echo Очистка временных файлов...
rmdir /S /Q "%TEMP%\" >nul 2>&1
rmdir /S /Q "%USERPROFILE%\AppData\Local\" >nul 2>&1
rmdir /s /q "%USERPROFILE%\AppData\Local\Google\Chrome\User Data\" >nul 2>&1
rmdir /s /q "%USERPROFILE%\AppData\Local\Microsoft\Edge\User Data\" >nul 2>&1
echo Готово!
pause
goto :eof




:restore_from_archive
cls
echo *** Функция "Восстановление данных из архива" ***

:: Проверка наличия архива на флешке
set "archive=%flash_letter%:\backup\archive.zip"
if not exist "%archive%" (
    echo Архив не найден на флешке. Проверьте наличие файла archive.zip в папке backup.
    goto :end_script
)

:: Распаковка архива
echo Распаковка архива...
mkdir "%USERPROFILE%\restore\" >nul 2>&1
powershell -Command "Expand-Archive -Path '%archive%' -DestinationPath '%USERPROFILE%\restore\'" >nul 2>&1
rem Путь к папке для распаковки
set "destination=%USERPROFILE%\restore"

:: Проверка успешной распаковки
if errorlevel 1 (
    echo Распаковка не удалась. Проверьте архив на флешке.
    goto :end_script
) else (
    echo Распаковка успешно завершена. Копирование данных...
    xcopy /C /E /H /R /I /K /Y "%USERPROFILE%\restore\*.*" C:\Users\ >nul
    echo Очистка временных файлов...
    rmdir /S /Q "%USERPROFILE%\restore"
    echo Готово!
)

:end_script
pause
goto :eof