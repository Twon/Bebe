{# Clang/LLVM Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('llvmorg-', '') %}
{% set major_version = base_version.split('.')[0] %}
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
      -DCMAKE_INSTALL_PREFIX=/opt/clang-{{ base_version }} \
      -DCMAKE_INSTALL_RPATH="/opt/clang-{{ base_version }}/lib" \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
      -G "Ninja" && \
    cmake --build . --target install -j"$(nproc)" && \
    if [ -d /opt/clang-{{ base_version }}/include/x86_64-unknown-linux-gnu/c++/v1 ]; then \
        cp -a /opt/clang-{{ base_version }}/include/x86_64-unknown-linux-gnu/c++/v1/* /opt/clang-{{ base_version }}/include/c++/v1/ || true; \
    fi
WORKDIR /
RUN rm -rf /tmp/llvm-project
{% endmacro %}

{% macro copy(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('llvmorg-', '') %}
{% set major_version = base_version.split('.')[0] %}
# Copy the compiled Clang compiler from the build stage
COPY --from=compiler_stage /opt/clang-{{ base_version }} /opt/clang-{{ base_version }}

ENV CC=/opt/clang-{{ base_version }}/bin/clang
ENV CXX=/opt/clang-{{ base_version }}/bin/clang++

RUN ln -sf /opt/clang-{{ base_version }}/bin/clang /usr/bin/clang-{{ major_version }} && \
    ln -sf /opt/clang-{{ base_version }}/bin/clang++ /usr/bin/clang++-{{ major_version }} && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-{{ major_version }} 100 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-{{ major_version }}

# Create default configuration files for Clang to automatically inject the runtime library search path (rpath)
RUN echo "-Wl,-rpath,/opt/clang-{{ base_version }}/lib" > /opt/clang-{{ base_version }}/bin/clang.cfg && \
    echo "-Wl,-rpath,/opt/clang-{{ base_version }}/lib" > /opt/clang-{{ base_version }}/bin/clang++.cfg

ENV PATH=/opt/clang-{{ base_version }}/bin:$PATH
{% endmacro %}
