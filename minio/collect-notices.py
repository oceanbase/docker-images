#!/usr/bin/env python3
"""Preserve upstream and vendored dependency notices in the image context."""
from pathlib import Path
import shutil
import sys

source, destination = map(Path, sys.argv[1:])
for project in ("minio", "mc"):
    root = source / project
    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        if path.name.upper().startswith(("LICENSE", "COPYING", "NOTICE", "COPYRIGHT", "CREDITS", "AUTHORS")):
            target = destination / project / path.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
