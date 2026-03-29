cmake_minimum_required(VERSION 3.20)

foreach(v COMPILER CLANG SRC OUT_BIN ROOT)
  if(NOT DEFINED ${v} OR "${${v}}" STREQUAL "")
    message(FATAL_ERROR "Missing required -D${v}=...")
  endif()
endforeach()

if(NOT DEFINED CODEGEN_MODE OR "${CODEGEN_MODE}" STREQUAL "")
  set(CODEGEN_MODE "frontend")
endif()

set(expected_file "${SRC}.expected")
if(EXISTS "${expected_file}")
  file(READ "${expected_file}" expected_output)
else()
  set(expected_output "")
endif()

get_filename_component(out_bin_dir "${OUT_BIN}" DIRECTORY)
file(MAKE_DIRECTORY "${out_bin_dir}")
if(DEFINED OUT_LL AND NOT "${OUT_LL}" STREQUAL "")
  get_filename_component(out_ll_dir "${OUT_LL}" DIRECTORY)
  file(MAKE_DIRECTORY "${out_ll_dir}")
endif()

find_program(BASH_EXECUTABLE NAMES bash)
if(NOT BASH_EXECUTABLE)
  message(FATAL_ERROR "bash is required for piped test execution")
endif()

if(CODEGEN_MODE STREQUAL "frontend")
  execute_process(
    COMMAND "${BASH_EXECUTABLE}" "-lc"
            "front_err=$(mktemp); back_err=$(mktemp); \
             \"${COMPILER}\" \"${SRC}\" 2>\"\${front_err}\" | \"${CLANG}\" -x ir - -o \"${OUT_BIN}\" -lm 2>\"\${back_err}\"; \
             st_front=\${PIPESTATUS[0]}; st_back=\${PIPESTATUS[1]}; \
             if [ \${st_front} -ne 0 ]; then cat \"\${front_err}\"; rm -f \"\${front_err}\" \"\${back_err}\"; exit 101; fi; \
             if [ \${st_back} -ne 0 ]; then cat \"\${back_err}\"; rm -f \"\${front_err}\" \"\${back_err}\"; exit 102; fi; \
             rm -f \"\${front_err}\" \"\${back_err}\""
    RESULT_VARIABLE pipe_rc
    OUTPUT_VARIABLE pipe_out
    ERROR_VARIABLE pipe_err
  )
  if(pipe_rc EQUAL 101)
    message(FATAL_ERROR "[FRONTEND_FAIL] ${SRC}\n${pipe_out}${pipe_err}")
  endif()
  if(pipe_rc EQUAL 102)
    message(FATAL_ERROR "[BACKEND_FAIL] ${SRC}\n${pipe_out}${pipe_err}")
  endif()
  if(NOT pipe_rc EQUAL 0)
    message(FATAL_ERROR "[COMPILE_PIPE_FAIL] ${SRC}\n${pipe_out}${pipe_err}")
  endif()
elseif(CODEGEN_MODE STREQUAL "backend-x86_64")
  foreach(v OUT_LL TARGET_TRIPLE)
    if(NOT DEFINED ${v} OR "${${v}}" STREQUAL "")
      message(FATAL_ERROR "Missing required -D${v}=... for CODEGEN_MODE=${CODEGEN_MODE}")
    endif()
  endforeach()

  execute_process(
    COMMAND "${COMPILER}" --codegen lir --target "${TARGET_TRIPLE}" "${SRC}" -o "${OUT_LL}"
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE front_rc
    OUTPUT_VARIABLE front_out
    ERROR_VARIABLE front_err
  )
  if(NOT front_rc EQUAL 0)
    message(FATAL_ERROR "[FRONTEND_FAIL] ${SRC}\n${front_out}${front_err}")
  endif()
  if(NOT EXISTS "${OUT_LL}")
    message(FATAL_ERROR "[BACKEND_OUTPUT_MISSING] ${SRC}\nexpected backend output at ${OUT_LL}")
  endif()

  file(READ "${OUT_LL}" backend_output LIMIT 256)
  if(NOT backend_output MATCHES "(^|\n)\\.text(\n|$)")
    message(FATAL_ERROR
      "[BACKEND_FALLBACK_IR] ${SRC}\n"
      "expected backend asm output for ${TARGET_TRIPLE}, but backend output did not start the asm path")
  endif()

  execute_process(
    COMMAND "${CLANG}" "--target=${TARGET_TRIPLE}" -x assembler "${OUT_LL}" -o "${OUT_BIN}" -lm
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE back_rc
    OUTPUT_VARIABLE back_out
    ERROR_VARIABLE back_err
  )
  if(NOT back_rc EQUAL 0)
    message(FATAL_ERROR "[BACKEND_FAIL] ${SRC}\n${back_out}${back_err}")
  endif()
else()
  message(FATAL_ERROR "Unsupported CODEGEN_MODE='${CODEGEN_MODE}'")
endif()

execute_process(
  COMMAND "${OUT_BIN}"
  RESULT_VARIABLE run_rc
  OUTPUT_VARIABLE run_out
  ERROR_VARIABLE run_err
)
set(actual_output "${run_out}${run_err}")
if(NOT run_rc EQUAL 0)
  message(FATAL_ERROR "[RUNTIME_NONZERO] ${SRC} exit=${run_rc}\nstdout+stderr:\n${actual_output}")
endif()

if(NOT actual_output STREQUAL expected_output)
  message(FATAL_ERROR "[RUNTIME_MISMATCH] ${SRC}\nexpected:\n${expected_output}\nactual:\n${actual_output}")
endif()

message(STATUS "[PASS] ${SRC}")
