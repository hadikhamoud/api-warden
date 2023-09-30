import logging
from logging.handlers import RotatingFileHandler
import os


if not os.path.exists('logs'):
    os.makedirs('logs')

LOG_FILENAME = 'logs/app.log'
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
LOG_LEVEL = logging.INFO
MAX_LOG_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
BACKUP_COUNT = 3  # Keep three backup copies

# Configure the root logger
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

# Add a rotating file handler
handler = RotatingFileHandler(LOG_FILENAME, maxBytes=MAX_LOG_FILE_SIZE, backupCount=BACKUP_COUNT)
formatter = logging.Formatter(LOG_FORMAT)
handler.setFormatter(formatter)
logger.addHandler(handler)
