# Apps

Utilities for building and preparing Intune Win32 app packages.

## Build-IntuneWin.py

Builds a `.intunewin` package on Linux without Microsoft's Windows-only Win32 Content Prep Tool.

### Requirements

- Python 3.10+
- `cryptography`

Install the Python dependency in a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r Apps/requirements.txt
```

### Usage

```bash
python Apps/Build-IntuneWin.py \
  --content ./package-source \
  --setup install.ps1 \
  --output ./out
```

The setup file must exist directly inside the content directory. The generated package is written to the output directory and verified after creation.

> `.intunewin` files are generated artifacts and are intentionally ignored by Git.
