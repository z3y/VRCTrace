# CMake generated Testfile for 
# Source directory: D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src
# Build directory: D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-build
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test([=[tiny_bvh_minimal]=] "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-build/Debug/tiny_bvh_minimal.exe")
  set_tests_properties([=[tiny_bvh_minimal]=] PROPERTIES  _BACKTRACE_TRIPLES "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;150;add_test;D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test([=[tiny_bvh_minimal]=] "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-build/Release/tiny_bvh_minimal.exe")
  set_tests_properties([=[tiny_bvh_minimal]=] PROPERTIES  _BACKTRACE_TRIPLES "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;150;add_test;D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test([=[tiny_bvh_minimal]=] "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-build/MinSizeRel/tiny_bvh_minimal.exe")
  set_tests_properties([=[tiny_bvh_minimal]=] PROPERTIES  _BACKTRACE_TRIPLES "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;150;add_test;D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test([=[tiny_bvh_minimal]=] "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-build/RelWithDebInfo/tiny_bvh_minimal.exe")
  set_tests_properties([=[tiny_bvh_minimal]=] PROPERTIES  _BACKTRACE_TRIPLES "D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;150;add_test;D:/Unity/Projects/VRCTrace/Packages/com.z3y.vrctrace/Runtime/tinybvh/src~/build/_deps/tinybvh-src/CMakeLists.txt;0;")
else()
  add_test([=[tiny_bvh_minimal]=] NOT_AVAILABLE)
endif()
