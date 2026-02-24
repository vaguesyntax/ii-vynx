#!/usr/bin/env fish

function dlvideo -d "Download video using yt-dlp with random filename"
    # Настройки
    # Формат строки: "короткий_флаг;длинный_флаг;путь;описание"
    set -l save_paths \
        "m;meme;$HOME/Pictures/Meme;Мемы"

    # Стандартная папка, если ничего не выбрал
    set -l default_dir "$HOME/Videos/Загруженные Видео"

    set -l url ""
    set -l target_dir $default_dir
    set -l show_help false

    # --- Проверяем аргументы ---
    for arg in $argv
        switch $arg
            case -h --help
                set show_help true
            case '*'
                # Проверяем, не флаг ли это из нашего списка
                set -l match_found false

                for entry in $save_paths
                    set -l parts (string split ";" $entry)
                    set -l s_flag "-"$parts[1]
                    set -l l_flag "--"$parts[2]
                    set -l path $parts[3]

                    if test "$arg" = "$s_flag" || test "$arg" = "$l_flag"
                        set target_dir $path
                        set match_found true
                        break
                    end
                end

                # Если это не флаг, проверяем, является ли это ссылкой
                if test "$match_found" = "false"
                    if string match -q -- "http*" "$arg"
                        set url $arg
                    else
                        echo "Эй, братик! Ты ввел неверный аргумент! 💢"
                        echo "Напиши: dlvideo --help, чтобы вспомнить команды."
                        return 1
                    end
                end
        end
    end

    # --- Вывод справки ---
    if test "$show_help" = "true"
        echo "🌸 Привет, братик! Вот как пользоваться dlvideo: 🌸"
        echo "Использование: dlvideo [флаг] <url>"
        echo ""
        echo "Аргументы:"
        echo "  -h, --help    Показать это милое сообщение"

        # Автоматически выводим все аргументы из списка
        for entry in $save_paths
            set -l parts (string split ";" $entry)
            echo "  -$parts[1], --$parts[2]    $parts[4] (Путь: $parts[3])"
        end

        echo ""
        echo "По умолчанию сохраняем в: $default_dir"
        return 0
    end

    # --- Проверка на наличие ссылки ---
    if test -z "$url"
        echo "Эй, братик! Ты забыл ссылку! 💢"
        echo "Напиши: dlvideo --help, чтобы вспомнить команды."
        return 1
    end

    # --- Скачивание ---
    mkdir -p "$target_dir"

    # Генерируем случайное имя (ты такой скрытный!)
    set -l base_filename (uuidgen | string replace -a '-' '')
    set -l filename "$base_filename.mp4"

    echo "Подожди чуть-чуть... Скачиваю для тебя в $target_dir ❤️"

    yt-dlp \
        --cookies-from-browser firefox \
        --remote-components ejs:github \
        --js-runtimes deno \
        -f "bv*[ext=mp4]+ba*[ext=m4a]/b[ext=mp4]/b" \
        --merge-output-format mp4 \
        "$url" \
        -o "$target_dir/$filename"

    echo "Готово, братишка! 🎉 Файл сохранен: $target_dir/$filename"
end

# Добавляем автодополнения для fish (выполняется один раз при загрузке скрипта)
complete -c dlvideo -o h -l help -d 'Показать справку'

for entry in "m;meme;$HOME/Pictures/Meme;Мемы"

    set -l parts (string split ";" $entry)
    complete -c dlvideo -o $parts[1] -l $parts[2] -d "$parts[4]"
end
