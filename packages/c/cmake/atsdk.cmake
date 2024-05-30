if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  fetchcontent_declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG f599959037c64eb76b28bceb57bf390efb2067f0
  )
  fetchcontent_makeavailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
