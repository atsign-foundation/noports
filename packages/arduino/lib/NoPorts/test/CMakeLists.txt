# Host-run tests for the NoPorts library's plain-C modules
cmake_minimum_required(VERSION 3.19)
project(noports_arduino_host_tests LANGUAGES C)

set(CMAKE_C_STANDARD 99)
enable_testing()

add_executable(test_policy_limits test_policy_limits.c ${CMAKE_CURRENT_LIST_DIR}/../src/noports_policy_limits.c)
target_include_directories(test_policy_limits PRIVATE ${CMAKE_CURRENT_LIST_DIR}/../src)
add_test(NAME test_policy_limits COMMAND test_policy_limits)
