{% include 'tools/versions.Dockerfile' %}

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

# --- GLOBAL BUILD STAGE ---
# This stage installs heavy dependencies and provides a base for all builds
FROM {{ params.os }} AS build_stage

ENV DEBIAN_FRONTEND=noninteractive

# Install central build dependencies once
RUN apt-get update && apt-get install -y \
    wget curl git build-essential cmake ninja-build python3 file flex bison lsb-release gnupg \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Import compiler macros and run build if required
{% if compiler %}
{{ compiler.build(params) }}
{% endif %}

# Import and build other tools from source
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module %}
{{ tool_module.build(tool_version) }}
{% endfor %}

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

# --- FINAL GENERATED IMAGE ---
FROM {{ state.current_stage }} AS bebe_final

# In the final stage, we call the compiler's copy macro to install the binaries
{% if params.compiler and compiler %}
{{ compiler.copy(params) }}
{% endif %}

# Copy and configure other tools
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module %}
{{ tool_module.copy(tool_version) }}
{% endfor %}
