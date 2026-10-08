#!/usr/bin/env python3
"""Lab 5: File Ingestion Batch Runner (RAW -> STAGING Pipeline)."""
import argparse
import sys
from pathlib import Path

# Đảm bảo package 'src' được tìm thấy dù script chạy từ bất kỳ thư mục nào
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.config import SETTINGS
from src.extract_files import read_dataset, profile
from src.transform import normalize
from src.logger import get_logger

logger = get_logger("file_pipeline")

DATASETS = [
    "customers",
    "products",
    "orders",
    "order_items",
    "payments",
]


def resolve_file(input_dir: Path, dataset_name: str) -> Path:
    """Tự động tìm file trong input_dir (hỗ trợ cả hậu tố _daily lẫn tên thường)."""
    candidates = [
        input_dir / f"{dataset_name}_daily.csv",
        input_dir / f"{dataset_name}.csv",
        input_dir / f"{dataset_name}_daily.json",
        input_dir / f"{dataset_name}.json",
    ]
    for p in candidates:
        if p.exists():
            return p
    return input_dir / f"{dataset_name}.csv"


def process_dataset(path: Path, staging_dir: Path):
    """Quy trình ETL cho một dataset: Extract -> Profile -> Normalize -> Load to Staging."""
    logger.info("start dataset=%s file=%s", path.stem, path.name)

    # 1. Extract
    raw_df = read_dataset(path)

    # 2. Profile
    before = profile(raw_df)
    logger.info(
        "profile dataset=%s rows=%d missing=%d duplicates=%d",
        path.name,
        before["rows"],
        sum(before["missing"].values()),
        before["duplicates"],
    )

    # 3. Transform / Normalize
    clean_df = normalize(raw_df)

    # 4. Load to Staging (<dataset>_clean.csv)
    dataset_name = path.stem.replace("_daily", "")
    output_path = staging_dir / f"{dataset_name}_clean.csv"
    clean_df.to_csv(output_path, index=False)

    logger.info(
        "success dataset=%s rows_in=%d rows_out=%d output=%s",
        path.name,
        len(raw_df),
        len(clean_df),
        output_path,
    )


def run_pipeline(input_dir: Path, staging_dir: Path):
    """Thực thi pipeline theo lô trên toàn bộ 5 dataset."""
    logger.info("=== START FILE PIPELINE ===")
    logger.info("Input dir: %s", input_dir)
    logger.info("Staging dir: %s", staging_dir)

    staging_dir.mkdir(parents=True, exist_ok=True)

    for name in DATASETS:
        file_path = resolve_file(input_dir, name)
        try:
            process_dataset(file_path, staging_dir)
        except (FileNotFoundError, ValueError) as e:
            # Bắt exception cụ thể kèm ngữ cảnh rõ ràng trước khi raise
            logger.error("Error processing dataset=%s file=%s: %s", name, file_path, e)
            raise
        except Exception:
            logger.exception("Unexpected error in dataset=%s file=%s", name, file_path)
            raise

    logger.info("=== FILE PIPELINE SUCCESS ===")


def main():
    parser = argparse.ArgumentParser(
        description="Lab 5: File Ingestion Batch Runner (RAW -> STAGING Pipeline)"
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=SETTINGS.root / "data" / "incremental" / "day_2026-07-01",
        help="Thư mục chứa dữ liệu thô đầu vào",
    )
    args = parser.parse_args()

    run_pipeline(input_dir=args.input_dir, staging_dir=SETTINGS.staging_dir)


if __name__ == "__main__":
    main()
