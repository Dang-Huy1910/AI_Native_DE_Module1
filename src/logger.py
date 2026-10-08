import logging
from pathlib import Path


def get_logger(name: str = 'pipeline') -> logging.Logger:
    """Cấu hình logger với FileHandler và StreamHandler, level INFO, format chuẩn."""
    Path('logs').mkdir(exist_ok=True)
    logger = logging.getLogger(name)

    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)

    fmt = logging.Formatter(
        '%(asctime)s | %(levelname)s | %(name)s | %(message)s'
    )

    file_handler = logging.FileHandler('logs/pipeline.log', encoding='utf-8')
    file_handler.setFormatter(fmt)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(fmt)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger
