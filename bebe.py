#!/usr/bin/env python
#
# BeBe: Bleeding Edge Build Environment
# 
# Builds a containerised environment with the latest required build tools
import argparse
import json
import logging
import subprocess
import sys
from pathlib import Path

import jinja2

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def get_image_tag(config_path: str, registry: str = None) -> str:
    """Generate a tag for the image based on the config file name and optional registry."""
    config_name = Path(config_path).stem
    if registry:
        prefix = registry if registry.endswith('/') else f"{registry}/"
        tag = f"{prefix}bebe:{config_name}"
    else:
        tag = f"bebe:{config_name}"
    return tag.lower()

def generate_dockerfile(config_path: str) -> str:
    """Reads the JSON config and generates the Dockerfile content."""
    with open(config_path) as configFile:
        config = json.loads(configFile.read())
        
    loader = jinja2.FileSystemLoader(Path(__file__).parent / 'images')
    environment = jinja2.Environment(loader=loader)
    
    # We assume 'os' in config can be like 'ubuntu:24.04', so we extract 'ubuntu'
    os_name = config.get('os', 'ubuntu').split(':')[0]
    
    template_path = str(Path('os') / os_name / 'base.Dockerfile')
    template = environment.get_template(template_path.replace('\\', '/'))
    
    return template.render(params=config)

def run_build(args):
    """Generates the Dockerfile and executes the build using the chosen engine."""
    with open(args.config) as f:
        config = json.loads(f.read())
        
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    dockerfile_content = generate_dockerfile(args.config)
    
    if args.verbose:
        logging.info("Generated Dockerfile:\n" + dockerfile_content)
        
    logging.info(f"Building image '{tag}' using {args.engine}...")
    
    # Run the build, piping the dockerfile contents to stdin
    if args.engine == 'docker' and (args.cache_from or args.cache_to):
        # When using Buildx cache backends, we use 'buildx build'
        cmd = [args.engine, "buildx", "build", "--load", "-t", tag]
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
    """Launches an interactive shell inside the generated container."""
    with open(args.config) as f:
        config = json.loads(f.read())
        
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    
    # Add a BEBE motd/prompt modification when entering the shell
    bash_cmd = (
        "echo -e '\\n\\e[1;36mWelcome to the BEBE Terminal!\\e[0m\\n'; "
        "PS1='\\e[1;36m(bebe)\\e[0m \\w \\$ '; "
        "bash"
    )
    
    logging.info(f"Starting interactive shell in '{tag}' using {args.engine}...")
    cmd = [args.engine, "run", "-it", "--rm", tag, "bash", "-c", bash_cmd]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to launch shell: {e}")
        sys.exit(1)

def run_upload(args):
    """Pushes the image to a remote registry."""
    with open(args.config) as f:
        config = json.loads(f.read())
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    
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
    with open(args.config) as f:
        config = json.loads(f.read())
    tag = get_image_tag(args.config, getattr(args, 'registry', None))
    
    logging.info(f"Downloading '{tag}' using {args.engine}...")
    cmd = [args.engine, "pull", tag]
    try:
        subprocess.run(cmd, check=True)
        logging.info(f"Successfully downloaded {tag}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Download failed: {e}")
        sys.exit(1)

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
    parser_build.set_defaults(func=run_build)

    # Shell command
    parser_shell = subparsers.add_parser('shell', parents=[common], help='Launch an interactive shell in the image')
    parser_shell.add_argument('--config', required=True, help='Configuration JSON file')
    parser_shell.set_defaults(func=run_shell)

    # Upload command
    parser_upload = subparsers.add_parser('upload', parents=[common], help='Push the image to the registry')
    parser_upload.add_argument('--config', required=True, help='Configuration JSON file')
    parser_upload.set_defaults(func=run_upload)

    # Download command
    parser_download = subparsers.add_parser('download', parents=[common], help='Pull the image from the registry')
    parser_download.add_argument('--config', required=True, help='Configuration JSON file')
    parser_download.set_defaults(func=run_download)

    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        
    args.func(args)

if __name__ == '__main__':
    main()

