def remove_duplicates(df):

    business_columns = [
        column
        for column in df.columns
        if not column.startswith("_")
    ]

    return (
        df
        .drop_duplicates(subset=business_columns)
        .reset_index(drop=True)
    )


def validate_unique(df, columns, dataset_name):

    for column in columns:

        duplicate_count = df[column].duplicated().sum()

        if duplicate_count > 0:
            raise ValueError(
                f"{dataset_name}.{column} contains "
                f"{duplicate_count} duplicate values."
            )


def validate_not_null(df, columns, dataset_name):

    for column in columns:

        null_count = df[column].isna().sum()

        if null_count > 0:
            raise ValueError(
                f"{dataset_name}.{column} contains "
                f"{null_count} null values."
            )


def validate_timestamp_order(
    df,
    column_pairs,
    dataset_name
):

    for start_column, end_column in column_pairs:

        invalid_rows = (
            df[end_column] < df[start_column]
        )

        invalid_count = invalid_rows.sum()

        if invalid_count > 0:
            raise ValueError(
                f"{dataset_name} contains "
                f"{invalid_count} rows where "
                f"{end_column} is earlier than "
                f"{start_column}."
            )