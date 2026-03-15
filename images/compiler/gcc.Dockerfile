# --- GCC BUILD STAGE ---
FROM build_stage AS gcc_build

# Clone and build GCC from source
# The version config acts as the branch/tag to checkout
RUN git clone --depth 1 --branch {{ params.compiler.version }} git://gcc.gnu.org/git/gcc.git /tmp/gcc && \
    cd /tmp/gcc && \
    ./contrib/download_prerequisites && \
    mkdir build && \
    cd build && \
    ../configure --enable-languages=c,c++ --disable-multilib --prefix=/opt/gcc-{{ params.compiler.version }} && \
    make -j$(nproc) && \
    make install-strip && \
    cd /tmp && \
    rm -rf gcc

# --- GCC RUNTIME STAGE ---
FROM {{ state.current_stage }} AS gcc_runtime

# Copy the compiled GCC compiler from its specific build stage
COPY --from=gcc_build /opt/gcc-{{ params.compiler.version }} /opt/gcc-{{ params.compiler.version }}

ENV CC=/opt/gcc-{{ params.compiler.version }}/bin/gcc
ENV CXX=/opt/gcc-{{ params.compiler.version }}/bin/g++

# Configure dynamic linker for sanitized builds and libstdc++
RUN echo "/opt/gcc-{{ params.compiler.version }}/lib64" > /etc/ld.so.conf.d/gcc-{{ params.compiler.version }}.conf && \
    ldconfig

ENV PATH=/opt/gcc-{{ params.compiler.version }}/bin:$PATH

{# Update the pipeline state to point to this new stage #}
{% set state.current_stage = 'gcc_runtime' %}
