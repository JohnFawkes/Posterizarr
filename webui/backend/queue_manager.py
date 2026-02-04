import sqlite3
import json
import logging
from pathlib import Path
from datetime import datetime
from threading import Lock

logger = logging.getLogger("QueueManager")

class QueueManager:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.lock = Lock()
        self._init_db()

    def _get_connection(self):
        return sqlite3.connect(self.db_path, check_same_thread=False)

    def _init_db(self):
        """Initialize the queue database table."""
        if not self.db_path.parent.exists():
            self.db_path.parent.mkdir(parents=True, exist_ok=True)

        with self.lock:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS queue_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    asset_path TEXT NOT NULL,
                    source_type TEXT NOT NULL, -- 'url' or 'upload' (path to temp file)
                    source_data TEXT NOT NULL, -- URL or Temp File Path
                    overlay_params TEXT, -- JSON string of parameters
                    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.commit()
            conn.close()

    def add_item(self, asset_path, source_type, source_data, overlay_params):
        """Add a new item to the queue."""
        with self.lock:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO queue_items (asset_path, source_type, source_data, overlay_params, status)
                VALUES (?, ?, ?, ?, 'pending')
            """, (asset_path, source_type, source_data, json.dumps(overlay_params)))
            item_id = cursor.lastrowid
            conn.commit()
            conn.close()
            logger.info(f"Queue item added: {item_id} ({asset_path})")
            return item_id

    def get_queue(self):
        """Get all items in the queue."""
        with self.lock:
            conn = self._get_connection()
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM queue_items ORDER BY created_at ASC")
            rows = cursor.fetchall()
            conn.close()

            queue = []
            for row in rows:
                item = dict(row)
                if item['overlay_params']:
                    try:
                        item['overlay_params'] = json.loads(item['overlay_params'])
                    except json.JSONDecodeError:
                        item['overlay_params'] = {}
                queue.append(item)
            return queue

    def get_pending_items(self):
        """Get only pending items."""
        with self.lock:
            conn = self._get_connection()
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM queue_items WHERE status = 'pending' ORDER BY created_at ASC")
            rows = cursor.fetchall()
            conn.close()

            items = []
            for row in rows:
                item = dict(row)
                if item['overlay_params']:
                    item['overlay_params'] = json.loads(item['overlay_params'])
                items.append(item)
            return items

    def update_status(self, item_id, status, error_message=None):
        """Update the status of an item."""
        with self.lock:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE queue_items
                SET status = ?, error_message = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            """, (status, error_message, item_id))
            conn.commit()
            conn.close()

    def delete_item(self, item_id):
        """Delete an item from the queue."""
        with self.lock:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM queue_items WHERE id = ?", (item_id,))
            conn.commit()
            conn.close()
            logger.info(f"Queue item deleted: {item_id}")

    def clear_queue(self):
        """Delete all items from the queue."""
        with self.lock:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM queue_items")
            conn.commit()
            conn.close()
            logger.info("Queue cleared")
