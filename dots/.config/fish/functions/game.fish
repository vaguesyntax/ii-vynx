#!/usr/bin/env fish

#------------------------------------------------#
# Вставить директории для игр через "\" Пример:  #
#   "$HOME/.NSFW/Games/HaremHotel" \             #
#   "$HOME/.NSFW/Native games/MIST"              #
#------------------------------------------------#

set -g GAME_DIRS \
    #Native
    "$HOME/.NSFW/Games Linux/RenPy/AttackOnSurveyCorps" \
    "$HOME/.NSFW/Games Linux/RenPy/CosyCafe" \
    "$HOME/.NSFW/Games Linux/RenPy/CrimsonHigh" \
    "$HOME/.NSFW/Games Linux/RenPy/DeepVault" \
    "$HOME/.NSFW/Games Linux/RenPy/Doomination" \
    "$HOME/.NSFW/Games Linux/RenPy/ElectricSheep" \
    "$HOME/.NSFW/Games Linux/RenPy/FakeFather" \
    "$HOME/.NSFW/Games Linux/RenPy/FourElementsTrainer" \
    "$HOME/.NSFW/Games Linux/RenPy/FromTheSin" \
    "$HOME/.NSFW/Games Linux/RenPy/HappySummer" \
    "$HOME/.NSFW/Games Linux/RenPy/HaremHotel" \
    "$HOME/.NSFW/Games Linux/RenPy/HoneyKingdom" \
    "$HOME/.NSFW/Games Linux/RenPy/Hornycraft" \
    "$HOME/.NSFW/Games Linux/RenPy/LessonsInLove" \
    "$HOME/.NSFW/Games Linux/RenPy/LifesPayback" \
    "$HOME/.NSFW/Games Linux/RenPy/MagicalMishaps" \
    "$HOME/.NSFW/Games Linux/RenPy/MIST" \
    "$HOME/.NSFW/Games Linux/RenPy/MonsterCollege" \
    "$HOME/.NSFW/Games Linux/RenPy/NekoParadise" \
    "$HOME/.NSFW/Games Linux/RenPy/NorikasCase" \
    "$HOME/.NSFW/Games Linux/RenPy/PhotoHunt" \
    "$HOME/.NSFW/Games Linux/RenPy/ProjektPassion" \
    "$HOME/.NSFW/Games Linux/RenPy/RSSU" \
    "$HOME/.NSFW/Games Linux/RenPy/RickAndMorty" \
    "$HOME/.NSFW/Games Linux/RenPy/TabooStories" \
    "$HOME/.NSFW/Games Linux/RenPy/TakeOver" \
    "$HOME/.NSFW/Games Linux/RenPy/TakeisJourney" \
    "$HOME/.NSFW/Games Linux/RenPy/TheHeadmaster" \
    "$HOME/.NSFW/Games Linux/RenPy/TheShopkeeper" \
    "$HOME/.NSFW/Games Linux/RenPy/WelcomeToErosland" \
    "$HOME/.NSFW/Games Linux/RenPy/WitchHunter" \
    "$HOME/.NSFW/Games Linux/RenPy/WTS" \
    "$HOME/.NSFW/Games Linux/RenPy/YesIamAFurry" \
    "$HOME/.NSFW/Games Linux/RenPy/inquisitorTrainer" \
    "$HOME/.NSFW/Games Linux/Unity/IN HEAT" \
    "$HOME/.NSFW/Games Linux/Unity/MyDystopianRobotGirlfriend" \
    "$HOME/.NSFW/Games Linux/Unity/PonyWaifuSim" \
    "$HOME/.NSFW/Games Linux/Other/LonaRPG/usr/bin/LonaRPG_RUS_Launcher" \
    #PortProton (NOT NATIVE)
    "$HOME/.NSFW/Games Windows(PortProton)/Other/Adulttale/" \
    "$HOME/.NSFW/Games Windows(PortProton)/Other/DailyLivesofMyCountryside" \
    "$HOME/.NSFW/Games Windows(PortProton)/Unity/HypnoAppV1" \
    "$HOME/.NSFW/Games Windows(PortProton)/Unity/HypnoAppV2" \
    "$HOME/.NSFW/Games Windows(PortProton)/Unity/LovelyCraftPistonTrap"

#-------------------------------------------------------------------------------------------------------------#
# Если у вас нет интегрированной графики, то удалите переменные оставив set -g GAME_NV_ENV                    #
# Если у вас интегрированная графика + видеокарта от амд замените переменные для амд (не тестил)              #
# Если игра запускается на интегрированной графике и вы хотите чтобы игра работала на дискретной видеокарте   #
#-------------------------------------------------------------------------------------------------------------#

set -g GAME_NV_ENV
    #"__NV_PRIME_RENDER_OFFLOAD=1" \
    #"__GLX_VENDOR_LIBRARY_NAME=nvidia" \
    #"__VK_LAYER_NV_optimus=NVIDIA_only"

#-------------------------------------------------------------------------------------------------#
# Если у вас portproton установленный через flatpak, то замените portproton на запуск от flatpak  #
#-------------------------------------------------------------------------------------------------#

set -g PORTPROTON_CMD portproton --launch

set -g GAME_PATHS
set -g GAME_NAMES

#------------------------------------------------------------------------------------------------------------#
# Эта функция ищет подходящий лаунчер в указанной директории: либо нативный для Linux (.sh, .x86_64, .AppImage)#
# либо Windows .exe для запуска через PortProton. Если директория - это файл, возвращает его сразу.          #
# Приоритет: нативные лаунчеры, затем .exe. Если несколько, выбирает по совпадению имени с базовым именем     #
# директории. Если ничего не найдено, возвращает саму директорию с ошибкой.                                  #
#------------------------------------------------------------------------------------------------------------#

