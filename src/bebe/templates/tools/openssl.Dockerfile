{# OpenSSL Build Template #}

{% macro build(version) %}
RUN wget https://www.openssl.org/source/openssl-{{ version }}.tar.gz && \
    tar -xzf openssl-{{ version }}.tar.gz
WORKDIR /openssl-{{ version }}
RUN ./config --prefix=/opt/openssl-{{ version }} --openssldir=/opt/openssl-{{ version }} && \
    make -j$(nproc) && \
    make install
WORKDIR /
RUN rm -rf /openssl-{{ version }}*
{% endmacro %}

{% macro copy(version) %}
COPY --from=build_stage /opt/openssl-{{ version }} /opt/openssl-{{ version }}
ENV PATH=/opt/openssl-{{ version }}/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/openssl-{{ version }}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
{% endmacro %}
