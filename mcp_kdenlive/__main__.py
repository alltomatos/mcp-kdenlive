"""Allow running as: python -m mcp_kdenlive.

Also usable directly via `.mcp.json` (command=python, args=["-m", "mcp_kdenlive"]),
which bypasses run.py's sys.path setup for the sibling kdenlive-api repo — so we
redo that insertion here too, making this entry point self-sufficient either way.
"""

import sys
from pathlib import Path

try:
    import kdenlive_api  # noqa: F401
except ImportError:
    workspace = Path(__file__).resolve().parent.parent.parent
    sys.path.insert(0, str(workspace / "kdenlive-api"))

from mcp_kdenlive.server import main

main()
