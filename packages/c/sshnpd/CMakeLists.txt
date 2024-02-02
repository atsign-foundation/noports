cmake_minimum_required(VERSION 3.19)

project(sshnpd)

find_package(atclient REQUIRED CONFIG)
find_package(atchops)
find_package(MbedTLS)

set(ARGPARSE_DIR ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse)

include_directories(
  ${CMAKE_CURRENT_LIST_DIR}/include
  ${ARGPARSE_DIR}
)

set(SOURCES
  ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse/argparse.h
  ${CMAKE_CURRENT_LIST_DIR}/3rdparty/argparse/argparse.c
  ${CMAKE_CURRENT_LIST_DIR}/include/params.h
  ${CMAKE_CURRENT_LIST_DIR}/src/params.c
  ${CMAKE_CURRENT_LIST_DIR}/src/main.c
)

add_executable(sshnpd ${SOURCES})
target_link_libraries(sshnpd PRIVATE atclient::atclient)

