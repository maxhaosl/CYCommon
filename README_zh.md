[English](README.md) | [中文](README_zh.md)

# CYCommon

CYCommon 是一个轻量级、零外部依赖的 C++ 通用工具库，是 [CYLogger](../CYLogger) 和 [CYCoroutine](../CYCoroutine) 的基础依赖。它以单一静态库的形式提供跨平台基础设施——异常处理、时间戳、字符串转换、智能指针和基础数据结构。

## 功能特性

- **零外部运行时依赖** — 不依赖任何第三方运行时库
- **跨平台**：Windows、macOS、iOS、Linux 和 Android
- **Unicode / ANSI 双模式** — Windows 上自动 TChar 映射；其他平台纯 UTF-8
- **异常层次结构** — `CYBaseException` 携带类型索引、严重级别代码、errno/系统错误和链式异常原因；`CYException<LEVEL, SEVER_CODE>` 提供编译期级别标记
- **微秒级精度时间戳**（`CYTimeStamps`）支持 UTC/本地时区偏移
- **字符串转换** — `CYStringUtils` 通过 locale 方式桥接 `std::string` 和 `std::wstring`
- **无锁侵入式单链表**（`CYList<NODE_TYPE>`）— 节点仅含 `next` 指针
- **函数绑定工具** — `Bind()` / `BindWithTryCatch()` 支持普通函数和 noexcept 保留的函数包装器
- **智能指针别名**：`SharePtr`、`UniquePtr`、`WeakPtr`、`MakeShared`、`MakeUnique`、`MakeTuple`
- **锁辅助工具**：`UniqueLock`、`LockGuard`
- **平台/编译器检测宏**：`CYCOMMON_WIN_OS`、`CYCOMMON_UNIX_OS`、`CYCOMMON_MAC_OS`、`CYCOMMON_ANDROID_OS`、`CYCOMMON_CLANG_COMPILER`、`CYCOMMON_GCC_COMPILER`、`CYCOMMON_MSVC_COMPILER`、`CYCOMMON_DEBUG_MODE`
- **可见性控制的 DLL API**（`CYCOMMON_API`），通过 `CYCOMMON_EXPORT_API` / `CYCOMMON_IMPORT_API` 控制符号导出

## 公共 API 总览

### 命名空间

所有符号均位于 `cry` 命名空间（`CYCOMMON_NAMESPACE_BEGIN` / `CYCOMMON_NAMESPACE_END`）。

### 核心类型

| 头文件 | 类型 | 说明 |
|---|---|---|
| `Common/Exception/CYBaseException.hpp` | `CYBaseException` | 基础异常：类型索引、严重级别代码、errno、`what()`、链式原因 |
| `Common/Exception/CYException.hpp` | `CYException<LEVEL, SEVER_CODE>` | 模板异常，编译期固定级别和严重级别代码 |
| `Common/Message/CYBaseMessage.hpp` | `CYBaseMessage` | 基础消息：channel、类型、严重级别代码、文本、文件/函数/行号、线程 ID、时间戳 |
| `Common/Time/CYTimeStamps.hpp` | `CYTimeStamps` | 微秒时间戳；`ToString()` 输出 `YYYY-MM-DD hh:mm:ss.nnn` |
| `Common/Structure/CYStringUtils.hpp` | `CYStringUtils` | `WString2String`、`String2WString`、`String2TString`、`TString2String` |
| `Common/CYList.hpp` | `CYList<NODE_TYPE>` | 无锁侵入式单链表：`Empty`、`PushBack`、`PopFront` |
| `Common/CYBind.hpp` | `Bind`、`BindWithTryCatch` | 函数绑定辅助工具 |
| `Common/CYDebugString.hpp` | `DebugString` | Windows 调试输出辅助函数 |

### 便捷宏

| 宏 | 展开为 |
|---|---|
| `SharePtr`、`UniquePtr`、`WeakPtr` | `std::shared_ptr`、`std::unique_ptr`、`std::weak_ptr` |
| `MakeShared`、`MakeUnique`、`MakeTuple` | `std::make_shared`、`std::make_unique`、`std::make_tuple` |
| `UniqueLock`、`LockGuard` | `std::unique_lock<std::mutex>`、`std::lock_guard<std::mutex>` |
| `IfTrueThrow`、`IfFalseThrow` | `CYException<K_LOG_LEVEL_UNKNOWN>` 上的静态辅助方法 |

## 构建

CYCommon 是一个**静态库**（Windows 上为 `CYCommon.lib`，Unix-like 平台为 `libCYCommon.a`）。它作为第三方组件被 CYLogger 和 CYCoroutine 引用。

### Windows（Visual Studio）

在 Visual Studio 2022 中打开 `Build/Windows/CYCommon.sln` 构建，或使用 CYLogger 的矩阵构建脚本（会自动构建 CYCommon 作为依赖）。

### macOS / iOS / Linux / Android

CYLogger 的 `Build/build_all_platforms.sh`（及其各平台独立脚本）会在需要时自动构建 CYCommon。

### 手动 CMake 构建

```bash
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --parallel
```

## 使用示例

```cpp
#include "CYCommon/CYCommon.hpp"

// 时间戳
cry::CYTimeStamps ts;
std::cout << ts.ToString() << std::endl;

// 字符串转换
std::string utf8 = cry::CYStringUtils::WString2String(L"你好世界");

// 异常捕获（自动携带 errno）
try {
    cry::IfFalseThrow(false, TEXT("Something went wrong"));
} catch (const cry::CYBaseException* e) {
    std::cerr << e->what() << std::endl;
}

// 侵入式链表
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

## 依赖

- C++11 及以上（编译时使用宿主工具链；CYLogger 使用 C++20，CYCoroutine 使用 C++20）
- 无外部运行时依赖
- 仅使用标准库（`<string>`、`<memory>`、`<mutex>`、`<functional>`、`<chrono>`、`<sstream>` 等）

## 许可证

CYCommon 基于 MIT 许可证分发。详见 `Inc/CYCommon/CYTypeDefine.hpp` 文件头部的许可证声明。

## 更新日志

详见 [`Change.log`](Change.log)。