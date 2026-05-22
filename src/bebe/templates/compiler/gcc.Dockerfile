{# GCC Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
# Clone and build GCC from source
# The version config acts as the branch/tag to checkout
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/gcc-mirror/gcc.git /tmp/gcc
WORKDIR /tmp/gcc

# Dynamically extract the exact GCC version from the source BASE-VER file
RUN VERSION=$(tr -d '[:space:]' < gcc/BASE-VER) && \
    echo "Building GCC version: ${VERSION}" && \
    ./contrib/download_prerequisites && \
    mkdir build
WORKDIR /tmp/gcc/build
RUN VERSION=$(tr -d '[:space:]' < ../gcc/BASE-VER) && \
    ../configure --enable-languages=c,c++ --disable-multilib --prefix="/opt/compiler/gcc-${VERSION}" && \
    make -j"$(nproc)" && \
    make install-strip
WORKDIR /
RUN rm -rf /tmp/gcc
{% endmacro %}

{% macro copy(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('gcc-', '') %}
{% set major_version = base_version.split('.')[0] %}
# Copy the compiled GCC compiler from the build stage explicitly
COPY --from=compiler_stage /opt/compiler/ /opt/

# Dynamically locate the custom GCC directory under /opt, create symlinks, and configure environment
RUN COMPILER_DIR=$(find /opt -maxdepth 1 -type d -name "gcc-*" | head -n 1) && \
    ln -sf "$COMPILER_DIR/bin/gcc" /usr/bin/gcc-{{ major_version }} && \
    ln -sf "$COMPILER_DIR/bin/g++" /usr/bin/g++-{{ major_version }} && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-{{ major_version }} 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-{{ major_version }}

ENV CC=/usr/bin/gcc-{{ major_version }}
ENV CXX=/usr/bin/g++-{{ major_version }}
ENV PATH=/usr/bin:$PATH
{% endmacro %}
