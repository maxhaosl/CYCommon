cmake_minimum_required(VERSION 3.16)
project(CYCommon VERSION 1.0.0 LANGUAGES CXX)

# Configure the C++ standard (C++11 is sufficient for CYCommon)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Force every target to compile as C++20
if(MSVC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++20 /utf-8")
    # Enable debug information in PDB format for all builds
    # /Zi - Program database for Edit & Continue
    # /FS - Force synchronous PDB writes (required when multiple cl.exe write to same PDB)
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Zi /FS")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /Zi /FS")
    # Linker settings for PDB generation
    set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /DEBUG:FULL")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /DEBUG:FULL")
else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20")
endif()

# Library flavor toggles
if(NOT DEFINED BUILD_SHARED_LIBS)
    option(BUILD_SHARED_LIBS "Build shared libraries" ON)
endif()
if(NOT DEFINED BUILD_STATIC_LIBS)
    option(BUILD_STATIC_LIBS "Build static libraries" ON)
endif()

# iOS only supports static libraries (App Store policy prohibits dylibs)
if(IOS)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
    set(BUILD_STATIC_LIBS ON CACHE BOOL "Build static libraries" FORCE)
endif()

# Fallback: detect iOS from output directory path when toolchain doesn't set IOS
if(NOT IOS AND DEFINED CYCOMMON_OUTPUT_DIR)
    if(CYCOMMON_OUTPUT_DIR MATCHES "/iOS/" OR CYCOMMON_OUTPUT_DIR MATCHES "/Bin/[^/]*/[^/]*/iOS/")
        set(IOS ON CACHE BOOL "Building for iOS" FORCE)
        set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
        set(BUILD_STATIC_LIBS ON CACHE BOOL "Build static libraries" FORCE)
    endif()
endif()

# Windows runtime library selection
if(WIN32)
    set(_CYCOMMON_VALID_RUNTIMES "MD" "MT" "MDD" "MTD")
    if(NOT DEFINED WINDOWS_RUNTIME)
        set(WINDOWS_RUNTIME "MD" CACHE STRING "Windows runtime library")
    else()
        set(WINDOWS_RUNTIME "${WINDOWS_RUNTIME}" CACHE STRING "Windows runtime library" FORCE)
    endif()
    set_property(CACHE WINDOWS_RUNTIME PROPERTY STRINGS "MD" "MT" "MDD" "MTD")

    string(TOUPPER "${WINDOWS_RUNTIME}" _CYCOMMON_RUNTIME_UPPER)
    list(FIND _CYCOMMON_VALID_RUNTIMES "${_CYCOMMON_RUNTIME_UPPER}" _CYCOMMON_RUNTIME_INDEX)
    if(_CYCOMMON_RUNTIME_INDEX EQUAL -1)
        message(FATAL_ERROR "WINDOWS_RUNTIME must be one of MT, MD, MTD, or MDD (got ${WINDOWS_RUNTIME}).")
    endif()

    if(_CYCOMMON_RUNTIME_UPPER STREQUAL "MT")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded" CACHE STRING "MSVC runtime selection" FORCE)
    elseif(_CYCOMMON_RUNTIME_UPPER STREQUAL "MTD")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDebug" CACHE STRING "MSVC runtime selection" FORCE)
    elseif(_CYCOMMON_RUNTIME_UPPER STREQUAL "MDD")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDebugDLL" CACHE STRING "MSVC runtime selection" FORCE)
    else()
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "MSVC runtime selection" FORCE)
    endif()
    message(STATUS "Windows Runtime: ${_CYCOMMON_RUNTIME_UPPER}")
endif()

# Output directory layout
if(WIN32)
    set(PLATFORM_NAME "Windows")
    if(CMAKE_SIZEOF_VOID_P EQUAL 4)
        set(ARCH_NAME "x86")
    else()
        set(ARCH_NAME "x86_64")
    endif()
