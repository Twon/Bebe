{% macro build(version) %}
RUN wget --progress=dot:giga https://www.python.org/ftp/python/{{ version }}/Python-{{ version }}.tgz && \
    tar -xzf Python-{{ version }}.tgz
WORKDIR /Python-{{ version }}
RUN ./configure --prefix=/opt/python-{{ version }} --enable-optimizations && \
    make -j"$(nproc)" && \
    make install
WORKDIR /
RUN rm -rf /Python-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/python-{{ version }} /opt/python-{{ version }}
ENV PATH=/opt/python-{{ version }}/bin:$PATH
{% endmacro %}
