set(_ros_idl_files "")
foreach(_idl_file ${rosidl_generate_interfaces_IDL_FILES})
  get_filename_component(_extension "${_idl_file}" EXT)
  # Skip .srv files
  if(_extension STREQUAL ".msg")
    list(APPEND _ros_idl_files "${_idl_file}")
  endif()
endforeach()

rosidl_generate_dds_interfaces(
  ${rosidl_generate_interfaces_TARGET}__dds_coredds_idl
  IDL_FILES ${_ros_idl_files}
  DEPENDENCY_PACKAGE_NAMES ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES}
  OUTPUT_SUBFOLDERS "dds_coredds"
)

set(_dds_idl_files "")
set(_dds_idl_base_path "${CMAKE_CURRENT_BINARY_DIR}/rosidl_generator_dds_idl")
foreach(_idl_file ${rosidl_generate_interfaces_IDL_FILES})
  get_filename_component(_extension "${_idl_file}" EXT)
  if(_extension STREQUAL ".msg")
    get_filename_component(_parent_folder "${_idl_file}" DIRECTORY)
    get_filename_component(_parent_folder "${_parent_folder}" NAME)
    get_filename_component(_name "${_idl_file}" NAME_WE)
    list(APPEND _dds_idl_files
      "${_dds_idl_base_path}/${PROJECT_NAME}/${_parent_folder}/dds_coredds/${_name}_.idl")
  endif()
endforeach()

set(_output_path "${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp/${PROJECT_NAME}")
set(_generated_files "")
set(_generated_external_files "")
foreach(_idl_file ${rosidl_generate_interfaces_IDL_FILES})
  get_filename_component(_extension "${_idl_file}" EXT)
  get_filename_component(_parent_folder "${_idl_file}" DIRECTORY)
  get_filename_component(_parent_folder "${_parent_folder}" NAME)
  get_filename_component(_msg_name "${_idl_file}" NAME_WE)
  string_camel_case_to_lower_case_underscore("${_msg_name}" _header_name)
  if(_extension STREQUAL ".msg")
    set(_allowed_parent_folders "msg" "srv" "action")
    if(NOT _parent_folder IN_LIST _allowed_parent_folders)
      message(FATAL_ERROR "Interface file with unknown parent folder: ${_idl_file}")
    endif()
    list(APPEND _generated_external_files "${_output_path}/${_parent_folder}/dds_coredds/src/${PROJECT_NAME}_${_parent_folder}_dds__${_msg_name}_TypeSupport.c")
    list(APPEND _generated_external_files "${_output_path}/${_parent_folder}/dds_coredds/include/${PROJECT_NAME}/${_parent_folder}/dds_/${_msg_name}_TypeSupport.h")
    list(APPEND _generated_external_files "${_output_path}/${_parent_folder}/dds_coredds/include/${PROJECT_NAME}/${_parent_folder}/dds_/${_msg_name}_.h")
    #list(APPEND _generated_external_files "${_output_path}/${_parent_folder}/dds_coredds/include/${PROJECT_NAME}/${_parent_folder}/dds_/1common.h")
    list(APPEND _generated_files "${_output_path}/${_parent_folder}/${_header_name}__rosidl_typesupport_coredds_cpp.hpp")
    list(APPEND _generated_files "${_output_path}/${_parent_folder}/dds_coredds/${_header_name}__type_support.cpp")

  elseif(_extension STREQUAL ".srv")
    set(_allowed_parent_folders "srv" "action")
    if(NOT _parent_folder IN_LIST _allowed_parent_folders)
      message(FATAL_ERROR "Interface file with unknown parent folder: ${_idl_file}")
    endif()
    list(APPEND _generated_files "${_output_path}/${_parent_folder}/${_header_name}__rosidl_typesupport_coredds_cpp.hpp")
    list(APPEND _generated_files "${_output_path}/${_parent_folder}/dds_coredds/${_header_name}__type_support.cpp")
  else()
    message(FATAL_ERROR "Interface file with unknown extension: ${_idl_file}")
  endif()
endforeach()

