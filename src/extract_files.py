from pathlib import Path
import json
import pandas as pd


def read_dataset(path: Path) -> pd.DataFrame:
    """Đọc file CSV hoặc JSON và trả về DataFrame."""
    path = Path(path)

    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    if path.suffix.lower() == ".csv":
        return pd.read_csv(path)

    if path.suffix.lower() == ".json":
        obj = json.loads(path.read_text(encoding="utf-8"))
        return pd.DataFrame(
            obj if isinstance(obj, list)
            else obj.get("data", [])
        )

    raise ValueError(f"Unsupported file type: {path.suffix}")


def profile(df: pd.DataFrame) -> dict:
    """Tính toán metrics chất lượng dữ liệu: rows, columns, missing, duplicates."""
    return {
        "rows": len(df),
        "columns": list(df.columns),
        "missing": df.isna().sum().to_dict(),
        "duplicates": int(df.duplicated().sum()),
    }
