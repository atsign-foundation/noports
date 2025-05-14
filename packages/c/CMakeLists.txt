option(NOPORTS_ATSDK_PATH "Local atsdk path" OFF)
option(NOPORTS_CJSON_PATH "Local cJSON path" OFF)
option(NOPORTS_MBEDTLS_PATH "Local mbedtls path" OFF)
# GS tool used to signal sshnpd to exit at a dedicated time
# allows us to properly test for memory leaks
option(NOPORTS_GS_TOOL "Include graceful-shutdown-tool" OFF)
option(NOPORTS_BUILD_TESTS "Enable testing" OFF)
set(ATSDK_CJSON_PATH ${NOPORTS_CJSON_PATH})
set(ATSDK_MBEDTLS_PATH ${NOPORTS_MBEDTLS_PATH})

cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)
project(noports VERSION 1.0.7 LANGUAGES C)

include("${CMAKE_CURRENT_LIST_DIR}/cmake/CPackSetup.cmake")

# Shared compile options between clang & gcc
add_compile_options("-Wall")
add_compile_options("-Wextra")
add_compile_options("-Werror-implicit-function-declaration")
add_compile_options("-Wtype-limits")
add_compile_options("-Wimplicit-fallthrough")
add_compile_options("-Wmissing-field-initializers")
# This enforces strictly using ISO standard (definitely overkill, hence pedantic)
# enable this to check our deviations from the standard
# add_compile_options("-pedantic-errors")

# Custom compiler-based compiler options
if(CMAKE_C_COMPILER MATCHES ".*clang.*")
  message(STATUS "[NoPorts] DETECTED COMPILER: clang")
  if(CMAKE_BUILD_TYPE STREQUAL Release)
    add_compile_options("-Wno-calloc-transposed-args")
  endif()
else() # Assume gcc as the default
  message(STATUS "[NoPorts] DETECTED COMPILER: gcc")
endif()

if(NOPORTS_BUILD_TESTS)
  set(SSHNPD_BUILD_TESTS NOPORTS_BUILD_TESTS)
  enable_testing()
endif()

add_subdirectory(sshnpd)

if(NOPORTS_GS_TOOL)
  add_subdirectory(graceful-shutdown-tool)
endif()
