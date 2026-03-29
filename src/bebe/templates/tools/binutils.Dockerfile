{% macro build(version) %}
{% if not 'windows' in params.os.lower() %}
RUN wget --progress=dot:giga https://ftp.gnu.org/gnu/binutils/binutils-{{ version }}.tar.gz && \
    tar -xzf binutils-{{ version }}.tar.gz
WORKDIR /binutils-{{ version }}
RUN ./configure --prefix=/opt/binutils-{{ version }} --enable-gold --enable-ld=default --enable-plugins --disable-werror && \
    make -j"$(nproc)" && \
    make install
WORKDIR /
RUN rm -rf /binutils-{{ version }}*
{% endif %}
{% endmacro %}

{% macro copy(version) %}
{% if not 'windows' in params.os.lower() %}
COPY --from=build_stage /opt/binutils-{{ version }} /opt/binutils-{{ version }}
ENV PATH=/opt/binutils-{{ version }}/bin:$PATH
{% endif %}
{% endmacro %}
