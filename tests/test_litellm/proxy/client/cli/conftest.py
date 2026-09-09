import pytest

from litellm.proxy.client.cli.commands import claude_settings


@pytest.fixture(autouse=True)
def _statusline_script_under_tmp(monkeypatch, tmp_path):
    """Every Claude Code wiring installs the status line script; keep it out of the real ~/.litellm."""
    monkeypatch.setattr(claude_settings, "STATUSLINE_SCRIPT_PATH", tmp_path / "litellm-home" / "statusline.py")
