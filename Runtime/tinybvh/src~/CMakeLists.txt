cmake_minimum_required(VERSION 3.15)
project(tinybvh_unity CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── tinybvh (header-only, fetched at configure time) ──────────────────────────
include(FetchContent)
FetchContent_Declare(
    tinybvh
    GIT_REPOSITORY https://github.com/jbikker/tinybvh.git
    GIT_TAG        main
)
FetchContent_MakeAvailable(tinybvh)

# ── shared library (the Unity native plugin) ──────────────────────────────────
add_library(tinybvh_unity SHARED tinybvh_unity.cpp)

target_include_directories(tinybvh_unity PRIVATE ${tinybvh_SOURCE_DIR})

# Symbol visibility: hide everything except EXPORT-marked functions
if(NOT MSVC)
    target_compile_options(tinybvh_unity PRIVATE -fvisibility=hidden)
endif()

# Optimise for release; tinybvh's BVH builder is CPU-heavy
target_compile_options(tinybvh_unity PRIVATE
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:/O2>   # MSVC fallback (cmake ignores unknown flags per-compiler)
)

# ── install (optional) ────────────────────────────────────────────────────────
# Copy the built .dll / .so into Assets/Plugins after building:
#   cmake --install . --prefix <path-to-unity-project>
install(TARGETS tinybvh_unity
    LIBRARY DESTINATION Assets/Plugins
    RUNTIME DESTINATION Assets/Plugins   # .dll on Windows
)
