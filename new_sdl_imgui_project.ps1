<#
Usage:

# Создать проект (demo OFF)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Code\Again\__Script_for_making_projects\new_sdl_imgui_projects.ps1" -Name "space-revenger"

# Создать проект + git
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Code\Again\__Script_for_making_projects\new_sdl_imgui_projects.ps1" -Name "space-revenger" -git

# Создать проект с ImGui demo (demo ON)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Code\Again\__Script_for_making_projects\new_sdl_imgui_projects.ps1" -Name "space-revenger" -demo

# demo + git
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Code\Again\__Script_for_making_projects\new_sdl_imgui_projects.ps1" -Name "space-revenger" -demo -git
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [switch]$git,
  [switch]$demo
)

$ErrorActionPreference = "Stop"

# ====== Fixed paths (as you specified) ======
$Root = "D:\Code\Again"

$SDL2_Include = "D:\Code\SDL_Dev\SDL2-2.30.0\include"
$SDL2_LibX64  = "D:\Code\SDL_Dev\SDL2-2.30.0\lib\x64"

$SDL2IMG_Include = "D:\Code\SDL_Dev\SDL2_image-2.8.2\include"
$SDL2IMG_LibX64  = "D:\Code\SDL_Dev\SDL2_image-2.8.2\lib\x64"

$ImGui_Core     = "D:\Code\imGui\imgui"
$ImGui_Backends = "D:\Code\imGui\imgui\backends"

