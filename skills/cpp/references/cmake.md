# Modern CMake — full template

Target-based, presets-driven, FetchContent for dependencies. CMake's current docs track 4.x;
`FetchContent` has shipped since 3.11, and its imported targets are used with
`target_link_libraries` exactly like `find_package` targets. The rule throughout: state
requirements on the **target**, never globally.

## Layout

```text
myproj/
  CMakeLists.txt
  CMakePresets.json
  include/myproj/widget.hpp
  src/widget.cpp
  src/main.cpp
  tests/widget_test.cpp
  .clang-format
  .clang-tidy
```

## Root CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.21)        # 3.21+ for presets v3 and modern target features
project(myproj VERSION 0.1.0 LANGUAGES CXX)

# Export compile_commands.json so clang-tidy / clangd see exact flags.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# A reusable warnings interface target — link it into everything you own.
add_library(myproj_warnings INTERFACE)
if(MSVC)
  target_compile_options(myproj_warnings INTERFACE /W4 /permissive- /WX)
else()
  target_compile_options(myproj_warnings INTERFACE
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Werror)
endif()

# --- library target ---
add_library(widget src/widget.cpp)
target_include_directories(widget PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
target_compile_features(widget PUBLIC cxx_std_23)         # the standard is a target property
target_link_libraries(widget PRIVATE myproj_warnings)

# --- executable target ---
add_executable(app src/main.cpp)
target_link_libraries(app PRIVATE widget myproj_warnings)

# --- dependencies via FetchContent ---
include(FetchContent)
FetchContent_Declare(fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG        11.0.2)
FetchContent_Declare(Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG        v3.7.1)
FetchContent_MakeAvailable(fmt Catch2)
target_link_libraries(widget PUBLIC fmt::fmt)

# --- tests ---
enable_testing()
add_executable(widget_test tests/widget_test.cpp)
target_link_libraries(widget_test PRIVATE widget Catch2::Catch2WithMain myproj_warnings)

include(Catch)                 # provided by Catch2; registers each TEST_CASE with ctest
catch_discover_tests(widget_test)
```

Use GoogleTest instead of Catch2 by declaring `googletest` (GIT_TAG `v1.15.2`) and linking
`GTest::gtest_main`; register with `include(GoogleTest)` + `gtest_discover_tests(...)`.

## CMakePresets.json

Presets give every developer (and CI) identical, named configurations — no remembered flag
soup. `debug` for day-to-day, `asan` for the sanitizer build the local gate uses, `release` for
optimized output.

```json
{
  "version": 3,
  "cmakeMinimumRequired": { "major": 3, "minor": 21, "patch": 0 },
  "configurePresets": [
    {
      "name": "debug",
      "binaryDir": "${sourceDir}/build/debug",
      "generator": "Ninja",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" }
    },
    {
      "name": "asan",
      "inherits": "debug",
      "binaryDir": "${sourceDir}/build/asan",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug",
        "CMAKE_CXX_FLAGS": "-fsanitize=address,undefined -fno-omit-frame-pointer -g"
      }
    },
    {
      "name": "release",
      "binaryDir": "${sourceDir}/build/release",
      "generator": "Ninja",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "RelWithDebInfo" }
    }
  ],
  "buildPresets": [
    { "name": "debug", "configurePreset": "debug" },
    { "name": "asan", "configurePreset": "asan" },
    { "name": "release", "configurePreset": "release" }
  ],
  "testPresets": [
    { "name": "asan", "configurePreset": "asan", "output": { "outputOnFailure": true } }
  ]
}
```

Drive it:

```bash
cmake --preset asan          # configure
cmake --build --preset asan  # build
ctest --preset asan          # test under ASan+UBSan
```

## Sanitizer & warning flags per compiler

| | GCC / Clang | MSVC |
| --- | --- | --- |
| Warnings-as-errors | `-Wall -Wextra -Wpedantic -Werror` | `/W4 /WX` |
| ASan + UBSan | `-fsanitize=address,undefined -fno-omit-frame-pointer -g` | `/fsanitize=address` (no UBSan) |
| TSan (run alone) | `-fsanitize=thread -g` | — |
| Std | `-std=c++23` (`-std=c++26`/`-std=c++2c`) | `/std:c++23` (`/std:c++latest`) |

Inject sanitizers per-config (the `asan` preset's `CMAKE_CXX_FLAGS`), not unconditionally — a
release build must not carry them.

## clang-tidy / cppcheck

With `CMAKE_EXPORT_COMPILE_COMMANDS=ON`, both tools read the exact per-file flags:

```bash
clang-tidy -p build/debug src/widget.cpp src/main.cpp
cppcheck --enable=warning,performance --project=build/debug/compile_commands.json
```

A minimal `.clang-tidy`:

```yaml
Checks: 'clang-analyzer-*,bugprone-*,modernize-*,performance-*,cppcoreguidelines-*'
WarningsAsErrors: 'clang-analyzer-*,bugprone-use-after-move'
```

## Install / export (when you ship a library)

```cmake
include(GNUInstallDirs)
install(TARGETS widget EXPORT widgetTargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT widgetTargets NAMESPACE myproj:: DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/myproj)
```

Containerizing the resulting binary and CI pipelines -> `deployment`.
