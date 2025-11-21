cmake_minimum_required(VERSION 3.10)
project(workspace_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(workspace_core SHARED
    src/workspace_core.cpp
)

target_include_directories(workspace_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common
)

if (WIN32)
    target_sources(workspace_core PRIVATE src/windows/process_win.cpp)
    target_link_libraries(workspace_core
        userenv
        advapi32
        kernel32
    )
    target_compile_definitions(workspace_core PRIVATE
        _UNICODE
        _WIN32_WINNT=0x0A00
    )
    target_compile_options(workspace_core PRIVATE /wd4102)
endif()

if (UNIX AND NOT APPLE)
    target_sources(workspace_core PRIVATE src/linux/process_linux.cpp)
    target_link_libraries(workspace_core pthread)
    target_compile_options(workspace_core PRIVATE -Wno-cpp)
endif()
