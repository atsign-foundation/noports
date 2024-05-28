if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  fetchcontent_declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG a95a94697c47358e99ca9f4734dea752dccc5042
  )
  fetchcontent_makeavailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
