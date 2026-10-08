import pandas as pd

TEXT_ENUM_COLUMNS = [
    "status",
    "payment_status",
    "payment_method",
    "channel",
]

NUMERIC_COLUMNS = {
    "quantity",
    "unit_price",
    "discount_amount",
    "order_total",
    "amount",
    "cost_price",
}


def normalize(df: pd.DataFrame) -> pd.DataFrame:
    """TODO Buổi 5: normalize column names, strings, email/enums, numerics, datetime."""
    out = df.copy()

    # 1. Chuẩn hóa tên cột
    out.columns = [c.strip().lower() for c in out.columns]

    # 2. Trim khoảng trắng thừa cho mọi cột text (không lowercase toàn bộ để giữ nguyên tên người/sản phẩm)
    for col in out.columns:
        if out[col].dtype == "object":
            out[col] = out[col].apply(
                lambda x: x.strip() if isinstance(x, str) else x
            )

    # 3. Viết thường email
    if "email" in out.columns:
        out["email"] = out["email"].str.lower()

    # 4. Viết thường các cột enum/trạng thái
    for col in TEXT_ENUM_COLUMNS:
        if col in out.columns:
            out[col] = out[col].str.lower()

    # 5. Parse các cột datetime kết thúc bằng _at hoặc _date
    for col in [
        c for c in out.columns
        if c.endswith("_at") or c.endswith("_date")
    ]:
        out[col] = pd.to_datetime(out[col], errors="coerce", utc=True)

    # 6. Parse các cột số
    for col in NUMERIC_COLUMNS:
        if col in out.columns:
            out[col] = pd.to_numeric(out[col], errors="coerce")

    # 7. Bổ sung technical metadata (source_system và ingested_at)
    if "source_system" not in out.columns:
        out["source_system"] = "file_batch"
    else:
        out["source_system"] = out["source_system"].fillna("file_batch")

    out["ingested_at"] = pd.Timestamp.now(tz="UTC")

    return out
