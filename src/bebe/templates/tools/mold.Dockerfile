{% macro build(version) %}
RUN wget --progress=dot:giga https://github.com/rui314/mold/archive/refs/tags/v{{ version }}.tar.gz -O mold-{{ version }}.tar.gz && \
    tar -xzf mold-{{ version }}.tar.gz
WORKDIR /mold-{{ version }}/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/mold-{{ version }} -DMOLD_USE_SYSTEM_TBB=OFF .. && \
    cmake --build . --parallel "$(nproc)" && \
    cmake --install .
WORKDIR /
RUN rm -rf /mold-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/mold-{{ version }} /opt/mold-{{ version }}
ENV PATH=/opt/mold-{{ version }}/bin:$PATH
{% endmacro %}
