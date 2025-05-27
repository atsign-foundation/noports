cmake_minimum_required(VERSION 3.19)
set(CMAKE_C_STANDARD 99)
cmake_policy(SET CMP0135 NEW)
project(graceful-shutdown-tool VERSION 1.0.9 LANGUAGES C)

include(FetchContent)
include(GNUInstallDirs)
cmake_policy(SET CMP0135 NEW)

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/atsdk.cmake)
add_executable(${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/main.c)

target_link_libraries(
  ${PROJECT_NAME}
  PRIVATE atclient atchops atlogger cjson argparse::argparse-static
)
