{% include 'tools/versions.Dockerfile' %}

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

# --- BUILD BASE STAGE ---
# This stage installs heavy dependencies and provides a foundation for all builds
FROM {{ params.os }} AS build_base

ENV DEBIAN_FRONTEND=noninteractive

# Install central build dependencies once
RUN apt-get update && apt-get install -y \
    wget curl git build-essential cmake ninja-build python3 python3-dev file flex bison lsb-release gnupg ca-certificates \
    libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev libreadline-dev texinfo libgmp-dev libzstd-dev \
    libexpat1-dev libmpfr-dev libmpc-dev libisl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*



# --- TOOLS BUILD STAGE ---
# This stage is now independent from compiler_stage to allow caching across all compiler images
FROM build_base AS build_stage

# Build other tools from source
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.build(tool_version) }}
{% endfor %}

# --- COMPILER BUILD STAGE ---
# Only builds the compiler from source. This is the heaviest and most cached layer.
FROM build_base AS compiler_stage
{% if params.compiler and compiler %}
{{ compiler.build(params) }}
{% endif %}

# --- RUNTIME BASE STAGE ---
# This stage is minimal and provides the runtime components
FROM {{ params.os }} AS runtime_base

ENV DEBIAN_FRONTEND=noninteractive

# Install only minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    wget curl git ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

# Initialize current_stage state for chained builds
{% set state = namespace(current_stage='runtime_base') %}

# --- FINAL GENERATED IMAGE ---
FROM {{ state.current_stage }} AS bebe_final

# Initialize LD_LIBRARY_PATH to avoid "UndefinedVar" warnings in tool macros
ENV LD_LIBRARY_PATH=

# In the final stage, we call the compiler's copy macro to install the binaries
{% if params.compiler and compiler %}
{{ compiler.copy(params) }}
{% endif %}

# Copy and configure other tools
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.copy(tool_version) }}
{% endfor %}
