import json
import pytest
import pandas as pd
from pathlib import Path
from src.extract_files import read_dataset, profile


def test_read_csv_success(tmp_path: Path):
    """1. Đọc file CSV trả về DataFrame hợp lệ."""
    csv_file = tmp_path / "sample.csv"
    csv_file.write_text("id,name\n1,Alice\n2,Bob", encoding="utf-8")

    df = read_dataset(csv_file)
    assert isinstance(df, pd.DataFrame)
    assert len(df) == 2
    assert list(df.columns) == ["id", "name"]


def test_read_json_nested_data(tmp_path: Path):
    """2. Đọc JSON cấu trúc list hoặc bọc bởi {'data': [...]}."""
    # Test JSON dạng list
    json_list_file = tmp_path / "sample_list.json"
    json_list_file.write_text(
        json.dumps([{"id": 1, "val": "A"}, {"id": 2, "val": "B"}]),
        encoding="utf-8",
    )
    df_list = read_dataset(json_list_file)
    assert len(df_list) == 2
    assert df_list.iloc[0]["val"] == "A"

    # Test JSON bọc bởi {"data": [...]}
    json_nested_file = tmp_path / "sample_nested.json"
    json_nested_file.write_text(
        json.dumps({"status": "ok", "data": [{"id": 3, "val": "C"}]}),
        encoding="utf-8",
    )
    df_nested = read_dataset(json_nested_file)
    assert len(df_nested) == 1
    assert df_nested.iloc[0]["id"] == 3


def test_read_file_not_found(tmp_path: Path):
    """3. Kiểm tra ném FileNotFoundError khi đường dẫn file không tồn tại."""
    not_exist = tmp_path / "not_exist.csv"
    with pytest.raises(FileNotFoundError):
        read_dataset(not_exist)


def test_unsupported_file_extension(tmp_path: Path):
    """4. Kiểm tra ném ValueError với định dạng không hỗ trợ."""
    unsupported = tmp_path / "sample.xlsx"
    unsupported.write_text("mock binary", encoding="utf-8")
    with pytest.raises(ValueError):
        read_dataset(unsupported)


def test_profile_metrics():
    """5. Đo lường chính xác rows, columns, missing, duplicates."""
    df = pd.DataFrame({
        "col_a": [1, 2, 2, None],
        "col_b": ["x", "y", "y", "z"],
    })
    metrics = profile(df)
    assert metrics["rows"] == 4
    assert metrics["columns"] == ["col_a", "col_b"]
    assert metrics["missing"]["col_a"] == 1
    assert metrics["missing"]["col_b"] == 0
    assert metrics["duplicates"] == 1
