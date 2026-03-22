{# LCOV Build Template #}

{% macro build(version) %}
RUN wget https://github.com/linux-test-project/lcov/releases/download/v{{ version }}/lcov-{{ version }}.tar.gz && \
    tar -xzf lcov-{{ version }}.tar.gz && \
    cd lcov-{{ version }} && \
    make install PREFIX=/opt/lcov-{{ version }} && \
    cd .. && \
    rm -rf lcov-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/lcov-{{ version }} /opt/lcov-{{ version }}
ENV PATH=/opt/lcov-{{ version }}/usr/bin:$PATH
{% endmacro %}
