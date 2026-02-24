#!/usr/bin/env fish
function syncC
    set -l base_dir ~/Documents/configuration/.config

    # === Цвета (перенёс вверх, чтобы использовать и в бэкапе) ===
    set -l GREEN (printf '\033[32m')
    set -l YELLOW (printf '\033[33m')
    set -l RED (printf '\033[31m')
    set -l BOLD (printf '\033[1m')
    set -l RESET (printf '\033[0m')

    # === Автоматический бэкап предыдущей версии .config ===
    if test -d $base_dir
        set -l timestamp (date +%Y-%m-%d_%H-%M-%S)
        set -l backup_path $base_dir-$timestamp.bak

        printf "🔄 Создаём бэкап старой конфигурации → %s\n" $backup_path
        if mv $base_dir $backup_path
            printf "%s✓ Бэкап успешно создан%s\n" $GREEN $RESET
        else
            printf "%s✗ Ошибка при создании бэкапа!%s\n" $RED $RESET
            return 1
        end
    end

    set -l items \
        ~/.config/fish/config.fish fish \
        ~/.config/fish/conf.d fish/conf.d \
        ~/.config/fish/functions fish/functions \
        ~/.config/kitty/kitty.conf kitty \
        ~/.config/hypr/hyprland/keybinds.conf hypr/hyprland \
        ~/.config/hypr/hyprland/general.conf hypr/hyprland \
        ~/.config/hypr/custom/general.conf hypr/custom \
        ~/.config/hypr/custom/keybinds.conf hypr/custom \
        ~/.config/hypr/custom/execs.conf hypr/custom \
        ~/.config/quickshell/ii/services/Ai.qml quickshell/ii/services \
        ~/.config/quickshell/ii/services/Booru.qml quickshell/ii/services \
        ~/.config/quickshell/ii/services/ai/GeminiApiStrategy.qml quickshell/ii/services/ai \
        ~/.config/quickshell/ii/scripts/ai/gemini-translate.sh quickshell/ii/scripts/ai \
        ~/.config/quickshell/ii/scripts/videos/record.sh quickshell/ii/scripts/videos \
        ~/yt-dlp.conf yt-dlp

    set -l GREEN (printf '\033[32m')
    set -l YELLOW (printf '\033[33m')
    set -l RED (printf '\033[31m')
    set -l BOLD (printf '\033[1m')
    set -l RESET (printf '\033[0m')

    set -l copied_list
    set -l skipped_list
    set -l error_list

    for i in (seq 1 2 (count $items))
        set -l src_path $items[$i]
        set -l subdir $items[(math $i + 1)]

        if not test -e $src_path
            continue
        end

        set -l files_to_process
        if test -d $src_path
            set files_to_process (find $src_path -type f)
        else
            set files_to_process $src_path
        end

        for file in $files_to_process
            set -l src_base (dirname $src_path)
            if test -f $src_path
                set src_base (dirname $src_path)
            else
                set src_base $src_path
            end

            set -l rel (realpath --relative-to=$src_base $file)
            set -l dest $base_dir/$subdir/$rel

            mkdir -p (dirname $dest)

            set -l src_mtime (date -r $file +%s)
            set -l dest_mtime 0
            if test -f $dest
                set dest_mtime (date -r $dest +%s)
            end

            if test $src_mtime -eq $dest_mtime
                set -a skipped_list (basename $file)
                continue
            end

            if cp -p -- $file $dest
                set -a copied_list (basename $file)
            else
                set -a error_list (basename $file)
            end
        end
    end

    printf "\n%sИтог синхронизации%s\n" $BOLD $RESET
    printf "  %sСкопировано:%s %d\n" $GREEN $RESET (count $copied_list)
    printf "  %sПропущено (без изменений):%s %d\n" $YELLOW $RESET (count $skipped_list)
    if test (count $error_list) -gt 0
        printf "  %sОшибок:%s %d\n" $RED $RESET (count $error_list)
    end

    if test (count $copied_list) -gt 0
        printf "\n%sСписок скопированных файлов:%s\n" $GREEN $RESET
        for f in $copied_list
            printf "  • %s\n" $f
        end
    end

    printf "\nГотово.\n\n"
end
