{# MSVC Compiler Template — Jinja Macro Pattern (Placeholder) #}
{# MSVC support generally requires Windows containers or specialised Wine setups. #}

{% macro build(params) %}
# MSVC: no Linux source build available
{% endmacro %}

{% macro copy(params) %}
RUN echo "MSVC configuration not yet fully implemented for Linux containers" && exit 1
{% endmacro %}
