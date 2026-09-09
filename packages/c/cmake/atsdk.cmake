option(NOPORTS_ATSDK_PATH "Local atsdk path" OFF)
if(NOT atsdk_FOUND)
  message(STATUS "[atsdk] fetching package...")
  include(FetchContent)
  if(NOPORTS_ATSDK_PATH)
    FetchContent_Declare(
      atsdk
      SOURCE_DIR
      ${CMAKE_SOURCE_DIR}/${NOPORTS_ATSDK_PATH}
    )
  else()
    FetchContent_Declare(
      atsdk
      GIT_REPOSITORY https://github.com/atsign-foundation/at_c.git
      # at_c 0.4.1 (trunk merge of the at_c#716 release prep): atauth and
      # onboarding code-review fixes (at_c#715) on top of v0.4.0; repoint
      # to the v0.4.1 tag once at_c cuts the release
      GIT_TAG 60ba6ec38c5cfa78929f709291dcd9f2ad9ddbac
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
