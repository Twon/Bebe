{# Clang/LLVM Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
# Clone LLVM/Clang from source
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/llvm/llvm-project.git /tmp/llvm-project
WORKDIR /tmp/llvm-project

# Dynamically extract the exact LLVM version from the source CMakeLists.txt
RUN MAJOR=$(grep -E 'set\(LLVM_VERSION_MAJOR' llvm/CMakeLists.txt | tr -cd '0-9') && \
    MINOR=$(grep -E 'set\(LLVM_VERSION_MINOR' llvm/CMakeLists.txt | tr -cd '0-9') && \
    PATCH=$(grep -E 'set\(LLVM_VERSION_PATCH' llvm/CMakeLists.txt | tr -cd '0-9') && \
    VERSION="${MAJOR}.${MINOR}.${PATCH}" && \
    echo "Building LLVM version: ${VERSION}" && \
    mkdir build && \
    cd build && \
    cmake ../llvm \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
      -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DCMAKE_INSTALL_PREFIX="/opt/clang-${VERSION}" \
      -DCMAKE_INSTALL_RPATH="/opt/clang-${VERSION}/lib" \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
      -G "Ninja" && \
    cmake --build . --target install -j"$(nproc)" && \
    if [ -d "/opt/clang-${VERSION}/include/x86_64-unknown-linux-gnu/c++/v1" ]; then \
        cp -a "/opt/clang-${VERSION}/include/x86_64-unknown-linux-gnu/c++/v1/"* "/opt/clang-${VERSION}/include/c++/v1/" || true; \
    fi && \
    tar -cf /tmp/clang.tar -C /opt "clang-${VERSION}"
WORKDIR /
RUN rm -rf /tmp/llvm-project
{% endmacro %}

{% macro copy(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('llvmorg-', '') %}
{% set major_version = base_version.split('.')[0] %}
# Copy the compiled Clang compiler from the build stage
COPY --from=compiler_stage /tmp/clang.tar /tmp/clang.tar
RUN tar -xf /tmp/clang.tar -C /opt && rm /tmp/clang.tar

ENV CC=/usr/bin/clang-{{ major_version }}
ENV CXX=/usr/bin/clang++-{{ major_version }}

# Dynamically locate the custom Clang directory under /opt, create symlinks, and configure Clang cfg files locally
RUN COMPILER_DIR=$(find /opt -maxdepth 1 -name "clang-*" | head -n 1) && \
    ln -sf $COMPILER_DIR/bin/clang /usr/bin/clang-{{ major_version }} && \
    ln -sf $COMPILER_DIR/bin/clang++ /usr/bin/clang++-{{ major_version }} && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-{{ major_version }} 100 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-{{ major_version }} && \
    echo "-Wl,-rpath,$COMPILER_DIR/lib" > $COMPILER_DIR/bin/clang.cfg && \
    echo "-Wl,-rpath,$COMPILER_DIR/lib" > $COMPILER_DIR/bin/clang++.cfg

ENV PATH=/usr/bin:$PATH
{% endmacro %}
