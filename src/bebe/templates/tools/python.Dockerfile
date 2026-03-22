{% macro build(version) %}
RUN wget https://www.python.org/ftp/python/{{ version }}/Python-{{ version }}.tgz && \
    tar -xzf Python-{{ version }}.tgz && \
    cd Python-{{ version }} && \
    ./configure --prefix=/opt/python-{{ version }} --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/python-{{ version }} /opt/python-{{ version }}
ENV PATH=/opt/python-{{ version }}/bin:$PATH
{% endmacro %}
