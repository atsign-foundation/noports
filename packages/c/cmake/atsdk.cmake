if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  fetchcontent_declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG e43ba4e9a3ce04ed02e3469f49656d4d887361f3
  )
  fetchcontent_makeavailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
