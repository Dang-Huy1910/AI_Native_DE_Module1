import pandas as pd
from src.transform import normalize


def test_normalize_raw_immutability():
    """6. Xác nhận DataFrame nguồn không bị thay đổi sau khi chuẩn hóa (Pure Function)."""
    raw_df = pd.DataFrame({
        " NAME ": ["  John Doe  "],
        "EMAIL": ["  TEST@EXAMPLE.COM  "],
    })
    raw_cols_before = list(raw_df.columns)
    raw_val_before = raw_df["EMAIL"].iloc[0]

    clean_df = normalize(raw_df)

    # DataFrame gốc vẫn giữ nguyên
    assert list(raw_df.columns) == raw_cols_before
    assert raw_df["EMAIL"].iloc[0] == raw_val_before

    # DataFrame mới được chuẩn hóa
    assert list(clean_df.columns) == ["name", "email", "source_system", "ingested_at"]
    assert clean_df["name"].iloc[0] == "John Doe"
    assert clean_df["email"].iloc[0] == "test@example.com"


def test_normalize_strings_and_enums():
    """7. Xác nhận trim khoảng trắng và lowercase email, status, payment_method, channel."""
    df = pd.DataFrame({
        "city": ["  Hanoi  "],
        "email": ["  AN@GMAIL.COM  "],
        "status": ["  COMPLETED  "],
        "payment_method": ["  BANK_TRANSFER  "],
        "channel": ["  ONLINE  "],
    })

    clean = normalize(df)

    assert clean["city"].iloc[0] == "Hanoi"
    assert clean["email"].iloc[0] == "an@gmail.com"
    assert clean["status"].iloc[0] == "completed"
    assert clean["payment_method"].iloc[0] == "bank_transfer"
    assert clean["channel"].iloc[0] == "online"


def test_normalize_numeric_and_datetime():
    """8. Xác nhận ép kiểu số và parse ISO/UTC datetime."""
    df = pd.DataFrame({
        "quantity": ["10", "invalid"],
        "unit_price": ["1500.50", "2000"],
        "created_at": ["2026-07-01T10:00:00+07:00", "invalid_date"],
        "order_date": ["2026-07-01", "2026-07-02"],
    })

    clean = normalize(df)

    # Numeric: chuỗi hợp lệ thành số, chuỗi sai thành NaN (errors='coerce')
    assert pd.api.types.is_numeric_dtype(clean["quantity"])
    assert clean["quantity"].iloc[0] == 10.0
    assert pd.isna(clean["quantity"].iloc[1])

    assert pd.api.types.is_numeric_dtype(clean["unit_price"])
    assert clean["unit_price"].iloc[0] == 1500.50

    # Datetime: chuỗi hợp lệ thành datetime UTC, chuỗi sai thành NaT
    assert pd.api.types.is_datetime64_any_dtype(clean["created_at"])
    assert str(clean["created_at"].iloc[0].tz) == "UTC"
    assert pd.isna(clean["created_at"].iloc[1])

    assert pd.api.types.is_datetime64_any_dtype(clean["order_date"])
