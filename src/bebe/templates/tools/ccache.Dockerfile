{% macro build(version) %}
RUN wget --progress=dot:giga https://github.com/ccache/ccache/releases/download/v{{ version }}/ccache-{{ version }}.tar.gz && \
    tar -xzf ccache-{{ version }}.tar.gz
WORKDIR /ccache-{{ version }}/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/ccache-{{ version }} .. && \
    make -j"$(nproc)" && \
    make install
WORKDIR /
RUN rm -rf /ccache-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/ccache-{{ version }} /opt/ccache-{{ version }}
ENV PATH=/opt/ccache-{{ version }}/bin:$PATH
{% endmacro %}
