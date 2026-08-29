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
      # PLACEHOLDER - update before merge: pinned to the at_c#709 PR branch
      # head (atchops_rsa_encrypt output-buffer bound, breaking signature
      # change). Replace with the at_c release SHA that contains #709 once it
      # merges and is released.
      GIT_TAG 05295c51791a17a8118361cd02d6b5e7ed6b845e
    )
  endif()
  FetchContent_MakeAvailable(atsdk)
  install(
    TARGETS atclient atchops atlogger atauth atcommons
  )
endif()
