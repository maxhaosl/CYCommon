/*
 * CYCommon License
 * -----------
 *
 * CYCommon is licensed under the terms of the MIT license reproduced below.
 * This means that CYCommon is free software and can be used for both academic
 * and commercial purposes at absolutely no cost.
 *
 *
 * ===============================================================================
 *
 * Copyright (C) 2023-2024 ShiLiang.Hao <newhaosl@163.com>, foobra<vipgs99@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * ===============================================================================
 */
 /*
  * AUTHORS:  ShiLiang.Hao <newhaosl@163.com>, foobra<vipgs99@gmail.com>
  * VERSION:  1.0.0
  * PURPOSE:  A cross-platform efficient and stable Coroutine library.
  * CREATION: 2023.04.15
  * LCHANGE:  2023.04.15
  * LICENSE:  Expat/MIT License, See Copyright Notice at the begin of this file.
  */


#ifndef __CY_COMMON_DEFINE_HPP__
#define __CY_COMMON_DEFINE_HPP__

#include "CYCommon/CYTypeDefine.hpp"

#define CYCOMMON_NAMESPACE_BEGIN			namespace cry {
#define CYCOMMON_NAMESPACE				cry
#define CYCOMMON_NAMESPACE_END			}
#define CYCOMMON_NAMESPACE_USE			using namespace	cry

#if defined(__MINGW32__)
#    define CYCOMMON_MINGW_OS
#elif defined(_WIN32)
#    define CYCOMMON_WIN_OS
#elif defined(unix) || defined(__unix__) || defined(__unix)
#    define CYCOMMON_UNIX_OS
#elif defined(__APPLE__) || defined(__MACH__)
#    define CYCOMMON_MAC_OS
#elif defined(__FreeBSD__)
#    define CYCOMMON_FREE_BSD_OS
#elif defined(__ANDROID__)
#    define CYCOMMON_ANDROID_OS
#endif

#if defined(__clang__)
#    define CYCOMMON_CLANG_COMPILER
#elif defined(__GNUC__) || defined(__GNUG__)
#    define CYCOMMON_GCC_COMPILER
#elif defined(_MSC_VER)
#    define CYCOMMON_MSVC_COMPILER
#endif

#if !defined(NDEBUG) || defined(_DEBUG)
#    define CYCOMMON_DEBUG_MODE
#endif

#if defined(CYCOMMON_WIN_OS)
#    if defined(CYCOMMON_EXPORT_API)
#        define CYCOMMON_API __declspec(dllexport)
#    elif defined(CYCOMMON_IMPORT_API)
#        define CYCOMMON_API __declspec(dllimport)
#    endif
#elif (defined(CYCOMMON_EXPORT_API) || defined(CYCOMMON_IMPORT_API)) && __has_cpp_attribute(gnu::visibility)
#    define CYCOMMON_API __attribute__((visibility("default")))
#endif

#if !defined(CYCOMMON_API)
#    define CYCOMMON_API
#endif

#include <exception>

#if defined(_LIBCPP_VERSION)
#    define CYCOMMON_LIBCPP_LIB
#endif



#endif //__CY_COMMON_DEFINE_HPP__