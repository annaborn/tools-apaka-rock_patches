module OroGen
    module Gen
        module RTT_CPP
        # Returns the directory where Orogen's lib part sits (i.e. where
        # autobuild.rb and autobuild/ are)
        def self.base_dir
            File.expand_path(File.join('..', '..'), File.dirname(__FILE__))
        end

        # call-seq:
        #   touch path1, path2, ..., file_name
        #
        # Creates an empty file path1/path2/.../file_name
        def self.touch(*args)
            path = File.expand_path(File.join(*args))
            FileUtils.touch path
            generated_files << path
        end

        # Returns the C++ code which changes the current namespace from +old+
        # to +new+. +indent_size+ is the count of indent spaces between
        # namespaces.
        def self.adapt_namespace(old, new, indent_size = 4)
            old = old.split('/').delete_if { |v| v.empty? }
            new = new.split('/').delete_if { |v| v.empty? }
            indent = old.size * indent_size

            result = ""

            while !old.empty? && old.first == new.first
                old.shift
                new.shift
            end
            while !old.empty?
                indent -= indent_size
                result << " " * indent + "}\n"
                old.shift
            end
            while !new.empty?
                result << "#{" " * indent}namespace #{new.first} {\n"
                indent += indent_size
                new.shift
            end

            result
        end

        class BuildDependency
            attr_reader :var_name
            attr_reader :pkg_name

            attr_reader :context

            def initialize(var_name, pkg_name)
                @var_name = var_name.gsub(/[^\w]/, '_')
                @pkg_name = pkg_name
                @context = []
            end

            def in_context(*args)
                context << args.to_set
                self
            end

            def remove_context(*args)
                args = args.to_set
                @context = context.dup
                context.delete_if do |ctx|
                    (args & ctx).size == args.size
                end
                self
            end

            def in_context?(*args)
                args = args.to_set
                context.any? do |ctx|
                    (args & ctx).size == args.size
                end
            end
        end

        def self.cmake_pkgconfig_require(depspec, context = 'core')
            cmake_txt = "set(DEPS_CFLAGS_OTHER \"\")\n"
            cmake_txt += depspec.inject([]) do |result, s|
                result << "orogen_pkg_check_modules(#{s.var_name} REQUIRED #{s.pkg_name})"
                if s.in_context?(context, 'include')
                    result << "include_directories(${#{s.var_name}_INCLUDE_DIRS})"
                    result << "list(APPEND DEPS_CFLAGS_OTHER ${#{s.var_name}_CFLAGS_OTHER})"
                end
                if s.in_context?(context, 'link')
                    result << "list(APPEND DEPS_LINK_LIBRARIES ${#{s.var_name}_LIBRARY_DIRS})"
                end
                result
            end.join("\n") + "\n"
            cmake_txt += "list(REMOVE_DUPLICATES DEPS_CFLAGS_OTHER)\n"
            cmake_txt += "add_definitions(${DEPS_CFLAGS_OTHER})\n"
            cmake_txt += "foreach(LIB ${DEPS_LINK_LIBRARIES})\n"
            cmake_txt += "    # This is a workaround, but only fixes the issues\n"
            cmake_txt += "    # when the same install prefix is being used\n"
            cmake_txt += "    # Aim for separate prefixes for include and library directories\n"
            cmake_txt += "    if(\"${LIB}\" MATCHES \"^@APAKA_INSTALL_DIR@\")\n"
            cmake_txt += "        list(APPEND DEPS_SYSTEM_LINK_DIR ${LIB})\n"
            cmake_txt += "    else()\n"
            cmake_txt += "        link_directories(${LIB})\n"
            cmake_txt += "    endif()\n"
            cmake_txt += "endforeach()\n"
            cmake_txt += ""
            cmake_txt += "foreach(LIB ${DEPS_SYSTEM_LINK_DIR})\n"
            cmake_txt += "    link_directories(${LIB})\n"
            cmake_txt += "endforeach()\n"
            cmake_txt
        end

        def self.cmake_pkgconfig_link(context, target, depspec)
            depspec.inject([]) do |result, s|
                if s.in_context?(context, 'link')
                    result << "target_link_libraries(#{target} ${#{s.var_name}_LIBRARIES})"
                end
                result
            end.join("\n") + "\n"
        end

        def self.cmake_pkgconfig_link_corba(target, depspec)
            cmake_pkgconfig_link('corba', target, depspec)
        end
        def self.cmake_pkgconfig_link_noncorba(target, depspec)
            cmake_pkgconfig_link('core', target, depspec)
        end
        end
    end
end

