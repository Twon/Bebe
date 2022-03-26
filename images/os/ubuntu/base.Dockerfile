{% macro apt_get(package) -%}
    apt get install {{ package }} && apt get clean
{%- endmacro %}

{% include 'tools/versions.Dockerfile' %}

FROM ubuntu:22.04 AS ubuntu_base

{% include 'os/ubuntu/build_layer.Dockerfile' %}
