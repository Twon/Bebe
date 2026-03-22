import json
from pathlib import Path

from bebe.cli import get_image_tag, load_config, generate_dockerfile

def test_get_image_tag():
    # Correct base tag name extraction
    assert get_image_tag('configs/base.json') == 'bebe:base'
    # Correct prefixed registry output
    assert get_image_tag('configs/ubuntu.gcc14.json', registry='ghcr.io/twon') == 'ghcr.io/twon/bebe:ubuntu.gcc14'
    # Correct slash trimming/preservation
    assert get_image_tag('ubuntu.clang19.json', registry='xyz.com/') == 'xyz.com/bebe:ubuntu.clang19'

def test_load_config_and_inheritance(tmp_path):
    base_file = tmp_path / "base.json"
    child_file = tmp_path / "child.json"
    
    # Write a mock base configuraton
    base_file.write_text(json.dumps({
        "abstract": True,
        "os": "ubuntu:24.04",
        "versions": {"cmake": "4.3.0"}
    }))
    
    # Write a child configuration that claims inheritance
    child_file.write_text(json.dumps({
        "inherits": "base.json",
        "compiler": {"family": "gcc"}
    }))
    
    # Load child
    config = load_config(str(child_file))
    
    # Assert successful merging
    assert config["os"] == "ubuntu:24.04"
    assert config["versions"]["cmake"] == "4.3.0"
    assert config["compiler"]["family"] == "gcc"
    
    # The child is NOT abstract since it did not explicitly mark itself as such
    assert config["abstract"] is False

def test_generate_dockerfile():
    # We test on the real base config to ensure all Jinja2 macros and imports evaluate cleanly
    # without scoping or syntax exceptions on native rendering.
    config_path = Path('configs/base.json')
    if config_path.exists():
        content = generate_dockerfile(str(config_path))
        assert "FROM ubuntu:24.04" in content
        assert "ninja" in content
        assert "apt-get update" in content
