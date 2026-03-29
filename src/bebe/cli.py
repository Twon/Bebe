#!/usr/bin/env python
#
# BeBe: Bleeding Edge Build Environment
# 
# Builds a containerised environment with the latest required build tools
import argparse
import json
import logging
import subprocess
import importlib.resources as pkg_resources
import sys
from pathlib import Path

import jinja2

import os
import jinja2

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def load_user_config() -> dict:
    """Loads the user's global configuration from ~/.bebe/config.json if it exists."""
    user_config_path = Path.home() / '.bebe' / 'config.json'
    if user_config_path.exists():
        try:
            with open(user_config_path) as f:
                return json.load(f)
        except Exception as e:
            logging.warning(f"Failed to load user config at {user_config_path}: {e}")
    return {}

def resolve_registry(args, config: dict) -> str:
    """ Resolves the container registry to use based on a hierarchical priority:
        1. CLI flag (--registry)
        2. Environment variable (BEBE_REGISTRY)
        3. User global config (~/.bebe/config.json)
        4. Project configuration (registry key in JSON)
    """
    # 1. CLI flag
    registry = getattr(args, 'registry', None)
    if registry:
        return registry

    # 2. Environment variable
    registry = os.environ.get('BEBE_REGISTRY')
    if registry:
        return registry

    # 3. User global config
    user_config = load_user_config()
    registry = user_config.get('registry')
    if registry:
        return registry

    # 4. Project configuration
    return config.get('registry')

def get_image_tag(config_path: str, registry: str = None) -> str:
    """Generates the formatted image tag with an optional registry prefix."""
    config_name = Path(config_path).stem
    if registry:
        prefix = registry if registry.endswith('/') else f"{registry}/"
        tag = f"{prefix}bebe:{config_name}"
    else:
        tag = f"bebe:{config_name}"
    return tag.lower()

def resolve_config_path(config_path: str) -> Path:
    """Resolves a config file path, searching the 'configs/' directory as a fallback."""
    path = Path(config_path)
    if path.exists():
        return path
    # Try searching in a 'configs/' subdirectory (useful when only the filename is given)
    fallback = Path('configs') / path.name
    if fallback.exists():
        return fallback
    # Return original path so error messages are informative
    return path

def load_config(config_path: str) -> dict:
    """Recursively loads configurations based on the 'inherits' key and performs a deep merge."""
    path = resolve_config_path(config_path)
    with open(path) as f:
        file_config = json.loads(f.read())

    if 'inherits' in file_config:
        base_path = path.parent / file_config['inherits']
        config = load_config(str(base_path))
        
        # Deep merge: config (base) is updated with file_config (current)
        def deep_merge(base, update):
            for key, value in update.items():
                if key in ['inherits', 'abstract']:
                    continue
                if isinstance(value, dict) and key in base and isinstance(base[key], dict):
                    deep_merge(base[key], value)
                else:
                    base[key] = value
            return base
        
        config = deep_merge(config, file_config)
    else:
        config = file_config
    
    # The 'abstract' property should only apply to the file that defines it
    config['abstract'] = file_config.get('abstract', False)
    
    return config

def generate_dockerfile(config_path: str) -> str:
    """Reads the JSON config and generates the Dockerfile content."""
    config = load_config(config_path)
        
    templates_dir = pkg_resources.files('bebe').joinpath('templates')
    loader = jinja2.FileSystemLoader(str(templates_dir))
    environment = jinja2.Environment(loader=loader)
    
    # We assume 'os' in config can be like 'ubuntu:24.04', so we extract 'ubuntu'
    os_name = config.get('os', 'ubuntu').split(':')[0]
    
    template_path = str(Path('os') / os_name / 'base.Dockerfile')
    template = environment.get_template(template_path.replace('\\', '/'))
    
    return template.render(params=config)

def run_build(args):
    """Generates the Dockerfile and executes the build using the chosen engine."""
    config = load_config(args.config)
        
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    dockerfile_content = generate_dockerfile(args.config)
    
    if args.verbose:
        logging.info("Generated Dockerfile:\n" + dockerfile_content)
        
    logging.info(f"Building image '{tag}' using {args.engine}...")
    
    # Run the build, piping the dockerfile contents to stdin
    if args.engine == 'docker' and (args.cache_from or args.cache_to or args.push):
        # When using Buildx cache backends, we use 'buildx build'
        build_type = "--push" if args.push else "--load"
        cmd = [args.engine, "buildx", "build", build_type, "-t", tag]
        if args.cache_from:
            cmd.extend(["--cache-from", args.cache_from])
        if args.cache_to:
            cmd.extend(["--cache-to", args.cache_to])
        cmd.append("-")
    else:
        cmd = [args.engine, "build", "-t", tag, "-"]
        
    try:
        subprocess.run(cmd, input=dockerfile_content.encode('utf-8'), check=True)
        logging.info(f"Successfully built {tag}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Build failed: {e}")
        sys.exit(1)

