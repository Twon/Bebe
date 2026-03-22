{% macro build(version) %}
{% if not 'windows' in params.os.lower() %}
RUN wget https://ftp.gnu.org/gnu/gdb/gdb-{{ version }}.tar.gz && \
    tar -xzf gdb-{{ version }}.tar.gz && \
    cd gdb-{{ version }} && \
    ./configure --prefix=/opt/gdb-{{ version }} && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf gdb-{{ version }}*
{% endif %}
{% endmacro %}

{% macro copy(version) %}
{% if not 'windows' in params.os.lower() %}
COPY --from=build_stage /opt/gdb-{{ version }} /opt/gdb-{{ version }}
ENV PATH=/opt/gdb-{{ version }}/bin:$PATH
{% endif %}
{% endmacro %}
