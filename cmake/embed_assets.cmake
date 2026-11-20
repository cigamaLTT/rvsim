foreach(_req_var IN ITEMS OUTPUT_HEADER OUTPUT_SOURCE FONT_SANS FONT_MONO)
  if(NOT DEFINED ${_req_var} OR "${${_req_var}}" STREQUAL "")
    message(FATAL_ERROR "embed_assets.cmake requires -D${_req_var}=...")
  endif()
endforeach()

function(rvsim_read_font_bytes input_path out_bytes_var out_size_var)
  if(NOT EXISTS "${input_path}")
    message(FATAL_ERROR "Font asset not found: ${input_path}")
  endif()

  file(READ "${input_path}" _hex HEX)
  string(LENGTH "${_hex}" _hex_len)
  math(EXPR _byte_len "${_hex_len} / 2")

  string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," _bytes "${_hex}")
  string(REGEX REPLACE
    "(0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],0x[0-9a-f][0-9a-f],)"
    "\\1\n"
    _bytes
    "${_bytes}"
  )

  set(${out_bytes_var} "${_bytes}" PARENT_SCOPE)
  set(${out_size_var} "${_byte_len}" PARENT_SCOPE)
endfunction()

rvsim_read_font_bytes("${FONT_SANS}" _sans_bytes _sans_size)
rvsim_read_font_bytes("${FONT_MONO}" _mono_bytes _mono_size)

get_filename_component(_header_dir "${OUTPUT_HEADER}" DIRECTORY)
get_filename_component(_source_dir "${OUTPUT_SOURCE}" DIRECTORY)
file(MAKE_DIRECTORY "${_header_dir}" "${_source_dir}")

file(WRITE "${OUTPUT_HEADER}"
"#pragma once
#include <cstddef>

namespace rvsim::assets {
extern const unsigned char kNotoSansRegularData[];
inline constexpr std::size_t kNotoSansRegularSize = ${_sans_size};

extern const unsigned char kNotoSansMonoRegularData[];
inline constexpr std::size_t kNotoSansMonoRegularSize = ${_mono_size};
}  // namespace rvsim::assets
")

file(WRITE "${OUTPUT_SOURCE}"
"#include \"embedded_fonts.h\"

namespace rvsim::assets {
const unsigned char kNotoSansRegularData[] = {
${_sans_bytes}
};

const unsigned char kNotoSansMonoRegularData[] = {
${_mono_bytes}
};
}  // namespace rvsim::assets
")
