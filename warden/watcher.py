import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


class WardenHandler(FileSystemEventHandler):

    def __init__(self, log_file, patterns, callback):
        self.log_file = log_file
        self.callback = callback
        self.patterns = patterns
        self.last_position = 0

    def read_new_lines(self):
        with open(self.log_file, 'r') as file:
            file.seek(self.last_position) 
            new_lines = file.readlines()
            self.last_position = file.tell()
            return new_lines
        
    def check_patterns_in_line(self, line):
        for pattern in self.patterns:
            if pattern in line:
                self.callback(pattern, line)

    def on_modified(self, event):
        if event.src_path == self.log_file:
            new_lines = self.read_new_lines()
            for line in new_lines:
                self.check_patterns_in_line(line)



class Warden:
    def __init__(self, log_file, patterns, callback):
        self.log_file = log_file
        self.callback = callback
        self.patterns = patterns

    def start(self):
        event_handler = WardenHandler(self.log_file, self.patterns, self.callback)
        observer = Observer()
        observer.schedule(event_handler, path=self.log_file, recursive=False)
        observer.start()

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            observer.stop()
        observer.join()

def detected_change(pattern, line):
    # This function will be called when one of the patterns is detected in the log file.
    print(f"Detected pattern '{pattern}' in line: {line}")
    # Insert API request logic here or other action based on the detected pattern

if __name__ == "__main__":
    log_file_path = "/path/to/your/logfile.log"
    patterns_to_watch = ['ERROR', 'CRITICAL', 'WARNING']
    watcher = Warden(log_file_path, patterns_to_watch, detected_change)
    watcher.start()
