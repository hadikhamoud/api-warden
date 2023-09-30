import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from warden.logger import logger
import os



class WardenHandler(FileSystemEventHandler):

    def __init__(self, path, patterns, callback):
        self.path = path  # Renamed for clarity
        self.callback = callback
        self.patterns = patterns
        self.last_position = 0
        self.debounce_time = 1  
        self.last_triggered_time = 0
        self.last_positions = {}  


    def read_new_lines(self, filepath):
        position = self.last_positions.get(filepath, 0)
        with open(filepath, 'r') as file:
            file.seek(position)
            new_lines = file.readlines()
            self.last_positions[filepath] = file.tell()
            return new_lines

    def on_modified(self, event):

        if os.path.isfile(self.path) and event.src_path == self.path:
            # If you're specifically watching a file (not a directory)
            new_lines = self.read_new_lines(self.path)
            for line in new_lines:
                self.check_patterns_in_line(line)
    
        elif os.path.isdir(self.path) and os.path.isfile(event.src_path):
            # If you're watching a directory, handle each modified file individually
            new_lines = self.read_new_lines(event.src_path)
            for line in new_lines:
                self.check_patterns_in_line(line)
        
    def check_patterns_in_line(self, line):
        for pattern in self.patterns:
            if pattern in line:
                logger.debug("Pattern detected in line.")
                self.callback(pattern, line)



class Warden:
    def __init__(self, path, patterns, callback):  
        self.path = path
        self.callback = callback
        self.patterns = patterns

    def start(self):
        event_handler = WardenHandler(self.path, self.patterns, self.callback)
        
        
        if os.path.isfile(self.path):
            watch_path = os.path.dirname(self.path)
        elif os.path.isdir(self.path):
            watch_path = self.path
        else:
            raise ValueError(f"Invalid path provided: {self.path}")
        
        observer = Observer()
        observer.schedule(event_handler, path=watch_path, recursive=False)
        observer.start()
        logger.debug(f"Watching logs for: {watch_path}")
        
        try:
            while True:
                time.sleep(1)


        except KeyboardInterrupt:
            observer.stop()
        observer.join()


def detected_change(pattern, line):
    # This function will be called when one of the patterns is detected in the log file.
    logger.debug(f"Detected pattern '{pattern}' in line: {line}")
    # Insert API request logic here or other action based on the detected pattern

if __name__ == "__main__":
    log_file_path = "/path/to/your/logfile.log"
    patterns_to_watch = ['ERROR', 'CRITICAL', 'WARNING']
    watcher = Warden(log_file_path, patterns_to_watch, detected_change)
    watcher.start()
