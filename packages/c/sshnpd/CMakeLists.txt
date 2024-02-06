cmake_minimum_required(VERSION 3.19)

project(
  sshnpd
  VERSION 0.0.1
  LANGUAGES C
)

# 1. Variables - you are free to edit anything in this step

# 1a. Manually add your src files here
# globs are known as bad practice, so we do not use them here
set(SSHNPD_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/src/params.c
)

# 1b. Manually add your include directories here
set(SSHNPD_INCLUDE_DIR
  ${CMAKE_CURRENT_LIST_DIR}/include
)

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

# 4a. atclient
find_package(atclient QUIET)
if(NOT atclient_FOUND)
  # TODO: fetch from GitHub
  # message(STATUS "[SSHNPD] atclient not found, fetching from GitHub..")
  # FetchContent_Declare(
  #  atclient
  #  URL https://github.com/...
  #           URL_HASH SHA256=
  # )
  list(APPEND SSHNPD_TARGETS_TO_INSTALL atclient cJSON)
  list(APPEND SSHNPD_MAKE_AVAILABLE atclient)
else()
  message(STATUS "[SSHNPD] atclient found package..")
endif()

# 4b. atchops
find_package(atchops)
if(NOT atchops_FOUND)
  # TODO: fetch from GitHub
  # message(STATUS "[SSHNPD] atchops not found, fetching from GitHub..")
  # FetchContent_Declare(
  #  atchops
  #  URL https://github.com/...
  #           URL_HASH SHA256=
  # )
  list(APPEND SSHNPD_TARGETS_TO_INSTALL atchops uuid4-static)
  list(APPEND SSHNPD_MAKE_AVAILABLE atchops)
else()
  message(STATUS "[SSHNPD] atchops found package..")
endif()

# 4c. MbedTLS
find_package(MbedTLS QUIET)
if(NOT MbedTLS_FOUND)
  message(STATUS "[SSHNPD] MbedTLS not found, fetching from GitHub..")
  FetchContent_Declare(
   MbedTLS
   URL https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.5.1.zip
            URL_HASH SHA256=959a492721ba036afc21f04d1836d874f93ac124cf47cf62c9bcd3a753e49bdb # hash for v3.5.1 .zip release source code
  )
  list(APPEND SSHNPD_TARGETS_TO_INSTALL mbedtls mbedx509 mbedcrypto p256m everest)
  list(APPEND SSHNPD_MAKE_AVAILABLE MbedTLS)
else()
  message(STATUS "[SSHNPD] MbedTLS found package..")
endif()

# 4d. argparse
find_package(argparse-static QUIET)
if(NOT argparse-static_FOUND)
  message(STATUS "[SSHNPD] argparse not found, fetching from local repository..")
  FetchContent_Declare(
   argparse-static
   SOURCE_DIR ${ARGPARSE_DIR}
  )
  list(APPEND SSHNPD_TARGETS_TO_INSTALL argparse-static)
  list(APPEND SSHNPD_MAKE_AVAILABLE argparse-static)
else()
  message(STATUS "[SSHNPD] argparse found package..")
endif()

if(SSHNPD_MAKE_AVAILABLE)
  FetchContent_MakeAvailable(${SSHNPD_MAKE_AVAILABLE})
endif()

# 5. Create sshnpd_lib library target

add_library(${PROJECT_NAME}_lib STATIC ${SSHNPD_SRCS})

target_link_libraries(${PROJECT_NAME}_lib PRIVATE
  atclient::atclient
  argparse::argparse-static
)

# Set include directories for sshnpd target
target_include_directories(${PROJECT_NAME}_lib PUBLIC
  $<BUILD_INTERFACE:${SSHNPD_INCLUDE_DIR}>
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

target_link_libraries(${PROJECT_NAME} PRIVATE
 ${PROJECT_NAME}_lib
  atclient::atclient
  argparse::argparse-static
)

# 8. Build tests
if(SSHNPD_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/tests)
endif()