def run_shell(args):
    """Launches an interactive shell or runs a command inside the container."""
    config = load_config(args.config)
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    
    cmd = [args.engine, "run", "--rm"]
    
    # Mount current directory to /src if requested
    if args.mount:
        cwd = Path.cwd().absolute()
        # Ensure path uses forward slashes for cross-platform docker compatibility
        mount_path = str(cwd).replace('\\', '/')
        cmd.extend(["-v", f"{Path.cwd()}:/src", "-w", "/src"])
    
    if args.command:
        cmd.extend([tag, "bash", "-c", args.command])
    else:
        cmd.extend(["-it", tag, "bash", "-c", (
            "echo -e '\\n\\e[1;36mWelcome to the BEBE Terminal!\\e[0m\\n'; "
            "PS1='\\e[1;36m(bebe)\\e[0m \\w \\$ '; "
            "bash"
        )])
        
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        if args.command:
            logging.error(f"Command execution failed: {e}")
        else:
            logging.error(f"Failed to launch shell: {e}")
        sys.exit(1)

def run_tag(args):
    """Resolves and prints the full image tag for a configuration."""
    config = load_config(args.config)
    registry = resolve_registry(args, config)
    tag = get_image_tag(args.config, registry)
    print(tag)

def run_upload(args):
    """Pushes the image to a remote registry."""
    config = load_config(args.config)
    registry = resolve_registry(args, config)
    tag = get_image_tag(args.config, registry)
    
    logging.info(f"Uploading '{tag}' using {args.engine}...")
    cmd = [args.engine, "push", tag]
    try:
        subprocess.run(cmd, check=True)
        logging.info(f"Successfully uploaded {tag}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Upload failed: {e}")
        sys.exit(1)

def run_download(args):
    """Pulls the image from a remote registry."""
    config = load_config(args.config)
    registry = resolve_registry(args, config)
    tag = get_image_tag(args.config, registry)
    
    logging.info(f"Downloading '{tag}' using {args.engine}...")
    cmd = [args.engine, "pull", tag]
    try:
        subprocess.run(cmd, check=True)
        logging.info(f"Successfully downloaded {tag}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Download failed: {e}")
        sys.exit(1)

def run_generate(args):
    """Renders and prints the Dockerfile content for a configuration."""
    dockerfile_content = generate_dockerfile(args.config)
    print(dockerfile_content)

def run_list(args):
    """Lists all buildable (non-abstract) configurations in a directory."""
    directory = Path(args.directory)
    buildable = []
    for p in directory.glob('*.json'):
        try:
            config = load_config(str(p))
            if not config.get('abstract', False):
                # Use forward slashes for cross-platform CI compatibility
                buildable.append(str(p).replace('\\', '/'))
        except Exception:
            # Skip invalid configs
            continue
    # Print the JSON array to stdout for CI consumption
    print(json.dumps(buildable))


def main():
    # Shared parent parser so flags work before OR after the subcommand
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('-e', '--engine', default='docker', choices=['docker', 'podman'], 
                        help='Container engine to use (default: docker)')
    common.add_argument('-v', '--verbose', action='store_true', help='Display verbose diagnostic information')
    common.add_argument('--registry', help='Container registry prefix (e.g. ghcr.io/twon/)')

    parser = argparse.ArgumentParser(description='BEBE: Bleeding Edge Build Environment Generator',
                                     parents=[common])
    
    subparsers = parser.add_subparsers(dest='command', required=True, help='Commands')

    # Build command
    parser_build = subparsers.add_parser('build', parents=[common], help='Build the container image')
    parser_build.add_argument('--config', required=True, help='Configuration JSON file')
    parser_build.add_argument('--cache-from', help='Build cache source (e.g. type=gha)')
    parser_build.add_argument('--cache-to', help='Build cache destination (e.g. type=gha,mode=max)')
    parser_build.add_argument('--push', action='store_true', help='Push the image directly after building (requires buildx)')
    parser_build.set_defaults(func=run_build)

    # Shell command
    parser_shell = subparsers.add_parser('shell', parents=[common], help='Launch interactive shell or run command in image')
    parser_shell.add_argument('--config', required=True, help='Configuration JSON file')
    parser_shell.add_argument('--command', help='Specific command to run non-interactively')
    parser_shell.add_argument('--mount', action='store_true', help='Mount current directory to /src')
    parser_shell.set_defaults(func=run_shell)

    # Upload command
    parser_upload = subparsers.add_parser('upload', parents=[common], help='Push the image to the registry')
    parser_upload.add_argument('--config', required=True, help='Configuration JSON file')
    parser_upload.set_defaults(func=run_upload)

    # Download command
    parser_download = subparsers.add_parser('download', parents=[common], help='Pull the image from the registry')
    parser_download.add_argument('--config', required=True, help='Configuration JSON file')
    parser_download.set_defaults(func=run_download)

    # Tag command (for resolving image names)
    parser_tag = subparsers.add_parser('tag', parents=[common], help='Resolve and print the image tag')
    parser_tag.add_argument('--config', required=True, help='Configuration JSON file')
    parser_tag.set_defaults(func=run_tag)

    # List command (for CI discovery)
    parser_list = subparsers.add_parser('list', parents=[common], help='List buildable configurations')
    parser_list.add_argument('--directory', default='configs', help='Directory to scan for configs')
    parser_list.set_defaults(func=run_list)

    # Generate command (for CI linting/discovery)
    parser_generate = subparsers.add_parser('generate', parents=[common], help='Output rendered Dockerfile to stdout')
    parser_generate.add_argument('--config', required=True, help='Configuration JSON file')
    parser_generate.set_defaults(func=run_generate)


    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        
    args.func(args)

if __name__ == '__main__':
    main()