elseif(APPLE)
    if(IOS)
        set(PLATFORM_NAME "iOS")
        # Allow the caller to override the arch output directory name.
        # This is essential for iOS where arm64 (device) and arm64-simulator
        # both map to CMAKE_OSX_ARCHITECTURES=arm64 but need separate output dirs.
        if(DEFINED TARGET_ARCH AND NOT "${TARGET_ARCH}" STREQUAL "")
            set(ARCH_NAME "${TARGET_ARCH}")
        elseif(DEFINED CYCOMMON_OUTPUT_ARCH)
            set(ARCH_NAME "${CYCOMMON_OUTPUT_ARCH}")
        elseif(DEFINED CMAKE_OSX_ARCHITECTURES AND NOT "${CMAKE_OSX_ARCHITECTURES}" STREQUAL "")
            if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
                set(ARCH_NAME "arm64")
            elseif(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
                set(ARCH_NAME "x86_64")
            else()
                set(ARCH_NAME "${CMAKE_OSX_ARCHITECTURES}")
            endif()
        else()
            set(ARCH_NAME "arm64")
        endif()
    else()
        # macOS
        set(PLATFORM_NAME "MacOS")
        if(DEFINED CYCOMMON_OUTPUT_ARCH)
            set(ARCH_NAME "${CYCOMMON_OUTPUT_ARCH}")
        elseif(DEFINED CMAKE_OSX_ARCHITECTURES AND NOT "${CMAKE_OSX_ARCHITECTURES}" STREQUAL "")
            if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
                set(ARCH_NAME "arm64")
            elseif(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
                set(ARCH_NAME "x86_64")
            else()
                set(ARCH_NAME "${CMAKE_OSX_ARCHITECTURES}")
            endif()
        elseif(DEFINED CMAKE_SYSTEM_PROCESSOR)
            if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
                set(ARCH_NAME "arm64")
            elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
                set(ARCH_NAME "x86_64")
            else()
                set(ARCH_NAME "${CMAKE_SYSTEM_PROCESSOR}")
            endif()
        else()
            set(ARCH_NAME "x86_64")
        endif()
    endif()
elseif(ANDROID)
    set(PLATFORM_NAME "Android")
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
        set(ARCH_NAME "armeabi-v7a")
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        set(ARCH_NAME "arm64-v8a")
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
        set(ARCH_NAME "x86")
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
        set(ARCH_NAME "x86_64")
    endif()
elseif(UNIX)
    set(PLATFORM_NAME "Linux")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        set(ARCH_NAME "arm64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i386|i686")
        set(ARCH_NAME "x86")
    else()
        set(ARCH_NAME "x86_64")
    endif()
else()
    # Fallback: treat as MacOS
    set(PLATFORM_NAME "MacOS")
    if(DEFINED CYCOMMON_OUTPUT_ARCH)
        set(ARCH_NAME "${CYCOMMON_OUTPUT_ARCH}")
    elseif(DEFINED CMAKE_OSX_ARCHITECTURES AND NOT "${CMAKE_OSX_ARCHITECTURES}" STREQUAL "")
        if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
            set(ARCH_NAME "arm64")
        elseif(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
            set(ARCH_NAME "x86_64")
        else()
            set(ARCH_NAME "${CMAKE_OSX_ARCHITECTURES}")
        endif()
    elseif(DEFINED CMAKE_SYSTEM_PROCESSOR)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
            set(ARCH_NAME "arm64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
            set(ARCH_NAME "x86_64")
        else()
            set(ARCH_NAME "${CMAKE_SYSTEM_PROCESSOR}")
        endif()
    else()
        set(ARCH_NAME "x86_64")
    endif()
endif()

# Use absolute output directories to keep artifacts organized
# Support external output directory override (for deps-based builds)
option(CYCOMMON_OUTPUT_DIR_IS_FINAL "CYCOMMON_OUTPUT_DIR already includes config slice (e.g. CYLogger Bin/Linux/arch/release)" OFF)
if(DEFINED CYCOMMON_OUTPUT_DIR AND CYCOMMON_OUTPUT_DIR_IS_FINAL)
    # Caller has provided a complete output path including arch and build type.
    # Use it directly without any modification.
    get_filename_component(OUTPUT_BASE_DIR "${CYCOMMON_OUTPUT_DIR}" ABSOLUTE)
elseif(DEFINED CYCOMMON_OUTPUT_DIR)
    # Resolve to absolute path (handles relative paths from deps builds)
    get_filename_component(_CYCOMMON_OUTPUT_DIR_ABS "${CYCOMMON_OUTPUT_DIR}" ABSOLUTE)
    get_filename_component(OUTPUT_BASE_DIR "${_CYCOMMON_OUTPUT_DIR_ABS}" ABSOLUTE)
    # On Windows, include runtime library type in output path (MD/MT)
    if(WIN32 AND DEFINED WINDOWS_RUNTIME)
        set(OUTPUT_BASE_DIR "${OUTPUT_BASE_DIR}/${WINDOWS_RUNTIME}")
    endif()
else()
    get_filename_component(OUTPUT_BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../Bin/${PLATFORM_NAME}/${ARCH_NAME}" ABSOLUTE)
    # On Windows, include runtime library type in output path (MD/MT)
    if(WIN32 AND DEFINED WINDOWS_RUNTIME)
        set(OUTPUT_BASE_DIR "${OUTPUT_BASE_DIR}/${WINDOWS_RUNTIME}")
    endif()
endif()

# For single-config generators (Ninja, Makefile), we manually append CMAKE_BUILD_TYPE.
# For multi-config generators (Visual Studio), MSBuild appends the config name automatically.
# For iOS (even with Xcode generator), we always append build type to keep Debug/Release separate.
if(CMAKE_CONFIGURATION_TYPES AND NOT IOS)
    # Multi-config: use OUTPUT_BASE_DIR directly; MSBuild adds config subdir
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
elseif(CYCOMMON_OUTPUT_DIR_IS_FINAL)
    # Caller already included the config slice in OUTPUT_BASE_DIR; do not append build type.
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}")
elseif(CMAKE_BUILD_TYPE)
    # Single-config: capitalize first letter of build type (debug -> Debug, release -> Release)
    string(SUBSTRING "${CMAKE_BUILD_TYPE}" 0 1 _FIRST_CHAR)
    string(SUBSTRING "${CMAKE_BUILD_TYPE}" 1 -1 _REST_CHARS)
    string(TOUPPER "${_FIRST_CHAR}" _FIRST_UPPER)
    set(_BUILD_TYPE_CAPITALIZED "${_FIRST_UPPER}${_REST_CHARS}")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${_BUILD_TYPE_CAPITALIZED}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${_BUILD_TYPE_CAPITALIZED}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${_BUILD_TYPE_CAPITALIZED}")
else()
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
endif()

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/..)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../Inc)

# Gather sources
file(GLOB_RECURSE CYCOMMON_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/../Src/*.cpp"
)

# Gather headers
file(GLOB_RECURSE CYCOMMON_HEADERS
    "${CMAKE_CURRENT_SOURCE_DIR}/../Inc/*.hpp"
)

# Helper to apply platform-specific properties
function(set_target_properties_by_platform TARGET)
    if(WIN32)
        target_compile_definitions(${TARGET} PRIVATE
            _WIN32_WINNT=0x0601
            WIN32_LEAN_AND_MEAN
            NOMINMAX
        )

        # Set output name based on build type (Debug builds get 'D' suffix)
        get_target_property(TARGET_OUTPUT_NAME ${TARGET} OUTPUT_NAME)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT TARGET_OUTPUT_NAME MATCHES "D$")
            set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME "${TARGET_OUTPUT_NAME}D")
        endif()

        if(${TARGET} MATCHES "shared")
            target_compile_definitions(${TARGET} PRIVATE
                CYCOMMON_EXPORT_API
            )
            set_target_properties(${TARGET} PROPERTIES
                WINDOWS_EXPORT_ALL_SYMBOLS ON
            )
        endif()

        set_property(TARGET ${TARGET} PROPERTY
            MSVC_RUNTIME_LIBRARY "${CMAKE_MSVC_RUNTIME_LIBRARY}")
    elseif(APPLE)
        if(IOS)
            set_target_properties(${TARGET} PROPERTIES
                XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
                MACOSX_BUNDLE OFF
            )
        endif()

        # Set output name based on build type (Debug builds get 'D' suffix on non-iOS)
        get_target_property(TARGET_OUTPUT_NAME ${TARGET} OUTPUT_NAME)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT TARGET_OUTPUT_NAME MATCHES "D$")
            set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME "${TARGET_OUTPUT_NAME}D")
        endif()

        if(${TARGET} MATCHES "shared")
            target_compile_definitions(${TARGET} PRIVATE
                CYCOMMON_EXPORT_API
            )
        endif()
    elseif(ANDROID)
        target_compile_definitions(${TARGET} PRIVATE
            ANDROID
        )

        if(${TARGET} MATCHES "shared")
            target_compile_definitions(${TARGET} PRIVATE
                CYCOMMON_EXPORT_API
            )
        endif()

        # Set output name based on build type (Debug builds get 'D' suffix)
        get_target_property(TARGET_OUTPUT_NAME ${TARGET} OUTPUT_NAME)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT TARGET_OUTPUT_NAME MATCHES "D$")
            set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME "${TARGET_OUTPUT_NAME}D")
        endif()
    elseif(UNIX)
        target_compile_definitions(${TARGET} PRIVATE
            _GNU_SOURCE
        )

        # Set output name based on build type (Debug builds get 'D' suffix)
        get_target_property(TARGET_OUTPUT_NAME ${TARGET} OUTPUT_NAME)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT TARGET_OUTPUT_NAME MATCHES "D$")
            set_target_properties(${TARGET} PROPERTIES OUTPUT_NAME "${TARGET_OUTPUT_NAME}D")
        endif()

        if(${TARGET} MATCHES "shared")
            target_compile_definitions(${TARGET} PRIVATE
                CYCOMMON_EXPORT_API
            )
        endif()
    endif()
endfunction()

# Shared library target
if(BUILD_SHARED_LIBS)
    add_library(CYCommon_shared SHARED
        ${CYCOMMON_SOURCES}
        ${CYCOMMON_HEADERS}
    )

    set_target_properties(CYCommon_shared PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
        PUBLIC_HEADER "${CYCOMMON_HEADERS}"
        OUTPUT_NAME "CYCommon"
        MACOSX_BUNDLE OFF
    )

    set_target_properties_by_platform(CYCommon_shared)

    if(NOT TARGET CYCommon::shared)
        add_library(CYCommon::shared ALIAS CYCommon_shared)
    endif()
endif()

# Static library target (always available; BUILD_SHARED_LIBS=OFF triggers it)
if(BUILD_STATIC_LIBS)
    add_library(CYCommon_static STATIC
        ${CYCOMMON_SOURCES}
        ${CYCOMMON_HEADERS}
    )

    set_target_properties(CYCommon_static PROPERTIES
        VERSION ${PROJECT_VERSION}
        PUBLIC_HEADER "${CYCOMMON_HEADERS}"
        OUTPUT_NAME "CYCommon"
        COMPILE_PDB_OUTPUT_DIRECTORY "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}"
    )

    # Enable Position Independent Code (PIC) so the static library can be
    # linked into shared libraries on UNIX and Apple platforms
    if(UNIX OR APPLE)
        set_target_properties(CYCommon_static PROPERTIES
            POSITION_INDEPENDENT_CODE ON
        )
    endif()

    set_target_properties_by_platform(CYCommon_static)

    if(NOT TARGET CYCommon::static)
        add_library(CYCommon::static ALIAS CYCommon_static)
    endif()
endif()

# Install rules
if(BUILD_SHARED_LIBS)
    install(TARGETS CYCommon_shared
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        PUBLIC_HEADER DESTINATION include/CYCommon
    )
endif()
if(BUILD_STATIC_LIBS)
    install(TARGETS CYCommon_static
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        PUBLIC_HEADER DESTINATION include/CYCommon
    )
endif()

# Diagnostics
message(STATUS "CYCommon Version: ${PROJECT_VERSION}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "Platform: ${PLATFORM_NAME}")
message(STATUS "Architecture: ${ARCH_NAME}")
message(STATUS "Output Directory: ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
message(STATUS "Build Shared Libraries: ${BUILD_SHARED_LIBS}")
message(STATUS "Build Static Libraries: ${BUILD_STATIC_LIBS}")
if(WIN32)
    message(STATUS "Windows Runtime: ${WINDOWS_RUNTIME}")
endif()
