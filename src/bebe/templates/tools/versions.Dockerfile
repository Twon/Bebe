# This file contains the macro for installing tools
{% macro apt_get(package) -%}
    apt-get install -y {{ package }} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
{%- endmacro %}
