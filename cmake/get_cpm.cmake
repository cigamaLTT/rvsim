set(CPM_DOWNLOAD_VERSION 0.43.2)
set(CPM_DOWNLOAD_HASH "49a3bef91ceb65bb66d57255e12d1ffd22abc2f6408fa9fe4534c544a2f232aa")

if(CPM_SOURCE_CACHE)
  set(CPM_DOWNLOAD_LOCATION "${CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
elseif(DEFINED ENV{CPM_SOURCE_CACHE} AND NOT "$ENV{CPM_SOURCE_CACHE}" STREQUAL "")
  set(CPM_DOWNLOAD_LOCATION "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
else()
  set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
endif()

# Expand relative path. This is important if the provided path contains a tilde (~)
get_filename_component(CPM_DOWNLOAD_LOCATION ${CPM_DOWNLOAD_LOCATION} ABSOLUTE)

if(NOT EXISTS "${CPM_DOWNLOAD_LOCATION}")
  message(STATUS "Downloading CPM.cmake v${CPM_DOWNLOAD_VERSION} to ${CPM_DOWNLOAD_LOCATION}")
  get_filename_component(_cpm_dir "${CPM_DOWNLOAD_LOCATION}" DIRECTORY)
  file(MAKE_DIRECTORY "${_cpm_dir}")
  file(DOWNLOAD
    "https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake"
    "${CPM_DOWNLOAD_LOCATION}"
    EXPECTED_HASH "SHA256=${CPM_DOWNLOAD_HASH}"
    STATUS _cpm_download_status
  )
  list(GET _cpm_download_status 0 _cpm_download_code)
  if(NOT _cpm_download_code EQUAL 0)
    list(GET _cpm_download_status 1 _cpm_download_msg)
    file(REMOVE "${CPM_DOWNLOAD_LOCATION}")
    message(FATAL_ERROR "Failed to download CPM.cmake: ${_cpm_download_msg}")
  endif()
endif()

include(${CPM_DOWNLOAD_LOCATION})
