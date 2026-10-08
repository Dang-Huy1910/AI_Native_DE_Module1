from dataclasses import dataclass
from pathlib import Path
import os
from dotenv import load_dotenv

load_dotenv()

ROOT = Path(__file__).resolve().parents[1]
INPUT_DIR = ROOT / "data" / "incremental" / "day_2026-07-01"
STAGING_DIR = ROOT / "data" / "staging"
LOG_DIR = ROOT / "logs"

STAGING_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)


@dataclass(frozen=True)
class Settings:
    root: Path = ROOT
    database_url: str = os.getenv('DATABASE_URL', 'postgresql+psycopg://de_user:de_password@localhost:5432/ecommerce')
    api_url: str = os.getenv('MOCK_API_URL', 'http://localhost:8000')
    api_key: str = os.getenv('MOCK_API_KEY', 'training-key')
    input_dir: Path = INPUT_DIR
    staging_dir: Path = STAGING_DIR
    log_dir: Path = LOG_DIR
    raw_dir: Path = ROOT / 'data' / 'raw'
    reject_dir: Path = ROOT / 'data' / 'reject'
    metadata_dir: Path = ROOT / 'metadata'
    report_dir: Path = ROOT / 'reports'


SETTINGS = Settings()
