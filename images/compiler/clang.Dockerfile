# --- CLANG BUILD STAGE ---
FROM build_stage AS clang_build

# Clone and build LLVM from source
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/llvm/llvm-project.git /tmp/llvm-project && \
    mkdir -p /tmp/llvm-project/build && \
    cd /tmp/llvm-project/build && \
    cmake ../llvm \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS="clang;lld" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DCMAKE_INSTALL_PREFIX=/opt/clang-{{ params.compiler.version }} \
      -G "Ninja" && \
    cmake --build . --target install -j$(nproc) && \
    rm -rf /tmp/llvm-project

# --- CLANG RUNTIME STAGE ---
FROM {{ state.current_stage }} AS clang_runtime

# Copy the compiled Clang compiler from its specific build stage
COPY --from=clang_build /opt/clang-{{ params.compiler.version }} /opt/clang-{{ params.compiler.version }}

ENV CC=/opt/clang-{{ params.compiler.version }}/bin/clang
ENV CXX=/opt/clang-{{ params.compiler.version }}/bin/clang++

RUN echo "/opt/clang-{{ params.compiler.version }}/lib" > /etc/ld.so.conf.d/clang-{{ params.compiler.version }}.conf && \
    ldconfig

ENV PATH=/opt/clang-{{ params.compiler.version }}/bin:$PATH

{# Update the pipeline state to point to this new stage #}
{% set state.current_stage = 'clang_runtime' %}
