if(NOT atsdk_FOUND)
  message(STATUS "atsdk not found, fetching from GitHub..")
  fetchcontent_declare(
    atsdk
    GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
    GIT_TAG 5cddbc775ae57a7f07f97c9b922edf063996921f
  )
  fetchcontent_makeavailable(atsdk)
  install(TARGETS atclient atchops atlogger)
else()
  message(STATUS "atsdk already installed...")
endif()
