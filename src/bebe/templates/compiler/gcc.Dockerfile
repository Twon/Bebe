{# GCC Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
# Clone and build GCC from source
# The version config acts as the branch/tag to checkout
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/gcc-mirror/gcc.git /tmp/gcc
WORKDIR /tmp/gcc
RUN ./contrib/download_prerequisites && \
    mkdir build
WORKDIR /tmp/gcc/build
RUN ../configure --enable-languages=c,c++ --disable-multilib --prefix=/opt/gcc-{{ params.compiler.version }} && \
    make -j"$(nproc)" && \
    make install-strip
WORKDIR /
RUN rm -rf /tmp/gcc
{% endmacro %}

{% macro copy(params) %}
# Copy the compiled GCC compiler from the build stage
COPY --from=compiler_stage /opt/gcc-{{ params.compiler.version }} /opt/gcc-{{ params.compiler.version }}

ENV CC=/opt/gcc-{{ params.compiler.version }}/bin/gcc
ENV CXX=/opt/gcc-{{ params.compiler.version }}/bin/g++

{% set version_parts = params.compiler.version.split('-') %}
{% if version_parts|length > 1 %}
{% set major_version = version_parts[1].split('.')[0] %}
RUN ln -sf /opt/gcc-{{ params.compiler.version }}/bin/gcc /usr/bin/gcc-{{ major_version }} && \
    ln -sf /opt/gcc-{{ params.compiler.version }}/bin/g++ /usr/bin/g++-{{ major_version }} && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-{{ major_version }} 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-{{ major_version }}
{% endif %}

ENV PATH=/opt/gcc-{{ params.compiler.version }}/bin:$PATH
{% endmacro %}
