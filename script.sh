#!/bin/bash

# Поиск подключенной флешки
flash_drive=$(lsblk -o MOUNTPOINT,NAME -n | grep "/media/" | awk '{print $1}')

if [ -z "$flash_drive" ]; then
    echo "Не найдена подключенная флешка."
    exit 1
fi

echo "Найдена флешка: $flash_drive"

archive_and_delete() {
    echo "*** Функция 'Архивация и удаление' ***"

    free_space=$(df -BM "$flash_drive" | awk 'NR==2{print $4}' | tr -d 'M')
    user_folder_size=$(du -sm ~/ | cut -f1)

    echo "Размер флешки: $free_space MB"
    echo "Размер пользовательской папки: $user_folder_size MB"

    if [ "$free_space" -lt "$user_folder_size" ]; then
        echo "Недостаточно свободного места на флешке для архивации."
        exit 1
    fi

    fallocate -l 50M $HOME/testfile.txt

    start_time="$(date +%s%N)"
    cp $HOME/testfile.txt $flash_drive
    end_time="$(date +%s%N)"
    elapsed="$(($end_time-$start_time))"
    elapsed="$(($elapsed / 1000000000))"
    speed="$((50 / $elapsed))"
    echo "Total of $elapsed seconds elapsed for speedtest process with speed $speed MB/S"
    echo "Are you ready to wait $(($user_folder_size / $speed)) seconds?"
    
    select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done


    rm $HOME/testfile.txt
    rm $flash_drive/testfile.txt
    rm -rf $flash_drive/backup

    if [ ! -d "$flash_drive/backup" ]; then
        mkdir -p "$flash_drive/backup"
    fi

    echo "Архивация пользовательской папки..."
    tar -czf "$flash_drive/backup/archive.tar.gz"  ~/

    if ! test -f "$flash_drive/backup/archive.tar.gz"; then
        echo "Архивация не удалась. Проверьте наличие свободного места на флешке."
        exit 1
    else
        echo "Архивация успешно завершена."
        echo "Проверка архива..."
        echo "Удаление файлов и папок с компьютера..."
        rm -rf ~/Downloads ~/Documents ~/Music ~/Videos ~/Pictures
        echo "Готово!"
    fi
}


clean_temp_files() {
    echo "*** Функция 'Очистка временных файлов' ***"
    echo "Очистка временных файлов..." 
    rm -rf "$HOME/.local/share/*"
    rm -rf "$HOME/.cache/*"
    rm -rf "$HOME/snap/firefox"
    echo "Готово!"
}

restore_from_archive() {
    echo "*** Функция 'Восстановление данных из архива' ***"

    archive="$flash_drive/backup/archive.tar.gz"
    if [ ! -f "$archive" ]; then
        echo "Архив не найден на флешке. Проверьте наличие файла archive.zip в папке backup."
        exit 1
    fi

    echo "Распаковка архива..."
    tar -xzf "$flash_drive/backup/archive.tar.gz" -C /
    rm -rf "$flash_drive/backup/archive.tar.gz"
    echo "Готово!"
    
}

# Выбор функции
echo "Выберите функцию:"
echo "1. Архивация и удаление"
echo "2. Очистка временных файлов"
echo "3. Восстановление данных из архива"
read -p "Введите номер функции (1-3): " choice

case $choice in
    1) archive_and_delete ;;
    2) clean_temp_files ;;
    3) restore_from_archive ;;
    *) echo "Неверный выбор." ;;
esac

exit 0
