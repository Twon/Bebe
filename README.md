# BeBe: Bleeding Edge Build Environment

[![Build Environments](https://github.com/Twon/Bebe/actions/workflows/build_environments.yml/badge.svg)](https://github.com/Twon/Bebe/actions/workflows/build_environments.yml)
[![codecov](https://codecov.io/gh/Twon/Bebe/branch/main/graph/badge.svg)](https://codecov.io/gh/Twon/Bebe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)

BEBE is a flexible tool for generating and managing high-performance C++ build environments. It uses Jinja2 templates to dynamically generate Dockerfiles based on JSON configurations, allowing for easy management of different compiler versions and toolchains.

## Features

- **Dynamic Dockerfile Generation**: Uses Jinja2 templates to build tailored Docker images.
- **Multiprocess Builds**: Supports building Clang, GCC, and more from source.
- **Configuration Inheritance**: Share common settings across multiple environments using base configurations.
- **CI/CD Optimization**: Integrated with Docker Buildx and GitHub Actions (`gha`) caching for lightning-fast incremental builds.
- **CLI Tool**: A unified `bebe.py` script for all build and management tasks.

## Getting Started

### Prerequisites

- Python 3.12+
- Docker or Podman
- (Optional) Docker Buildx for advanced caching

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/twon/bebe.git
   cd bebe
   ```

2. Set up the virtual environment and install BeBe:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install .
   ```

## Configuration Inheritance

BEBE supports configuration inheritance to reduce duplication. You can define a base configuration (e.g., `configs/base.json`) with common settings and inherit from it in specific environment configs.

Example `configs/ubuntu.clang19.json`:
```json
{
    "inherits": "base.json",
    "compiler": {
        "family": "clang",
        "version": "release/19.x"
    }
}
```

Configurations marked as `"abstract": true` will be ignored by CI discovery but can be used as bases for other configs.

## Usage

The `bebe` command is the main entry point for all operations.

### Listing Configurations
Discover all buildable (non-abstract) configurations:
```bash
bebe list --directory configs
```

### Building an Image
```bash
bebe build --config configs/ubuntu.clang19.json
```

To enable advanced caching in CI:
```bash
bebe build --config configs/ubuntu.clang19.json \
  --cache-from type=gha \
  --cache-to type=gha,mode=max
```

### Interactive Shell
Launch a shell inside the built environment:
```bash
bebe shell --config configs/ubuntu.clang19.json
```

## How it Builds on CI

BEBE is designed to be CI-native. We use **Docker Buildx** with the **GitHub Actions Cache Backend** (`type=gha`).

In our [build workflow](.github/workflows/build_environments.yml), we use the following flags to ensure that expensive build steps (like compiling LLVM from source) are cached across different runs:

- `--cache-from type=gha`: Reuses build layers cached in previous GitHub Actions runs.
- `--cache-to type=gha,mode=max`: Exports all build layers back to the GitHub cache.

**Important CI Caching Detail:**
Because `bebe` invokes `docker buildx build` within a regular shell `run: ` step (rather than using the official `docker/build-push-action`), the GitHub Actions runner does not automatically expose the environment variables required by the `type=gha` cache backend out of the box. 

To fix this, our workflow uses the [`crazy-max/ghaction-github-runtime`](https://github.com/crazy-max/ghaction-github-runtime) action explicitly right before the build step. This seamlessly exposes the `ACTIONS_CACHE_URL` and `ACTIONS_RUNTIME_TOKEN` environment variables to the shell, ensuring the underlying `buildx` process can successfully communicate with the GitHub Cache API. This caching methodology ensures that only the parts of the environment that have changed are rebuilt, saving hours of CI time.

## Roadmap

We are actively working on expanding the BeBe ecosystem. Key upcoming features include:

- **Official GitHub Action**: A native `twon/bebe-action` to allow other repositories to easily build within a specific BeBe-generated environment.
- **VS Code / Dev Container Integration**: Seamless integration to allow developers to switch between toolsets while keeping their project source on the host, mapping it into the optimized build container for high-performance development.

---
© 2026 BeBe Contributors. Released under the MIT License.

