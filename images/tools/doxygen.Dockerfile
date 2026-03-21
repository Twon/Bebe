{# Doxygen Build Template #}

{% macro build(version) %}
RUN wget https://github.com/doxygen/doxygen/archive/refs/tags/Release_{{ version.replace('.', '_') }}.tar.gz && \
    tar -xzf Release_{{ version.replace('.', '_') }}.tar.gz && \
    cd doxygen-Release_{{ version.replace('.', '_') }} && \
    mkdir build && \
    cd build && \
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/opt/doxygen-{{ version }} .. && \
    ninja install && \
    cd ../.. && \
    rm -rf doxygen-Release_{{ version.replace('.', '_') }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/doxygen-{{ version }} /opt/doxygen-{{ version }}
ENV PATH=/opt/doxygen-{{ version }}/bin:$PATH
{% endmacro %}