# ====== Helpers ======
function Ensure-Dir([string]$p) {
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

function Write-TextFile([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  Ensure-Dir $dir
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Copy-One([string]$src, [string]$dst) {
  if (-not (Test-Path $src)) { throw "File not found: $src" }
  Ensure-Dir (Split-Path -Parent $dst)
  Copy-Item -Force $src $dst
}

function To-PosixPath([string]$p) { $p.Replace("\", "/") }

# ====== Create project tree ======
$ProjectDir = Join-Path $Root $Name
if (Test-Path $ProjectDir) { throw "Folder already exists: $ProjectDir" }

$TargetName = ($Name -replace '[^A-Za-z0-9_]', '_')
if ([string]::IsNullOrWhiteSpace($TargetName)) {
  throw "Project name produced empty target name after sanitizing."
}

Ensure-Dir $ProjectDir
Ensure-Dir (Join-Path $ProjectDir "src")
Ensure-Dir (Join-Path $ProjectDir "include")
Ensure-Dir (Join-Path $ProjectDir "assets")
Ensure-Dir (Join-Path $ProjectDir "third_party\imgui")
Ensure-Dir (Join-Path $ProjectDir "third_party\imgui\backends")
Ensure-Dir (Join-Path $ProjectDir ".devcontainer")

# ====== Copy ImGui core ======
$imguiCoreFiles = @(
  "imconfig.h",
  "imgui.h",
  "imgui.cpp",
  "imgui_draw.cpp",
  "imgui_tables.cpp",
  "imgui_widgets.cpp",
  "imgui_demo.cpp",
  "imgui_internal.h",
  "imstb_rectpack.h",
  "imstb_textedit.h",
  "imstb_truetype.h"
)

foreach ($f in $imguiCoreFiles) {
  Copy-One (Join-Path $ImGui_Core $f) (Join-Path $ProjectDir "third_party\imgui\$f")
}

# ====== Copy ImGui backends (SDL2 + SDL_Renderer) ======
$imguiBackendFiles = @(
  "imgui_impl_sdl2.h",
  "imgui_impl_sdl2.cpp",
  "imgui_impl_sdlrenderer2.h",
  "imgui_impl_sdlrenderer2.cpp"
)

foreach ($f in $imguiBackendFiles) {
  Copy-One (Join-Path $ImGui_Backends $f) (Join-Path $ProjectDir "third_party\imgui\backends\$f")
}

# ====== main.cpp (production-friendly: demo is compile-time optional) ======
$mainCpp = @"
#include <SDL.h>
#include <SDL_image.h>

#include "imgui.h"
#include "backends/imgui_impl_sdl2.h"
#include "backends/imgui_impl_sdlrenderer2.h"

#include <cstdio>

int main(int, char**)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0)
    {
        std::printf("SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    const int imgFlags = IMG_INIT_PNG;
    if ((IMG_Init(imgFlags) & imgFlags) != imgFlags)
    {
        std::printf("IMG_Init failed: %s\n", IMG_GetError());
        // not fatal for this ImGui smoke test
    }

    SDL_Window* window = SDL_CreateWindow(
        "$Name",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        1280, 720,
        SDL_WINDOW_SHOWN
    );

    if (!window)
    {
        std::printf("SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );

    if (!renderer)
    {
        std::printf("SDL_CreateRenderer failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    ImGui::StyleColorsDark();

    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    ImGui_ImplSDLRenderer2_Init(renderer);

#ifdef ENABLE_IMGUI_DEMO
    bool showDemo = true;
#endif

    bool running = true;
    while (running)
    {
        SDL_Event e;
        while (SDL_PollEvent(&e))
        {
            ImGui_ImplSDL2_ProcessEvent(&e);
            if (e.type == SDL_QUIT)
                running = false;
            if (e.type == SDL_WINDOWEVENT && e.window.event == SDL_WINDOWEVENT_CLOSE)
                running = false;
        }

        // Typical order for SDL2 + SDLRenderer2 backends
        ImGui_ImplSDL2_NewFrame();
        ImGui_ImplSDLRenderer2_NewFrame();
        ImGui::NewFrame();

        ImGui::Begin("ImGui + SDL2 smoke test");
        ImGui::Text("Project: %s", "$Name");
#ifdef ENABLE_IMGUI_DEMO
        ImGui::Checkbox("Show Demo Window", &showDemo);
        ImGui::Text("Demo is ENABLED (compile-time).");
#else
        ImGui::Text("Demo is DISABLED (compile-time).");
#endif
        ImGui::Text("If you see this window: OK :)");
        ImGui::End();

#ifdef ENABLE_IMGUI_DEMO
        if (showDemo)
            ImGui::ShowDemoWindow(&showDemo);
#endif

        ImGui::Render();

        SDL_SetRenderDrawColor(renderer, 20, 20, 25, 255);
        SDL_RenderClear(renderer);

        // Your backend expects 2 args:
        ImGui_ImplSDLRenderer2_RenderDrawData(ImGui::GetDrawData(), renderer);

        SDL_RenderPresent(renderer);
    }

    ImGui_ImplSDLRenderer2_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui::DestroyContext();

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    IMG_Quit();
    SDL_Quit();
    return 0;
}
"@

Write-TextFile (Join-Path $ProjectDir "src\main.cpp") $mainCpp

# ====== CMakeLists.txt (production: demo OFF by default, assets copied, MSVC release optimizations) ======
$cmakeLists = @'
cmake_minimum_required(VERSION 3.20)

project("__PROJECT_NAME__" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(ENABLE_IMGUI_DEMO "Build ImGui demo window code" OFF)
option(COPY_ASSETS "Copy assets/ to output dir after build" ON)

set(APP_TARGET "__TARGET_NAME__")

set(IMGUI_SOURCES
    third_party/imgui/imgui.cpp
    third_party/imgui/imgui_draw.cpp
    third_party/imgui/imgui_tables.cpp
    third_party/imgui/imgui_widgets.cpp
)

if (ENABLE_IMGUI_DEMO)
    list(APPEND IMGUI_SOURCES third_party/imgui/imgui_demo.cpp)
    target_compile_definitions(${APP_TARGET} PRIVATE ENABLE_IMGUI_DEMO=1) # (note: set after add_executable)
endif()

add_executable(${APP_TARGET}
    src/main.cpp
    ${IMGUI_SOURCES}
    third_party/imgui/backends/imgui_impl_sdl2.cpp
    third_party/imgui/backends/imgui_impl_sdlrenderer2.cpp
)

# If demo enabled, define macro on target (safe place, after target exists)
if (ENABLE_IMGUI_DEMO)
    target_compile_definitions(${APP_TARGET} PRIVATE ENABLE_IMGUI_DEMO=1)
endif()

target_include_directories(${APP_TARGET} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/imgui
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/imgui/backends
)

if (WIN32)
    set(SDL2_INCLUDE_DIR "__SDL2_INCLUDE__")
    set(SDL2_LIB_DIR     "__SDL2_LIB__")

    set(SDL2IMG_INCLUDE_DIR "__SDL2IMG_INCLUDE__")
    set(SDL2IMG_LIB_DIR     "__SDL2IMG_LIB__")

    target_include_directories(${APP_TARGET} PRIVATE
        "${SDL2_INCLUDE_DIR}"
        "${SDL2IMG_INCLUDE_DIR}"
    )

    target_link_directories(${APP_TARGET} PRIVATE
        "${SDL2_LIB_DIR}"
        "${SDL2IMG_LIB_DIR}"
    )

    target_link_libraries(${APP_TARGET} PRIVATE
        SDL2main
        SDL2
        SDL2_image
        winmm imm32 version setupapi
    )

    # ---- Slim & fast Release for MSVC ----
    if (MSVC)
        target_compile_options(${APP_TARGET} PRIVATE
            $<$<CONFIG:Release>:/O2 /Ob2 /DNDEBUG /Gy /Zc:inline>
        )
        target_link_options(${APP_TARGET} PRIVATE
            $<$<CONFIG:Release>:/OPT:REF /OPT:ICF>
        )
        set_property(TARGET ${APP_TARGET} PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)
    endif()

    # ---- Copy DLLs next to exe ----
    set(_SDL2_DLL "")
    set(_SDL2IMG_DLL "")

    if (EXISTS "${SDL2_LIB_DIR}/SDL2.dll")
        set(_SDL2_DLL "${SDL2_LIB_DIR}/SDL2.dll")
    elseif (EXISTS "D:/Code/SDL_Dev/SDL2-2.30.0/bin/SDL2.dll")
        set(_SDL2_DLL "D:/Code/SDL_Dev/SDL2-2.30.0/bin/SDL2.dll")
    endif()

    if (EXISTS "${SDL2IMG_LIB_DIR}/SDL2_image.dll")
        set(_SDL2IMG_DLL "${SDL2IMG_LIB_DIR}/SDL2_image.dll")
    elseif (EXISTS "D:/Code/SDL_Dev/SDL2_image-2.8.2/bin/SDL2_image.dll")
        set(_SDL2IMG_DLL "D:/Code/SDL_Dev/SDL2_image-2.8.2/bin/SDL2_image.dll")
    endif()

    if (NOT _SDL2_DLL STREQUAL "")
        add_custom_command(TARGET ${APP_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_SDL2_DLL}"
                "$<TARGET_FILE_DIR:${APP_TARGET}>/SDL2.dll"
        )
    else()
        message(WARNING "SDL2.dll not found. Put it near lib\\x64 or bin, or edit CMakeLists.")
    endif()

    if (NOT _SDL2IMG_DLL STREQUAL "")
        add_custom_command(TARGET ${APP_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_SDL2IMG_DLL}"
                "$<TARGET_FILE_DIR:${APP_TARGET}>/SDL2_image.dll"
        )
    else()
        message(WARNING "SDL2_image.dll not found. Put it near lib\\x64 or bin, or edit CMakeLists.")
    endif()

else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SDL2 REQUIRED sdl2)
    pkg_check_modules(SDL2_IMAGE REQUIRED SDL2_image)

    target_include_directories(${APP_TARGET} PRIVATE
        ${SDL2_INCLUDE_DIRS}
        ${SDL2_IMAGE_INCLUDE_DIRS}
    )

    target_link_libraries(${APP_TARGET} PRIVATE
        ${SDL2_LIBRARIES}
        ${SDL2_IMAGE_LIBRARIES}
    )
endif()

# ---- Copy assets/ next to exe ----
if (COPY_ASSETS)
    add_custom_command(TARGET ${APP_TARGET} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets"
            "$<TARGET_FILE_DIR:${APP_TARGET}>/assets"
    )
endif()
'@

$cmakeLists = $cmakeLists.
  Replace("__PROJECT_NAME__", $Name).
  Replace("__TARGET_NAME__", $TargetName).
  Replace("__SDL2_INCLUDE__", (To-PosixPath $SDL2_Include)).
  Replace("__SDL2_LIB__", (To-PosixPath $SDL2_LibX64)).
  Replace("__SDL2IMG_INCLUDE__", (To-PosixPath $SDL2IMG_Include)).
  Replace("__SDL2IMG_LIB__", (To-PosixPath $SDL2IMG_LibX64))

Write-TextFile (Join-Path $ProjectDir "CMakeLists.txt") $cmakeLists

# ====== CMakePresets.json (demo option controlled by script flag) ======
$demoValue = if ($demo) { "ON" } else { "OFF" }

$presets = @'
{
  "version": 6,
  "configurePresets": [
    {
      "name": "vs2022-x64",
      "displayName": "Visual Studio 2022 (x64)",
      "generator": "Visual Studio 17 2022",
      "architecture": "x64",
      "binaryDir": "${sourceDir}/build/vs2022-x64",
      "cacheVariables": {
        "ENABLE_IMGUI_DEMO": "__DEMO__",
        "COPY_ASSETS": "ON"
      }
    },
    {
      "name": "docker-linux",
      "displayName": "Docker (Linux, Release)",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/docker-linux",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Release",
        "ENABLE_IMGUI_DEMO": "__DEMO__",
        "COPY_ASSETS": "ON"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "vs2022-x64-debug",
      "configurePreset": "vs2022-x64",
      "configuration": "Debug"
    },
    {
      "name": "vs2022-x64-release",
      "configurePreset": "vs2022-x64",
      "configuration": "Release"
    },
    {
      "name": "docker-linux-release",
      "configurePreset": "docker-linux"
    }
  ]
}
'@

$presets = $presets.Replace("__DEMO__", $demoValue)
Write-TextFile (Join-Path $ProjectDir "CMakePresets.json") $presets

# ====== Dockerfile (build-only) ======
$dockerfile = @'
FROM ubuntu:24.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential cmake ninja-build pkg-config \
    libsdl2-dev libsdl2-image-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . /work

RUN cmake --preset docker-linux && cmake --build --preset docker-linux-release
'@
Write-TextFile (Join-Path $ProjectDir "Dockerfile") $dockerfile

# ====== .devcontainer (optional) ======
$devcontainerJson = @"
{
  "name": "$Name",
  "build": { "dockerfile": "../Dockerfile" },
  "workspaceFolder": "/work"
}
"@
Write-TextFile (Join-Path $ProjectDir ".devcontainer\devcontainer.json") $devcontainerJson

# ====== .gitignore ======
$gitignore = @'
.vs/
build/
out/
CMakeFiles/
CMakeCache.txt
cmake_install.cmake
*.vcxproj*
*.sln
*.dir/
*.user
*.suo
Thumbs.db
.DS_Store
'@
Write-TextFile (Join-Path $ProjectDir ".gitignore") $gitignore

# ====== README ======
$readme = @"
# $Name

## Visual Studio 2022 (CMake)
Open folder in Visual Studio.
Presets are in CMakePresets.json.

Demo: $demoValue (set by script flag -demo).

## Build from CLI
cmake --preset vs2022-x64
cmake --build --preset vs2022-x64-release

## Docker (Linux, build-only)
docker build -t $TargetName .
"@
Write-TextFile (Join-Path $ProjectDir "README.md") $readme

# ====== Optional git init ======
if ($git) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found in PATH, but -git was specified."
  }
  Push-Location $ProjectDir
  git init | Out-Null
  git add -A | Out-Null
  git commit -m "Initial project scaffold" | Out-Null
  Pop-Location
}

Write-Host "Done!"
Write-Host "Project folder: $ProjectDir"
Write-Host "CMake target:  $TargetName"
Write-Host "ImGui demo:    $demoValue"
if ($git) { Write-Host "Git initialized." }
