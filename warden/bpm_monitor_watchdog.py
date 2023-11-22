import os
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from warden.logger import logger

class BPMWatcher:
    def __init__(self, path, interval):
        self.path = os.path.abspath(path)  # Normalize the path
        self.interval = interval
        self.last_modified = time.time()
        self.observer = Observer()
        self.is_file = os.path.isfile(self.path)

    class FileHandler(FileSystemEventHandler):
        def __init__(self, watcher):
            self.watcher = watcher

        def on_any_event(self, event):
            # Normalize the path for accurate comparison
            event_path = os.path.abspath(event.src_path)
            logger.debug(f"Event path: {event_path}")
            if event_path == self.watcher.path:
                logger.debug(f"Modified file: {event.src_path}")
                self.watcher.last_modified = time.time()

    class DirectoryHandler(FileSystemEventHandler):
        def __init__(self, watcher):
            self.watcher = watcher

        def on_any_event(self, event):
            logger.debug(f"Event in directory: {event}")
            self.watcher.last_modified = time.time()

    def start(self, callback, endpoint_url):
        if self.is_file:
            event_handler = self.FileHandler(self)
            watch_path = os.path.dirname(self.path)
        else:
            event_handler = self.DirectoryHandler(self)
            watch_path = self.path

        self.observer.schedule(event_handler, watch_path, recursive=not self.is_file)
        self.observer.start()
        try:
            while True:
                time.sleep(self.interval)
                # if time.time() - self.last_modified > self.interval:
                #     callback(endpoint_url)
        except KeyboardInterrupt:
            self.observer.stop()
        self.observer.join()