set(_dependency_files "")
set(_dependencies "")
foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
  foreach(_idl_file ${${_pkg_name}_INTERFACE_FILES})
  get_filename_component(_extension "${_idl_file}" EXT)
    if(_extension STREQUAL ".msg")
      get_filename_component(_parent_folder "${_idl_file}" DIRECTORY)
      get_filename_component(_parent_folder "${_parent_folder}" NAME)
      get_filename_component(_name "${_idl_file}" NAME_WE)
      set(_abs_idl_file "${${_pkg_name}_DIR}/../${_parent_folder}/dds_coredds/${_name}_.idl")
      normalize_path(_abs_idl_file "${_abs_idl_file}")
      list(APPEND _dependency_files "${_abs_idl_file}")
      set(_abs_idl_file "${${_pkg_name}_DIR}/../${_idl_file}")
      normalize_path(_abs_idl_file "${_abs_idl_file}")
      list(APPEND _dependencies "${_pkg_name}:${_abs_idl_file}")
    endif()
  endforeach()
endforeach()

set(target_dependencies
  "${rosidl_typesupport_coredds_cpp_BIN}"
  ${rosidl_typesupport_coredds_cpp_GENERATOR_FILES}
  "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}/msg__rosidl_typesupport_coredds_cpp.hpp.em"
  "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}/msg__type_support.cpp.em"
  "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}/srv__rosidl_typesupport_coredds_cpp.hpp.em"
  "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}/srv__type_support.cpp.em"
  ${rosidl_generate_interfaces_IDL_FILES}
  ${_dependency_files})
foreach(dep ${target_dependencies})
  if(NOT EXISTS "${dep}")
    get_property(is_generated SOURCE "${dep}" PROPERTY GENERATED)
    if(NOT ${_is_generated})
      message(FATAL_ERROR "Target dependency '${dep}' does not exist")
    endif()
  endif()
endforeach()

set(generator_arguments_file "${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp__arguments.json")
rosidl_write_generator_arguments(
  "${generator_arguments_file}"
  PACKAGE_NAME "${PROJECT_NAME}"
  ROS_INTERFACE_FILES "${rosidl_generate_interfaces_IDL_FILES}"
  ROS_INTERFACE_DEPENDENCIES "${_dependencies}"
  OUTPUT_DIR "${_output_path}"
  TEMPLATE_DIR "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}"
  TARGET_DEPENDENCIES ${target_dependencies}
  ADDITIONAL_FILES ${_dds_idl_files}
)

set(_idl_pp "${CoreDDS_COREIDL}")
add_custom_command(
  OUTPUT ${_generated_files} ${_generated_external_files}
  COMMAND ${PYTHON_EXECUTABLE} ${rosidl_typesupport_coredds_cpp_BIN}
  --generator-arguments-file "${generator_arguments_file}"
  --dds-interface-base-path "${_dds_idl_base_path}"
  --idl-pp "${_idl_pp}"
  DEPENDS ${target_dependencies} ${_dds_idl_files}
  COMMENT "Generating C++ type support for CoreDDS (using '${_idl_pp}'"
  VERBATIM
)

# generate header to switch between export and import for a specific package
set(_visibility_control_file
"${_output_path}/msg/rosidl_typesupport_coredds_cpp__visibility_control.h")
string(TOUPPER "${PROJECT_NAME}" PROJECT_NAME_UPPER)
configure_file(
  "${rosidl_typesupport_coredds_cpp_TEMPLATE_DIR}/rosidl_typesupport_coredds_cpp__visibility_control.h.in"
  "${_visibility_control_file}"
  @ONLY
)

set(_target_suffix "__rosidl_typesupport_coredds_cpp")

link_directories(${coredds_LIBRARY_DIRS})
add_library(${rosidl_generate_interfaces_TARGET}${_target_suffix} SHARED
  ${_generated_files} ${_generated_external_files})
if(rosidl_generate_interfaces_LIBRARY_NAME)
  set_target_properties(${rosidl_generate_interfaces_TARGET}${_target_suffix}
    PROPERTIES OUTPUT_NAME "${rosidl_generate_interfaces_LIBRARY_NAME}${_target_suffix}")
endif()
set_target_properties(${rosidl_generate_interfaces_TARGET}${_target_suffix}
  PROPERTIES CXX_STANDARD 14)
if(WIN32)
  target_compile_definitions(${rosidl_generate_interfaces_TARGET}${_target_suffix}
    PRIVATE "ROSIDL_TYPESUPPORT_COREDDS_CPP_BUILDING_DLL_${PROJECT_NAME}")
endif()
if(NOT WIN32)
  set(_target_compile_flags "-Wall -Wextra -Wpedantic")
else()
  set(_target_compile_flags
    "/W4"
  )
