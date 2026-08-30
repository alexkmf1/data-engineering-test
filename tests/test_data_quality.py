import pandas as pd
import pytest

from src.silver.data_quality import (
    remove_duplicates,
    validate_unique,
    validate_not_null,
    validate_timestamp_order
)


def test_remove_duplicates():

    df = pd.DataFrame({
        "id": ["1", "1", "2"],
        "name": ["Carrier A", "Carrier A", "Carrier B"]
    })

    result = remove_duplicates(df)

    assert len(result) == 2


def test_validate_unique():

    df = pd.DataFrame({
        "id": ["1", "1", "2"]
    })

    with pytest.raises(ValueError):
        validate_unique(
            df,
            ["id"],
            "test_dataset"
        )


def test_validate_not_null():

    df = pd.DataFrame({
        "id": ["1", None, "3"]
    })

    with pytest.raises(ValueError):
        validate_not_null(
            df,
            ["id"],
            "test_dataset"
        )


def test_validate_timestamp_order():

    df = pd.DataFrame({
        "created_at": pd.to_datetime([
            "2026-05-01 10:00:00",
            "2026-05-01 11:00:00"
        ]),
        "updated_at": pd.to_datetime([
            "2026-05-01 10:30:00",
            "2026-05-01 10:30:00"
        ])
    })

    with pytest.raises(ValueError):
        validate_timestamp_order(
            df,
            [
                ("created_at", "updated_at")
            ],
            "test_dataset"
        )