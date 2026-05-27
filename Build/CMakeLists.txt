cmake_minimum_required(VERSION 3.16)
project(CYCommon VERSION 1.0.0 LANGUAGES CXX)

# Configure the C++ standard (C++11 is sufficient for CYCommon)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Force every target to compile as C++20
if(MSVC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++20 /utf-8")
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
        set(ARCH_NAME "x64")
    endif()
elseif(APPLE)
    if(IOS)
        set(PLATFORM_NAME "iOS")
    else()
        set(PLATFORM_NAME "macOS")
    endif()
    set(_CYCOMMON_OSX_ARCH_DEFINED FALSE)
    if(DEFINED CMAKE_OSX_ARCHITECTURES)
        string(STRIP "${CMAKE_OSX_ARCHITECTURES}" _CYCOMMON_OSX_ARCH_STRIPPED)
        if(NOT "${_CYCOMMON_OSX_ARCH_STRIPPED}" STREQUAL "")
            set(_CYCOMMON_OSX_ARCH_DEFINED TRUE)
        endif()
    endif()
    if(_CYCOMMON_OSX_ARCH_DEFINED)
        if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
            set(ARCH_NAME "arm64")
        elseif(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
            set(ARCH_NAME "x86_64")
        else()
            set(ARCH_NAME ${CMAKE_OSX_ARCHITECTURES})
        endif()
    elseif(DEFINED CMAKE_SYSTEM_PROCESSOR)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
            set(ARCH_NAME "arm64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
            set(ARCH_NAME "x86_64")
        else()
            set(ARCH_NAME ${CMAKE_SYSTEM_PROCESSOR})
        endif()
    else()
        set(ARCH_NAME "x86_64")
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
endif()

# Use absolute output directories to keep artifacts organized
get_filename_component(OUTPUT_BASE_DIR "${CMAKE_SOURCE_DIR}/../Bin/${PLATFORM_NAME}/${ARCH_NAME}" ABSOLUTE)

# On Windows, include runtime library type in output path (MD/MT)
if(WIN32 AND DEFINED WINDOWS_RUNTIME)
    set(OUTPUT_BASE_DIR "${OUTPUT_BASE_DIR}/${WINDOWS_RUNTIME}")
endif()

# For single-config generators, include build type in output path
if(CMAKE_BUILD_TYPE)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${CMAKE_BUILD_TYPE}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${CMAKE_BUILD_TYPE}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_BASE_DIR}/${CMAKE_BUILD_TYPE}")
else()
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_BASE_DIR})
endif()

# Multi-config generator output directories (Visual Studio, Xcode, etc.)
foreach(OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG} "${OUTPUT_BASE_DIR}/${OUTPUTCONFIG}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG} "${OUTPUT_BASE_DIR}/${OUTPUTCONFIG}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG} "${OUTPUT_BASE_DIR}/${OUTPUTCONFIG}")
endforeach()

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
            )
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
    elseif(UNIX)
        target_compile_definitions(${TARGET} PRIVATE
            _GNU_SOURCE
        )

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
    )

    set_target_properties_by_platform(CYCommon_shared)

    add_library(CYCommon::shared ALIAS CYCommon_shared)
endif()

# Static library target
if(BUILD_STATIC_LIBS)
    add_library(CYCommon_static STATIC
        ${CYCOMMON_SOURCES}
        ${CYCOMMON_HEADERS}
    )

    set_target_properties(CYCommon_static PROPERTIES
        VERSION ${PROJECT_VERSION}
        PUBLIC_HEADER "${CYCOMMON_HEADERS}"
        OUTPUT_NAME "CYCommon"
    )

    set_target_properties_by_platform(CYCommon_static)

    add_library(CYCommon::static ALIAS CYCommon_static)
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
