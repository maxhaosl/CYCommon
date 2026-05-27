# CYCommon

CYCommon is a lightweight, zero-dependency C++ common utilities library that underpins CYLogger and CYCoroutine. It provides cross-platform foundations - exception handling, timestamps, string conversion, smart pointers, and basic data structures - in a single static library.

## Features

- Zero external runtime dependencies - no third-party libraries required at runtime
- Cross-platform: Windows, macOS, iOS, Linux, and Android
- Unicode / ANSI dual-mode - automatic TChar mapping on Windows; pure UTF-8 on other platforms
- Exception hierarchy - CYBaseException carries type index, severity code, errno/system error, and chained causes; CYException adds compile-time level tagging
- Microsecond-precision timestamps (CYTimeStamps) with UTC/local offset support
- String conversion - CYStringUtils bridges std::string / std::wstring via locale-aware setlocale calls
- Lock-free intrusive singly-linked list (CYList<NODE_TYPE>) - nodes carry only a next pointer
- Bind utilities - Bind() / BindWithTryCatch() for plain and noexcept-preserving function wrappers
- Smart pointer aliases: SharePtr, UniquePtr, WeakPtr, MakeShared, MakeUnique, MakeTuple
- Lock helpers: UniqueLock, LockGuard
- Platform / compiler detection macros: CYCOMMON_WIN_OS, CYCOMMON_UNIX_OS, CYCOMMON_MAC_OS, CYCOMMON_ANDROID_OS, CYCOMMON_CLANG_COMPILER, CYCOMMON_GCC_COMPILER, CYCOMMON_MSVC_COMPILER, CYCOMMON_DEBUG_MODE
- Visibility-controlled DLL API (CYCOMMON_API) via CYCOMMON_EXPORT_API / CYCOMMON_IMPORT_API

## Public API Summary

### Namespace

All symbols live in the cry namespace (CYCOMMON_NAMESPACE_BEGIN / CYCOMMON_NAMESPACE_END).

### Core Types

| Header | Type | Purpose |
|---|---|---|
| Common/Exception/CYBaseException.hpp | CYBaseException | Base exception: type index, severity code, errno, what(), chained cause |
| Common/Exception/CYException.hpp | CYException<LEVEL, SEVER_CODE> | Templated exception with fixed level and severity code at compile time |
| Common/Message/CYBaseMessage.hpp | CYBaseMessage | Base message: channel, type, severity code, text, file/function/line, thread id, timestamp |
| Common/Time/CYTimeStamps.hpp | CYTimeStamps | Timestamp with microseconds; ToString() -> YYYY-MM-DD hh:mm:ss.nnn |
| Common/Structure/CYStringUtils.hpp | CYStringUtils | WString2String, String2WString, String2TString, TString2String |
| Common/CYList.hpp | CYList<NODE_TYPE> | Lock-free intrusive SList: Empty, PushBack, PopFront |
| Common/CYBind.hpp | Bind, BindWithTryCatch | Function binding helpers |
| Common/CYDebugString.hpp | DebugString | Windows debug output helper |

### Convenience Macros

| Macro | Expands to |
|---|---|
| SharePtr, UniquePtr, WeakPtr | std::shared_ptr, std::unique_ptr, std::weak_ptr |
| MakeShared, MakeUnique, MakeTuple | std::make_shared, std::make_unique, std::make_tuple |
| UniqueLock, LockGuard | std::unique_lock<std::mutex>, std::lock_guard<std::mutex> |
| IfTrueThrow, IfFalseThrow | Static helpers on CYException |

## Build

CYCommon is a static library (CYCommon.lib on Windows, libCYCommon.a on Unix-like platforms). It is consumed as a bundled third-party component by CYLogger and CYCoroutine.

### Windows (Visual Studio)

Open Build/Windows/CYCommon.sln in Visual Studio 2022 and build, or use the CYLogger matrix scripts which build it automatically as a dependency.

### macOS / iOS / Linux / Android

CYLogger Build/build_all_platforms.sh (and its individual platform helpers) automatically build CYCommon alongside CYLogger and CYCoroutine when needed.

### Manual CMake Build

```bash
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --parallel
```

### CMake Options

-DBUILD_SHARED_LIBS=ON/OFF - Build shared library (default: ON)
-DBUILD_STATIC_LIBS=ON/OFF - Build static library (default: ON)
-DWINDOWS_RUNTIME=MD/MT - Windows CRT type (default: MD)

## Usage Example

```cpp
#include "CYCommon/CYCommon.hpp"

// Timestamps
cry::CYTimeStamps ts;
std::cout << ts.ToString() << std::endl;

// String conversion
std::string utf8 = cry::CYStringUtils::WString2String(L"Hello World");

// Exception with errno capture
try {
    cry::IfFalseThrow(false, TEXT("Something went wrong"));
} catch (const cry::CYBaseException* e) {
    std::cerr << e->what() << std::endl;
}

// Intrusive list
struct Node { Node* next = nullptr; int value; };
cry::CYList<Node> list;
Node n1; n1.value = 1;
Node n2; n2.value = 2;
list.PushBack(n1);
list.PushBack(n2);
while (auto* node = list.PopFront()) {
    std::cout << node->value << std::endl;
}
```

## Dependencies

- C++20 or later
- No external runtime dependencies
- Standard library only (string, memory, mutex, functional, chrono, sstream, etc.)

## License

CYCommon is distributed under the MIT License. See the license block in Inc/CYCommon/CYTypeDefine.hpp for details.

## Changelog

See Change.log for a chronological list of updates.
