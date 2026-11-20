cmake_minimum_required(VERSION 3.21)

project(rvsim LANGUAGES C CXX)

set(LIB_DIR external)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(MSVC)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

include(cmake/get_cpm.cmake)

CPMAddPackage(
  NAME imgui
  GITHUB_REPOSITORY ocornut/imgui
  GIT_TAG 148bd34a7e8106cd6e8dae8411a506a8e3e84f40
  DOWNLOAD_ONLY YES
)

if(NOT EMSCRIPTEN)
  CPMAddPackage(
    NAME glfw
    GITHUB_REPOSITORY glfw/glfw
    GIT_TAG 3.5.1
    OPTIONS
      "GLFW_BUILD_EXAMPLES OFF"
      "GLFW_BUILD_TESTS OFF"
      "GLFW_BUILD_DOCS OFF"
      "GLFW_INSTALL OFF"
  )
endif()

add_library(rvsim_platform INTERFACE)

if(MSVC)
  target_compile_options(rvsim_platform INTERFACE
    /utf-8
    /Zc:__cplusplus
    $<$<CONFIG:Release>:/O2>
    $<$<CONFIG:Debug>:/Od>
  )
else()
  target_compile_options(rvsim_platform INTERFACE
    $<$<CONFIG:Release>:-Os>
    $<$<CONFIG:Debug>:-O0 -g>
  )
endif()

if(EMSCRIPTEN)
  target_compile_definitions(rvsim_platform INTERFACE IMGUI_IMPL_OPENGL_ES3)
  target_compile_options(rvsim_platform INTERFACE --use-port=contrib.glfw3 -pthread)
  target_link_options(rvsim_platform INTERFACE --use-port=contrib.glfw3 -pthread)
else()
  set(THREADS_PREFER_PTHREAD_FLAG TRUE)
  find_package(OpenGL REQUIRED)
  find_package(Threads REQUIRED)

  if(APPLE)
    target_compile_definitions(rvsim_platform INTERFACE GL_SILENCE_DEPRECATION)
  endif()

  if(WIN32)
    target_compile_definitions(rvsim_platform INTERFACE NOMINMAX WIN32_LEAN_AND_MEAN)
  endif()
endif()

add_library(imgui_lib STATIC
  "${imgui_SOURCE_DIR}/imgui.cpp"
  "${imgui_SOURCE_DIR}/imgui_demo.cpp"
  "${imgui_SOURCE_DIR}/imgui_draw.cpp"
  "${imgui_SOURCE_DIR}/imgui_tables.cpp"
  "${imgui_SOURCE_DIR}/imgui_widgets.cpp"
  "${imgui_SOURCE_DIR}/misc/cpp/imgui_stdlib.cpp"
  "${imgui_SOURCE_DIR}/backends/imgui_impl_glfw.cpp"
  "${imgui_SOURCE_DIR}/backends/imgui_impl_opengl3.cpp"
)

target_include_directories(imgui_lib SYSTEM PUBLIC
  "${imgui_SOURCE_DIR}"
  "${imgui_SOURCE_DIR}/backends"
)

target_link_libraries(imgui_lib PUBLIC rvsim_platform)

if(NOT EMSCRIPTEN)
  target_link_libraries(imgui_lib PUBLIC glfw)
endif()

add_library(imgui_text_editor STATIC
  "${LIB_DIR}/text_editor/TextEditor.cpp"
)

target_include_directories(imgui_text_editor SYSTEM PUBLIC
  "${LIB_DIR}/text_editor"
)

target_link_libraries(imgui_text_editor PUBLIC imgui_lib)

set(GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(EMBEDDED_FONTS_HEADER "${GENERATED_DIR}/embedded_fonts.h")
set(EMBEDDED_FONTS_SOURCE "${GENERATED_DIR}/embedded_fonts.cpp")
set(FONT_SANS "${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts/NotoSans-Regular.ttf")
set(FONT_MONO "${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts/NotoSansMono-Regular.ttf")

add_custom_command(
  OUTPUT "${EMBEDDED_FONTS_HEADER}" "${EMBEDDED_FONTS_SOURCE}"
  COMMAND ${CMAKE_COMMAND}
    -DOUTPUT_HEADER=${EMBEDDED_FONTS_HEADER}
    -DOUTPUT_SOURCE=${EMBEDDED_FONTS_SOURCE}
    -DFONT_SANS=${FONT_SANS}
    -DFONT_MONO=${FONT_MONO}
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_assets.cmake"
  DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_assets.cmake"
    "${FONT_SANS}"
    "${FONT_MONO}"
  COMMENT "Embedding font assets into generated C++ sources"
  VERBATIM
)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp")

add_executable(rvsim
  ${SOURCES}
  "${EMBEDDED_FONTS_SOURCE}"
  "${EMBEDDED_FONTS_HEADER}"
)

target_include_directories(rvsim PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/src"
  "${CMAKE_CURRENT_SOURCE_DIR}/${LIB_DIR}"
  "${GENERATED_DIR}"
)

target_link_libraries(rvsim PRIVATE imgui_lib imgui_text_editor)

target_compile_options(rvsim PRIVATE
  $<IF:$<BOOL:${MSVC}>,/W4,-Wall -Wextra>
)

if(EMSCRIPTEN)
  set_target_properties(rvsim PROPERTIES
    OUTPUT_NAME "index"
    SUFFIX ".html"
  )

  target_link_options(rvsim PRIVATE
    -sPTHREAD_POOL_SIZE=2
    -sALLOW_MEMORY_GROWTH=1
    -sMAXIMUM_MEMORY=1GB
    "--shell-file=${CMAKE_CURRENT_SOURCE_DIR}/shell_minimal.html"
    $<$<CONFIG:Debug>:-sASSERTIONS=1>
  )

  add_custom_command(TARGET rvsim POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${CMAKE_CURRENT_SOURCE_DIR}/web/coi-serviceworker.js"
      "$<TARGET_FILE_DIR:rvsim>/coi-serviceworker.js"
  )
else()
  target_link_libraries(rvsim PRIVATE OpenGL::GL Threads::Threads)

  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND
     CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 14 AND
     CMAKE_CXX_COMPILER_VERSION VERSION_LESS 15)
    target_link_libraries(rvsim PRIVATE stdc++exp)
  endif()

  target_link_options(rvsim PRIVATE
    $<$<AND:$<PLATFORM_ID:Linux>,$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-static-libstdc++ -static-libgcc>
  )

  if(WIN32)
    set_target_properties(rvsim PROPERTIES WIN32_EXECUTABLE $<CONFIG:Release>)
    if(MSVC)
      target_link_options(rvsim PRIVATE $<$<CONFIG:Release>:/ENTRY:mainCRTStartup>)
    endif()
  endif()
endif()
