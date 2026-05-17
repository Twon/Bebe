{# Clang/LLVM Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
# Clone and build LLVM/Clang from source
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/llvm/llvm-project.git /tmp/llvm-project
WORKDIR /tmp/llvm-project/build
RUN cmake ../llvm \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
      -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DCMAKE_INSTALL_PREFIX=/opt/clang-{{ params.compiler.version }} \
      -DCMAKE_INSTALL_RPATH="/opt/clang-{{ params.compiler.version }}/lib" \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
      -G "Ninja" && \
    cmake --build . --target install -j"$(nproc)"
WORKDIR /
RUN rm -rf /tmp/llvm-project
{% endmacro %}

{% macro copy(params) %}
# Copy the compiled Clang compiler from the build stage
COPY --from=compiler_stage /opt/clang-{{ params.compiler.version }} /opt/clang-{{ params.compiler.version }}

ENV CC=/opt/clang-{{ params.compiler.version }}/bin/clang
ENV CXX=/opt/clang-{{ params.compiler.version }}/bin/clang++

{% set version_parts = params.compiler.version.split('-') %}
{% if version_parts|length > 1 %}
{% set major_version = version_parts[1].split('.')[0] %}
RUN ln -s /opt/clang-{{ params.compiler.version }}/bin/clang /usr/bin/clang-{{ major_version }} && \
    ln -s /opt/clang-{{ params.compiler.version }}/bin/clang++ /usr/bin/clang++-{{ major_version }} && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-{{ major_version }} 100 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-{{ major_version }}
{% endif %}

ENV PATH=/opt/clang-{{ params.compiler.version }}/bin:$PATH
{% endmacro %}
