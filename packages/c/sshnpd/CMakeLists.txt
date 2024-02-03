cmake_minimum_required(VERSION 3.19)

project(
  sshnpd
  VERSION 0.0.1
  HOMEPAGE_URL https://atsign.com
  LANGUAGES C
)

find_package(atclient REQUIRED CONFIG)
find_package(atchops)
find_package(MbedTLS)

set(ARGPARSE_DIR ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse)

include_directories(
  ${CMAKE_CURRENT_LIST_DIR}/include
  ${ARGPARSE_DIR}
)

# ON=>builds tests by running the tests/CMakeLists.txt file and generates a
# `tests/` folder in the build directory where `ctest` can be ran in that
# directory, OFF=>does not build `tests/`
option(SSHNPD_BUILD_TESTS "Build sshnpd tests" OFF)

set(ARGPARSE_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse/argparse.h
  ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse/argparse.c
)

set(SSHNPD_SRCS
  ${CMAKE_CURRENT_LIST_DIR}/include/sshnpd_params.h
  ${CMAKE_CURRENT_LIST_DIR}/include/environment.h
  ${CMAKE_CURRENT_LIST_DIR}/include/version.h
  ${CMAKE_CURRENT_LIST_DIR}/src/sshnpd_params.c

)

add_library(sshnpd_lib STATIC
  ${ARGPARSE_SRCS}
  ${SSHNPD_SRCS}
)

add_executable(sshnpd ${CMAKE_CURRENT_LIST_DIR}/src/sshnpd.c)
target_link_libraries(sshnpd PRIVATE sshnpd_lib)
target_link_libraries(sshnpd PRIVATE atclient::atclient)

if(SSHNPD_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/tests)
endif()
