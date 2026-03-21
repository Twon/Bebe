{% macro apt_get(package) -%}
    apt-get install {{ package }} && apt-get clean
{%- endmacro %}

{% include 'tools/versions.Dockerfile' %}

# --- GLOBAL BUILD STAGE ---
# This stage installs heavy dependencies and provides a base for all builds
FROM {{ params.os }} AS build_stage

ENV DEBIAN_FRONTEND=noninteractive

# Install central build dependencies once
RUN apt-get update && apt-get install -y \
    wget curl git build-essential ninja-build python3 file flex bison lsb-release gnupg \
    && rm -rf /var/lib/apt/lists/*

# --- RUNTIME BASE STAGE ---
# This stage is minimal and provides the runtime components
FROM {{ params.os }} AS runtime_base

ENV DEBIAN_FRONTEND=noninteractive

# Install only minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    wget curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Initialize current_stage state for chained builds
{% set state = namespace(current_stage='runtime_base') %}

# --- COMPILE MODULES ---

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

# In the build_stage, we call the compiler's build macro if it exists
{% if compiler %}
{{ compiler.build(params) }}
{% endif %}

# --- FINAL GENERATED IMAGE ---
FROM {{ state.current_stage }} AS bebe_final

# In the final stage, we call the compiler's copy macro to install the binaries
{% if compiler %}
{{ compiler.copy(params) }}
{% endif %}
