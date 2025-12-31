скрипт newproj.py открывается в GitBash.
Скрипт предназначен для запуска в PowerShell 7 скрипта new_sdl_imgui_project.ps1
Этот скрипт создает проект sdl2 + imgui в пути D:\Code\Again\ProjectName

Проект работает с SDL2, SDL_image, ImGui
В папки Debug и Release копируются библиотеки sdl2, sdl2_image для запуска программы из проводника.

При работе скрипт обращается к директориям:
D:\Code\SDL_Dev\SDL2-2.30.0\include - инклюды для SDL2
D:\Code\SDL_Dev\SDL2-2.30.0\lib\x64 - либы для SDL2
D:\Code\SDL_Dev\SDL2_image-2.8.2\include - инклюды для SDL2_image
D:\Code\SDL_Dev\SDL2_image-2.8.2\lib\x64 - либы для SDL2_image

D:\Code\imGui\imgui - инклюды и cpp  для imgui
D:\Code\imGui\imgui\backends - инклюды и cpp для imgui\backends


Работа в GitBash:
python3 newproj.py ProjectName --git

флаг --git инициализирует git в папке проекта