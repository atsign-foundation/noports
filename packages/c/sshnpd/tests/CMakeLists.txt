file(GLOB_RECURSE files ${CMAKE_CURRENT_LIST_DIR}/test_*.c)
foreach(file ${files})
  # ${filename} - without `.c`
  get_filename_component(filename ${file} NAME)
  string(REPLACE ".c" "" filename ${filename})

  add_executable(${filename} ${file})
  target_link_libraries(
    ${filename}
    PRIVATE sshnpd-lib argparse::argparse-static atlogger
  )
  add_test(NAME ${filename} COMMAND $<TARGET_FILE:${filename}>)
endforeach()
