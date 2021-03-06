
cl_flags_global_group = 2

set_global('cl_base_flags', table.concat({
   '/nologo',
   '/c',
   '/showIncludes',
   '/utf-8',
   '/FS',
   '/Gd',   -- __cdecl calling convention
   '/Gm-',  -- Disable minimal rebuild
   '/Gy',   -- Enable function-level linking
   '/GF',   -- Enable string pooling
   '/Zi',   -- Create PDB
   '/EHs',  -- C++ exceptions
   '/fp:precise',
   '/volatile:iso',
   '/w44746', -- Enable volatile access warning
   '/Qpar',
   '/Zc:rvalueCast',
   '/diagnostics:caret',
   '/errorReport:prompt'
}, ' '), cl_flags_global_group)

set_global('cl_base_defines', serialize_defines {
   _WINDOWS = '',
   SYSTEM_WINDOWS = '',
   WIN32 = '',
   _WIN32 = '',
   _WIN32_WINNT = '0x0601'
}, cl_flags_global_group)

make_rule 'cl' {
   command = table.concat({
      'cl',
      '$cl_base_flags',
      '$flags',
      '$cl_base_defines',
      '$extra',
      serialize_includes {
         include_dir(),
         deps_dir(),
         ext_include_dir(),
         nil
      },
      '/Fo"$out"',
      '/Fd"$pdb"',
      '"$in"'
   }, ' '),
   description = 'cl $in',
   deps = 'msvc'
}

function configure_cl_flags (configured, define, disable_warning, option, name_suffix)
   if configured.force_cxx then
      name_suffix 'cxx'
      option '/TP'
   elseif configured.force_c then
      name_suffix 'c'
      option '/TC'
   end

   if configured.test_type then
      if configured.test_type == 'perf' then
         name_suffix 'perf'
         define 'BE_TEST_PERF'
      else
         name_suffix 'test'
         define 'BE_TEST'
      end
      disable_warning(4702) -- Unreachable code
   end

   if configured.rtti then
      name_suffix 'rtti'
      option '/GR'
   else
      option '/GR-'
      define 'BOOST_NO_TYPEID'
      define 'BOOST_NO_RTTI'
   end

   -- TODO remove these when boost has been updated to avoid these
   define '_SILENCE_CXX17_ALLOCATOR_VOID_DEPRECATION_WARNING'
   define '_SILENCE_CXX17_RESULT_OF_DEPRECATION_WARNING'
   define '_SILENCE_CXX17_ITERATOR_BASE_CLASS_DEPRECATION_WARNING'

   define 'BOOST_CONFIG_SUPPRESS_OUTDATED_MESSAGE'

   if configured.is_ext_lib then
      name_suffix 'extlib'
      option '/GA'    -- TLS Optimization
      option '/W3'    -- Warning level 3
      option '/Zm120' -- increase PCH memory allocation limit (glbinding)
      define '_CRT_SECURE_NO_WARNINGS'
      define '_SCL_SECURE_NO_WARNINGS'
      disable_warning(4334) -- result of 32-bit shift implicitly converted to 64 bits (Lua)
      disable_warning(4267) -- narrowing conversion (zlib)
   else
      if configured.is_dyn_lib then
         name_suffix 'dll'
      elseif configured.is_lib then
         name_suffix 'lib'
         define 'BE_STATIC_LIB'
         option '/GA'         -- TLS Optimization
      else
         option '/GA'         -- TLS Optimization
         option '/Gw'         -- Optimize globals
         option '/Zc:inline'  -- Remove unused symbols
      end

      option '/std:c++latest'
      define 'BE_NO_LEAKCHECK' -- VLD installer only adds paths to MSBuild config, not vcvarsall.bat
      define 'BE_ID_EXTERNS'
      define 'NOMINMAX'
      define('_HAS_AUTO_PTR_ETC', 1)
      define('SQLITE_WIN32_GETVERSIONEX', 0)
      define 'GLM_ENABLE_EXPERIMENTAL'
      define 'GLM_FORCE_SSE3'
      option '/permissive-'
      option '/W4'          -- warning level 4
      option '/w15038'      -- member initialization order
      option '/WX'          -- warnings are errors
      disable_warning(4065) -- switch with no case:
      disable_warning(4100) -- unreferenced parameter
      disable_warning(4201) -- nameless struct/union
      disable_warning(4310) -- cast truncates constant value
      disable_warning(4324) -- struct padding due to alignas()
      disable_warning(4458) -- declaration hides class member
      disable_warning(4503) -- 'identifier' : decorated name length exceeded, name was truncated
      disable_warning(4505) -- unreferenced local function has been removed
      disable_warning(5030) -- Unrecognized attribute

      --disable_warning(4351) -- elements of array 'array' will be default initialized

      if configured.configuration == 'debug' then
         define 'BE_DEBUG'
         define 'BE_DEBUG_TIMERS'
         define 'BE_ENABLE_MAIN_THREAD_ASSERTIONS'
      else
         define 'GSL_UNENFORCED_ON_CONTRACT_VIOLATION'
      end
   end

   if configured.configuration == 'debug' then
      name_suffix 'debug'
      define '_DEBUG'
      define 'DEBUG'
      option '/Od'   -- Disable optimization
      option '/MDd'  -- Multithreaded Debug DLL CRT
      option '/RTC1' -- Runtime stack/uninitialized checks
      option '/sdl-' -- Disable extra SDL checks
      option '/GS'   -- buffer overrun check
   else
      name_suffix 'release'
      define 'NDEBUG'
      option '/Ox'   -- Full optimization
      option '/MD'   -- Multithreaded DLL CRT
      option '/GL'   -- Whole Program Optimization
      -- option '/sdl-' -- Disable extra SDL checks -- implied by /GS-
      option '/GS-'  -- Disable buffer overrun check
   end
end
