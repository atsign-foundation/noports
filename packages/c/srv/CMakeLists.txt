cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)

project(srv VERSION 0.0.1 LANGUAGES C)

# 1. Variables - you are free to edit anything in this step

# 1a. Manually add your src files here
# globs are known as bad practice, so we do not use them here
set(
  SRV_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/src/params.c
  ${CMAKE_CURRENT_LIST_DIR}/src/side.c
  ${CMAKE_CURRENT_LIST_DIR}/src/srv.c
)

# 1b. Manually add your include directories here
set(SRV_INCLUDE_DIR ${CMAKE_CURRENT_LIST_DIR}/include)

# 1c. Set the path to the argparse directory
set(ARGPARSE_DIR ${CMAKE_CURRENT_LIST_DIR}/../3rdparty/argparse)

# 1d. Set compile definitions

# ON=>builds tests by running the tests/CMakeLists.txt file and generates a
# `tests/` folder in the build directory where `ctest` can be ran in that
# directory, OFF=>does not build `tests/`
option(SRV_BUILD_TESTS "Build srv tests" OFF)

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
find_package(atsdk)
if(NOT atsdk_FOUND)
  # TODO: fetch from GitHub
  # message(STATUS "[SRV] atclient not found, fetching from GitHub..")
  # FetchContent_Declare(
  #  atclient
  #  URL https://github.com/...
  #           URL_HASH SHA256=
  # )
  list(APPEND SRV_TARGETS_TO_INSTALL atchops atlogger mbedtls)
  list(APPEND SRV_MAKE_AVAILABLE atchops atlogger mbedtls)
else()
  message(STATUS "[SRV] atclient found package..")
endif()

# 4b. argparse
find_package(argparse-static QUIET)
if(NOT argparse-static_FOUND)
  message(STATUS "[SRV] argparse not found, fetching from local repository..")
  fetchcontent_declare(argparse-static SOURCE_DIR ${ARGPARSE_DIR})
  list(APPEND SRV_TARGETS_TO_INSTALL argparse-static)
  list(APPEND SRV_MAKE_AVAILABLE argparse-static)
else()
  message(STATUS "[SRV] argparse found package..")
endif()

# 4c. make everything available
if(SRV_MAKE_AVAILABLE)
  fetchcontent_makeavailable(${SRV_MAKE_AVAILABLE})
endif()

# 5. Create srv_lib library target

add_library(${PROJECT_NAME}-lib STATIC ${SRV_SRCS})

target_link_libraries(
  ${PROJECT_NAME}-lib
  PRIVATE
    argparse::argparse-static
    atsdk::atlogger
    atsdk::atchops
    atsdk::mbedtls
)

# Set include directories for srv target
target_include_directories(
  ${PROJECT_NAME}-lib
  PUBLIC
    $<BUILD_INTERFACE:${SRV_INCLUDE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# 6 Install srv library
# This step configures running `cmake --build build --target install` (which is the same thing as `make install`)
# This work also helps other CMake projects use `find_package(atclient)` to find our library, once installed.
list(APPEND SRV_TARGETS_TO_INSTALL ${PROJECT_NAME}-lib) # install srv_lib

foreach(target ${SRV_TARGETS_TO_INSTALL})
  message(STATUS "[SRV] Installing ${target}..")
  install(
    TARGETS ${target}
    EXPORT ${PROJECT_NAME}-lib-config
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
endforeach()

install(
  DIRECTORY ${SRV_INCLUDE_DIR}/${PROJECT_NAME}
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# 7. Create srv executable target
add_executable(${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/src/main.c)

target_link_libraries(
  ${PROJECT_NAME}
  PRIVATE
    ${PROJECT_NAME}-lib
    atsdk::atlogger
    atsdk::atchops
    atsdk::mbedtls
    argparse::argparse-static
)

# 8. Build tests
if(SRV_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/tests)
endif()
