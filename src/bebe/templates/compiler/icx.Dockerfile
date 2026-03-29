{# ICC (Intel C++ Compiler) Template — Jinja Macro Pattern #}
{# Installs via the oneAPI toolkit repositories (no source build needed). #}

{% macro build(params) %}
# ICC is installed from Intel repos, no source compilation needed in the build stage
{% endmacro %}

{% macro copy(params) %}
# Install Intel oneAPI compiler from official repositories
RUN wget --progress=dot:giga -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic

ENV CC=icx
ENV CXX=icpx
{% endmacro %}
