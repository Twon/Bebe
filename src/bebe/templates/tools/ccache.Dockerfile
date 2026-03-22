{% macro build(version) %}
RUN wget https://github.com/ccache/ccache/releases/download/v{{ version }}/ccache-{{ version }}.tar.gz && \
    tar -xzf ccache-{{ version }}.tar.gz && \
    cd ccache-{{ version }} && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/ccache-{{ version }} .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && \
    rm -rf ccache-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/ccache-{{ version }} /opt/ccache-{{ version }}
ENV PATH=/opt/ccache-{{ version }}/bin:$PATH
{% endmacro %}