function __find_launcher --argument-names dir --description 'Находит лаунчер: нативный или .exe для PortProton'
    if test -f "$dir"
        echo "$dir"
        return 0
    end

    if not test -d "$dir"
        echo "$dir"
        return 1
    end

    set -l dir_base (basename -- "$dir" | string lower)

    # 1. Natuve Linux-launcher
    for ext in .sh .x86_64 .AppImage
        set -l files
        for file in "$dir"/*$ext
            if test -f "$file" -a -x "$file"
                set files $files "$file"
            end
        end

        if test (count $files) -eq 0
            continue
        end

        if string match -q -- '*.AppImage' "$files[1]"
            echo $files[1]
            return 0
        else
            if test (count $files) -eq 1
                echo $files[1]
                return 0
            else
                for file in $files
                    set -l file_base (basename -- "$file" | string replace --regex '\Q'$ext'\E$' '' | string lower)
                    if test "$file_base" = "$dir_base"
                        echo "$file"
                        return 0
                    end
                end
            end
        end
    end

    # 2. WIndows .exe for PortProton
    set -l exe_files
    for file in "$dir"/*.exe
        if test -f "$file"
            set exe_files $exe_files "$file"
        end
    end

    if test (count $exe_files) -gt 0
        if test (count $exe_files) -eq 1
            echo $exe_files[1]
            return 0
        else
            for file in $exe_files
                set -l name (basename -- "$file" | string replace -r '\.[eE][xX][eE]$' '' | string lower)
                if test "$name" = "$dir_base"
                    echo "$file"
                    return 0
                end
            end
            echo $exe_files[1]
            return 0
        end
    end

    echo "$dir"
    return 1
end

#---------------------------------------------------------------------------------------------------------#
# Эта функция сканирует все директории из GAME_DIRS, находит лаунчеры с помощью __find_launcher,          #
# и заполняет глобальные переменные GAME_PATHS (пути к лаунчерам) и GAME_NAMES (имена директорий).        #
# Затем настраивает автодополнение для команды game: стирает старое и добавляет номера с описаниями игр.  #
#---------------------------------------------------------------------------------------------------------#

function __build_game_index --description 'Сканирует GAME_DIRS и заполняет GAME_PATHS / GAME_NAMES'
    set -g GAME_PATHS
    set -g GAME_NAMES

    for entry in $GAME_DIRS
        set -l launcher (__find_launcher "$entry")

        if test $status -ne 0
            continue
        end

        if not test -f "$launcher"
            continue
        end

        set -l base (basename -- "$entry")
        set -g GAME_PATHS $GAME_PATHS "$launcher"
        set -g GAME_NAMES $GAME_NAMES "$base"
    end

    complete -c game -e 2>/dev/null

    set -l total (count $GAME_NAMES)
    for i in (seq 1 $total)
        complete -c game -a "$i" -d "$GAME_NAMES[$i]" -f
    end
end

__build_game_index

#--------------------------------------------------------------------------------------------------------#
# Основная функция: game <номер> запускает игру по номеру из списка. Без аргументов выводит список игр.  #
# С аргументом "refresh" обновляет индекс. Проверяет номер, находит лаунчер, запускает с учетом типа:    #
# .exe через PortProton, нативные через env с GAME_NV_ENV. Дополнительные аргументы передаются дальше.   #
# Запуск в фоне с setsid для отрыва от терминала.                                                        #
#--------------------------------------------------------------------------------------------------------#

function game --description 'game <номер> — запустить игру (PortProton AUR для .exe)'
    if test (count $argv) -eq 0
        printf "%3s  %s\n" "№" "ИМЯ"
        printf "%3s  %s\n" "---" "---------------------------"
        for i in (seq 1 (count $GAME_NAMES))
            printf "%3s) %s\n" $i $GAME_NAMES[$i]
        end
        return 0
    end

    if test "$argv[1]" = "refresh"
        __build_game_index
        echo "Индекс игр обновлён."
        return 0
    end

    set -l idx $argv[1]
    if not string match -r '^[0-9]+$' -- $idx >/dev/null
        echo "Ошибка: первый аргумент должен быть номером. Использование: game <номер>"
        return 1
    end

    set -l total (count $GAME_PATHS)
    if test $idx -lt 1 -o $idx -gt $total
        echo "Ошибка: нет игры с номером $idx (всего $total)."
        return 1
    end

    set -l target $GAME_PATHS[$idx]
    set -l extra_args
    if test (count $argv) -gt 1
        set extra_args $argv[2..-1]
    end

    if test -d "$target"
        set -l launcher (__find_launcher "$target")
        if test "$launcher" = "$target"
            echo "Не найден исполняемый файл в папке: $target"
            return 1
        else
            set target "$launcher"
        end
    end

    if not test -f "$target"
        echo "Целевой файл не найден: $target"
        return 1
    end

    echo "Запускаю: $GAME_NAMES[$idx]"
    echo "Файл: $target"

    if string match -qi '*.exe' -- "$target"
        echo "-> через PortProton"
        setsid env $PORTPROTON_CMD "$target" $extra_args >/dev/null 2>&1 &
    else if test -x "$target"
        setsid env $GAME_NV_ENV "$target" $extra_args >/dev/null 2>&1 &
    else
        setsid env $GAME_NV_ENV sh "$target" $extra_args >/dev/null 2>&1 &
    end

    return 0
end