endif()
string(REPLACE ";" " " _target_compile_flags "${_target_compile_flags}")
set_target_properties(${rosidl_generate_interfaces_TARGET}${_target_suffix}
  PROPERTIES COMPILE_FLAGS "${_target_compile_flags}")
target_include_directories(${rosidl_generate_interfaces_TARGET}${_target_suffix}
  PUBLIC
  ${CMAKE_CURRENT_BINARY_DIR}/rosidl_generator_cpp
  ${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp
  ${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp/${PROJECT_NAME}/msg/dds_coredds/include
  ${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp/${PROJECT_NAME}/srv/dds_coredds/include
  ${CMAKE_CURRENT_BINARY_DIR}/rosidl_typesupport_coredds_cpp/${PROJECT_NAME}/action/dds_coredds/include
)
ament_target_dependencies(${rosidl_generate_interfaces_TARGET}${_target_suffix}
  "CoreDDS"
  "rmw"
  "rosidl_typesupport_coredds_cpp"
  "rosidl_typesupport_interface")
foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
  set(_msg_include_dir "${${_pkg_name}_DIR}/../../../include/${_pkg_name}/msg/dds_coredds")
  set(_srv_include_dir "${${_pkg_name}_DIR}/../../../include/${_pkg_name}/srv/dds_coredds")
  set(_action_include_dir "${${_pkg_name}_DIR}/../../../include/${_pkg_name}/action/dds_coredds")
  normalize_path(_msg_include_dir "${_msg_include_dir}")
  normalize_path(_srv_include_dir "${_srv_include_dir}")
  normalize_path(_action_include_dir "${_action_include_dir}")
  target_include_directories(${rosidl_generate_interfaces_TARGET}${_target_suffix}
    PUBLIC
    "${_msg_include_dir}"
    "${_srv_include_dir}"
    "${_action_include_dir}"
  )
  ament_target_dependencies(${rosidl_generate_interfaces_TARGET}${_target_suffix}
    ${_pkg_name})
  target_link_libraries(${rosidl_generate_interfaces_TARGET}${_target_suffix}
    ${${_pkg_name}_LIBRARIES${_target_suffix}})
endforeach()

add_dependencies(
  ${rosidl_generate_interfaces_TARGET}
  ${rosidl_generate_interfaces_TARGET}${_target_suffix}
)
add_dependencies(
  ${rosidl_generate_interfaces_TARGET}${_target_suffix}
  ${rosidl_generate_interfaces_TARGET}__cpp
)
add_dependencies(
  ${rosidl_generate_interfaces_TARGET}__dds_coredds_idl
  ${rosidl_generate_interfaces_TARGET}${_target_suffix}
)

if(NOT rosidl_generate_interfaces_SKIP_INSTALL)
  install(
    DIRECTORY "${_output_path}/"
    DESTINATION "include/${PROJECT_NAME}"
    PATTERN "*.cpp" EXCLUDE
  )

  if(
    NOT _generated_files STREQUAL "" OR
    NOT _generated_external_files STREQUAL ""
  )
    ament_export_include_directories(include)
  endif()

  install(
    TARGETS ${rosidl_generate_interfaces_TARGET}${_target_suffix}
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
  )

#ament_export_libraries(${rosidl_generate_interfaces_TARGET}${_target_suffix})
  rosidl_export_typesupport_libraries(${_target_suffix}
    ${rosidl_generate_interfaces_TARGET}${_target_suffix})
endif()

if(BUILD_TESTING AND rosidl_generate_interfaces_ADD_LINTER_TESTS)
  if(NOT _generated_files STREQUAL "")
    find_package(ament_cmake_cppcheck REQUIRED)
    ament_cppcheck(
      TESTNAME "cppcheck_rosidl_typesupport_coredds_cpp"
      ${_generated_files})

    find_package(ament_cmake_cpplint REQUIRED)
    get_filename_component(_cpplint_root "${_output_path}" DIRECTORY)
    ament_cpplint(
      TESTNAME "cpplint_rosidl_typesupport_coredds_cpp"
      # the generated code might contain longer lines for templated types
      MAX_LINE_LENGTH 999
      ROOT "${_cpplint_root}"
      ${_generated_files})

    find_package(ament_cmake_uncrustify REQUIRED)
    ament_uncrustify(
      TESTNAME "uncrustify_rosidl_typesupport_coredds_cpp"
      # the generated code might contain longer lines for templated types
      # set the value to zero to tell uncrustify to ignore line lengths
      MAX_LINE_LENGTH 0
      ${_generated_files})
  endif()
endif()