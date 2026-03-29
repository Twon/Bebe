{% macro build(version) %}
RUN wget --progress=dot:giga https://github.com/ninja-build/ninja/archive/refs/tags/v{{ version }}.tar.gz -O ninja-{{ version }}.tar.gz && \
    tar -xzf ninja-{{ version }}.tar.gz
WORKDIR /ninja-{{ version }}
RUN python3 configure.py --bootstrap && \
    mkdir -p /opt/ninja-{{ version }}/bin && \
    cp ninja /opt/ninja-{{ version }}/bin/
WORKDIR /
RUN rm -rf /ninja-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/ninja-{{ version }} /opt/ninja-{{ version }}
ENV PATH=/opt/ninja-{{ version }}/bin:$PATH
{% endmacro %}
