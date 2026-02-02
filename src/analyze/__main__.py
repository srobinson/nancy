#!/usr/bin/env python3
"""CLI entry point: python3 -m src.analyze <control_dir> <treatment_dir> [--json]"""

from .compare import main

if __name__ == "__main__":
    main()
