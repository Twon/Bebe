{# CMake Build Template #}

{% macro build(version) %}
RUN wget https://github.com/Kitware/CMake/releases/download/v{{ version }}/cmake-{{ version }}.tar.gz && \
    tar -xzf cmake-{{ version }}.tar.gz && \
    cd cmake-{{ version }} && \
    ./bootstrap --prefix=/opt/cmake-{{ version }} --parallel=$(nproc) && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf cmake-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/cmake-{{ version }} /opt/cmake-{{ version }}
ENV PATH=/opt/cmake-{{ version }}/bin:$PATH
{% endmacro %}
