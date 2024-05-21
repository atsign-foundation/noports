cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)
project(sshnpd VERSION 0.0.1 LANGUAGES C)

# 1. Variables - you are free to edit anything in this step

# 1a. Manually add your src files here
# globs are known as bad practice, so we do not use them here
set(
  SSHNPD_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/src/background_jobs.c
  ${CMAKE_CURRENT_LIST_DIR}/src/file_utils.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_npt_request.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_ping.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_ssh_request.c
  ${CMAKE_CURRENT_LIST_DIR}/src/handle_sshpublickey.c
  ${CMAKE_CURRENT_LIST_DIR}/src/main.c
  ${CMAKE_CURRENT_LIST_DIR}/src/params.c
  ${CMAKE_CURRENT_LIST_DIR}/src/run_srv.c
  ${CMAKE_CURRENT_LIST_DIR}/src/run_sshkeygen.c
  ${CMAKE_CURRENT_LIST_DIR}/src/utils.c
)

# 1b. Manually add your include directories here
set(SSHNPD_INCLUDE_DIR ${CMAKE_CURRENT_LIST_DIR}/include)

# 1c. Set the path to the argparse directory
set(ARGPARSE_DIR ${CMAKE_CURRENT_LIST_DIR}/../3rdparty/argparse)

# 1d. Set compile definitions

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
find_package(atsdk QUIET)
if(NOT atsdk_FOUND)
  # TODO: fetch from GitHub
  # message(STATUS "[SSHNPD] atclient not found, fetching from GitHub..")
  # FetchContent_Declare(
  #  atclient
  #  URL https://github.com/...
  #           URL_HASH SHA256=
  # )
  list(APPEND SSHNPD_TARGETS_TO_INSTALL atclient atchops atlogger)
  list(APPEND SSHNPD_MAKE_AVAILABLE atclient atchops atlogger)
else()
  message(STATUS "[SSHNPD] atclient found package..")
endif()

# 4b. argparse
find_package(argparse-static QUIET)
if(NOT argparse-static_FOUND)
  message(
    STATUS
    "[SSHNPD] argparse not found, fetching from local repository.."
  )
  fetchcontent_declare(argparse-static SOURCE_DIR ${ARGPARSE_DIR})
  list(APPEND SSHNPD_TARGETS_TO_INSTALL argparse-static)
  list(APPEND SSHNPD_MAKE_AVAILABLE argparse-static)
else()
  message(STATUS "[SSHNPD] argparse found package..")
endif()

# 4c. make everything available
if(SSHNPD_MAKE_AVAILABLE)
  fetchcontent_makeavailable(${SSHNPD_MAKE_AVAILABLE})
endif()

# 5. Create sshnpd_lib library target

add_library(${PROJECT_NAME}_lib STATIC ${SSHNPD_SRCS})

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  target_link_libraries(
    ${PROJECT_NAME}_lib
    PRIVATE
      atsdk::atclient
      debug atsdk::atchops
      atsdk::atlogger
      argparse::argparse-static
  )
else()
  target_link_libraries(
    ${PROJECT_NAME}_lib
    PRIVATE
      atsdk::atclient
      atsdk::atchops
      atsdk::atlogger
      argparse::argparse-static
  )
endif()

# Set include directories for sshnpd target
target_include_directories(
  ${PROJECT_NAME}_lib
  PUBLIC
    $<BUILD_INTERFACE:${SSHNPD_INCLUDE_DIR}>
    $<BUILD_INTERFACE:${argparse-static_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# 6 Install sshnpd library
# This step configures running `cmake --build build --target install` (which is the same thing as `make install`)
# This work also helps other CMake projects use `find_package(atclient)` to find our library, once installed.
list(APPEND SSHNPD_TARGETS_TO_INSTALL ${PROJECT_NAME}_lib) # install sshnpd_lib

foreach(target ${SSHNPD_TARGETS_TO_INSTALL})
  message(STATUS "[SSHNPD] Installing ${target}..")
  install(
    TARGETS ${target}
    EXPORT ${PROJECT_NAME}_lib-config
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
endforeach()

install(
  DIRECTORY ${SSHNPD_INCLUDE_DIR}/${PROJECT_NAME}
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# 7. Create sshnpd executable target
add_executable(${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/src/main.c)

target_link_libraries(
  ${PROJECT_NAME}
  PRIVATE
    ${PROJECT_NAME}_lib
    atsdk::atclient
    atsdk::atchops
    atsdk::atlogger
    argparse::argparse-static
)

# 8. Build tests
if(SSHNPD_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/tests)
endif()
