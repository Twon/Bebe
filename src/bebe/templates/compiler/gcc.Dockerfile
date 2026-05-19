{# GCC Compiler Template — Jinja Macro Pattern #}
{# Import this file and call build() in the build stage, copy() in the runtime stage. #}

{% macro build(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('gcc-', '') %}
{% set major_version = base_version.split('.')[0] %}
# Clone and build GCC from source
# The version config acts as the branch/tag to checkout
RUN git clone --depth 1 --branch {{ params.compiler.version }} https://github.com/gcc-mirror/gcc.git /tmp/gcc
WORKDIR /tmp/gcc
RUN ./contrib/download_prerequisites && \
    mkdir build
WORKDIR /tmp/gcc/build
RUN ../configure --enable-languages=c,c++ --disable-multilib --prefix=/opt/gcc-{{ base_version }} && \
    make -j"$(nproc)" && \
    make install-strip
WORKDIR /
RUN rm -rf /tmp/gcc
{% endmacro %}

{% macro copy(params) %}
{% set base_version = params.compiler.version.split('/') | last | replace('gcc-', '') %}
{% set major_version = base_version.split('.')[0] %}
# Copy the compiled GCC compiler from the build stage explicitly
COPY --from=compiler_stage /opt/gcc-{{ base_version }} /opt/gcc-{{ base_version }}

ENV CC=/opt/gcc-{{ base_version }}/bin/gcc
ENV CXX=/opt/gcc-{{ base_version }}/bin/g++

RUN ln -sf /opt/gcc-{{ base_version }}/bin/gcc /usr/bin/gcc-{{ major_version }} && \
    ln -sf /opt/gcc-{{ base_version }}/bin/g++ /usr/bin/g++-{{ major_version }} && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-{{ major_version }} 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-{{ major_version }}

ENV PATH=/opt/gcc-{{ base_version }}/bin:$PATH
{% endmacro %}
