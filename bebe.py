# BeBe: Bleeding Edge Build Environment
# 
# Builds a containerised environment with the latest required build tools
import argparse
import docker
import jinja2
import json
import sys
from io import BytesIO
from pathlib import Path
from typing import BinaryIO

def buildImage(dockerile: BinaryIO):
    client = docker.from_env()
    client.images.build(fileobj=dockerile)
    pass

def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--config', help='Configuration file specifying tools to build into the final image')
    parser.add_argument('--vebose', help='Display verbose diagnostic information')
    args = parser.parse_args(args=None if sys.argv[1:] else ['--help'])


    #print(client.containers.list())

    loader = jinja2.FileSystemLoader(Path(__file__).parent / 'images')
    environment = jinja2.Environment(loader=loader)

    with open(args.config) as configFile:
        config = json.loads(configFile.read())
        template = environment.get_template(str(Path('./os') /'ubuntu'/'base.Dockerfile'))
        dockerfile = template.render(params=config)
        print(dockerfile)
        buildImage(BytesIO(bytes(dockerfile,encoding='utf-8')))

if __name__ == '__main__':
    main()

