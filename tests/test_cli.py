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
    # We test on a real compiler config to ensure the multi-stage logic (compiler_stage, tools_stage)
    # is correctly rendered in the final output.
    config_path = Path('configs/ubuntu.gcc14.json')
    if config_path.exists():
        content = generate_dockerfile(str(config_path))
        assert "FROM ubuntu:24.04 AS build_base" in content
        assert "AS compiler_stage" in content
        assert "AS build_stage" in content
        assert "COPY --from=compiler_stage /opt /opt" in content
        assert "COPY --from=build_stage" in content
        assert "gcc" in content
        assert "ninja" in content

def test_run_list(tmp_path, capsys):
    # Setup mock configs
    (tmp_path / "base.json").write_text(json.dumps({"abstract": True}))
    (tmp_path / "child.json").write_text(json.dumps({"inherits": "base.json", "os": "ubuntu"}))
    (tmp_path / "invalid.json").write_text("not json")
    
    from bebe.cli import run_list
    class Args:
        directory = str(tmp_path)
    
    run_list(Args())
    
    captured = capsys.readouterr()
    results = json.loads(captured.out)
    
    # Should only contain buildable (non-abstract) configs
    assert any("child.json" in r for r in results)
    assert not any("base.json" in r for r in results)
    assert not any("invalid.json" in r for r in results)

def test_main_help(capsys):
    from bebe.cli import main
    import sys
    from unittest.mock import patch
    
    with patch.object(sys, 'argv', ['bebe']):
        try:
            main()
        except SystemExit:
            pass
    
    captured = capsys.readouterr()
    assert "usage:" in captured.err
    assert "build" in captured.err
    assert "list" in captured.err

def test_run_build_dry_run(tmp_path, monkeypatch):
    # Test that run_build constructs the correct subprocess call
    config_file = tmp_path / "test.json"
    config_file.write_text(json.dumps({"os": "ubuntu", "versions": {}}))
    
    from bebe.cli import run_build
    class Args:
        config = str(config_file)
        engine = "docker"
        verbose = False
        cache_from = "type=gha"
        cache_to = "type=gha,mode=max"
        push = False
        registry = "ghcr.io/test"

    import subprocess
    captured_cmds = []
    
    def mock_run(cmd, **kwargs):
        captured_cmds.append(cmd)
        class MockResult:
            returncode = 0
        return MockResult()
        
    monkeypatch.setattr(subprocess, "run", mock_run)
    
    run_build(Args())
    
    assert len(captured_cmds) == 1
    assert "buildx" in captured_cmds[0]
    assert "--cache-from" in captured_cmds[0]
    assert "ghcr.io/test/bebe:test" in captured_cmds[0]

def test_subcommands_dispatch(monkeypatch):
    from bebe.cli import run_shell, run_upload, run_download
    import subprocess
    
    def mock_run(cmd, **kwargs):
        return type('obj', (object,), {'returncode': 0})
    
    monkeypatch.setattr(subprocess, "run", mock_run)
    
    class Args:
        config = "configs/base.json"
        engine = "docker"
        registry = None
    
    # Just verify they run without crashing (logic is shared with build)
    run_shell(Args())
    run_upload(Args())
    run_download(Args())
