"""Load gitignored Config/local_devices.env for diagnostic scripts."""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / "Config" / "local_devices.env"

def load():
    if not ENV_PATH.is_file():
        raise SystemExit(
            f"Missing {ENV_PATH}. Copy Config/local_devices.env.example and fill local device IDs."
        )
    for line in ENV_PATH.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())

def require(*keys):
    load()
    missing = [k for k in keys if not os.environ.get(k)]
    if missing:
        raise SystemExit(f"Missing values in {ENV_PATH}: {', '.join(missing)}")
    return {k: os.environ[k] for k in keys}
