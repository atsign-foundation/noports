cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)
project(sshnpd VERSION 1.0.9 LANGUAGES C)

# 1. Variables - you are free to edit anything in this step

# 1a. Manually add your src files here
# globs are known as bad practice, so we do not use them here
set(
  SSHNPD_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/src/daemon.c
  ${CMAKE_CURRENT_LIST_DIR}/src/daemon_utils.c
  ${CMAKE_CURRENT_LIST_DIR}/src/device_info.c
  ${CMAKE_CURRENT_LIST_DIR}/src/file_utils.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_npt_request.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_ping.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_ssh_request.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_sshpublickey.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handler_commons.c
  ${CMAKE_CURRENT_LIST_DIR}/src/main.c
  ${CMAKE_CURRENT_LIST_DIR}/src/params.c
  ${CMAKE_CURRENT_LIST_DIR}/src/permitopen.c
  ${CMAKE_CURRENT_LIST_DIR}/src/run_srv_process.c
)

if(SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION)
  add_compile_definitions(SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION)
endif()

# 1b. Manually add your include directories here
set(SSHNPD_INCLUDE_DIR ${CMAKE_CURRENT_LIST_DIR}/include)

# 1c. Set the path to the argparse directory
set(ARGPARSE_DIR ${CMAKE_CURRENT_LIST_DIR}/../3rdparty/argparse)

# 1d.
set(SRV_DIR ${CMAKE_CURRENT_LIST_DIR}/../srv)

# 1e. Set compile definitions
set(ATAUTH_BUILD_EXECUTABLES OFF)

# ON=>builds tests by running the tests/CMakeLists.txt file and generates a
# `tests/` folder in the build directory where `ctest` can be ran in that
# directory, OFF=>does not build `tests/`
option(SSHNPD_BUILD_TESTS "Build sshnpd tests" OFF)

# 2. Include CMake modules

# FetchContent is a CMake v3.11+ module that downloads content at configure time
# Difference between FetchContent and ExternalProject: https://cmake.org/cmake/help/latest/module/FetchContent.html #id6
include(FetchContent)

# Contains ${CMAKE_INSTALL_*} variables are defined in GNUInstallDirs and changes according to OS.
# E.g. on Linux & MacOS, ${CMAKE_INSTALL_LIBDIR} is /usr/local/lib, but on Windows it may be C:\Program Files\atchops\lib
include(GNUInstallDirs)

# 3. Set CMake policies

# Ensures that non-deprecated behaviour is used in ExternalProject_Add and FetchContent modules
# https://cmake.org/cmake/help/latest/policy/CMP0135.html
cmake_policy(SET CMP0135 NEW)

# 4. Dependencies

# 4a. atsdk
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/atsdk.cmake)

# 4b. argparse
find_package(argparse-static QUIET)
if(NOT argparse-static_FOUND)
  message(
    STATUS
    "[SSHNPD] argparse not found, fetching from local repository.."
  )
  FetchContent_Declare(argparse-static SOURCE_DIR ${ARGPARSE_DIR})
  list(APPEND SSHNPD_TARGETS_TO_INSTALL argparse-static)
  list(APPEND SSHNPD_MAKE_AVAILABLE argparse-static)
else()
  message(STATUS "[SSHNPD] argparse found package..")
endif()

# 4c. srv
find_package(srv-lib QUIET)
if(NOT srv-lib_FOUND)
  message(STATUS "[SSHNPD] srv-lib not found, fetching from local repository..")
  FetchContent_Declare(srv-lib SOURCE_DIR ${SRV_DIR})
  list(APPEND SSHNPD_TARGETS_TO_INSTALL srv-lib argparse-static)
  list(APPEND SSHNPD_MAKE_AVAILABLE srv-lib argparse-static)
else()
  message(STATUS "[SSHNPD] srv-lib found package..")
endif()

# 4d. make everything available
if(SSHNPD_MAKE_AVAILABLE)
  FetchContent_MakeAvailable(${SSHNPD_MAKE_AVAILABLE})
endif()

# 5. Create sshnpd_lib library target

add_compile_options("-lrt")
add_library(${PROJECT_NAME}-lib STATIC ${SSHNPD_SRCS})
set(include_dirs "")
set(
  link_libs
  atclient
  atchops
  atlogger
  srv-lib
  argparse::argparse-static
)
if(NOPORTS_USE_SHARED_LIBS)
  find_path(cjson_include_dir NAMES cjson/cJSON.h REQUIRED)
  list(APPEND include_dirs ${cjson_include_dir})
  find_library(
    cjson_lib_path
    NAMES libcjson.so
    PATHS /usr/lib /usr/lib64 /usr/local/lib NO_CACHE
    REQUIRED
    NO_DEFAULT_PATH
    NO_PACKAGE_ROOT_PATH
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
    NO_CMAKE_INSTALL_PREFIX
  )
  list(APPEND link_libs ${cjson_lib_path})
else()
  list(APPEND link_libs cjson)
endif()
target_link_libraries(${PROJECT_NAME}-lib PRIVATE ${link_libs})

# Set include directories for sshnpd target
target_include_directories(
  ${PROJECT_NAME}-lib
  PUBLIC
    $<BUILD_INTERFACE:${SSHNPD_INCLUDE_DIR}>
    $<BUILD_INTERFACE:${argparse-static_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    ${include_dirs}
)

# 6 Install sshnpd library
# This step configures running `cmake --build build --target install` (which is the same thing as `make install`)
# This work also helps other CMake projects use `find_package(atclient)` to find our library, once installed.
list(APPEND SSHNPD_TARGETS_TO_INSTALL ${PROJECT_NAME}-lib) # install sshnpd_lib

foreach(target ${SSHNPD_TARGETS_TO_INSTALL})
  message(STATUS "[SSHNPD] Installing ${target}..")
  install(
    TARGETS ${target}
    EXPORT ${PROJECT_NAME}-lib-config
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
endforeach()

install(
  DIRECTORY ${SSHNPD_INCLUDE_DIR}/${PROJECT_NAME}
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# 7. Create sshnpd executable target
add_executable(${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/src/main.c)

target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}-lib ${link_libs})

# 8. Build tests
if(SSHNPD_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/tests)
endif()

# setup atauth binaries
add_executable(at_activate ${CMAKE_CURRENT_LIST_DIR}/src/at_activate.c)
target_link_libraries(at_activate PRIVATE atauth)
