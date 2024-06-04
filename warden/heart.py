import threading
import os
import time
import random

class Beat:
    def __init__(self, interval = 10, log_file=None, max_lines=5):
        self.interval = interval
        self.log_file = log_file if log_file is not None else f"heartbeat_{random.randint(10000, 99999)}.log"
        self.max_lines = max_lines
        self.current_lines = 0
        self.thread = threading.Thread(target=self.run)
        self.thread.daemon = True
        self.running = False
        
        print(f"Log file: {self.log_file}")
        print(f"Full path: {os.path.abspath(self.log_file)}")
        print(f"Max lines: {self.max_lines}")
        print(f"Interval: {self.interval}")

    def start(self):
        self.running = True
        self.thread.start()

    def stop(self):
        self.running = False
        self.thread.join()

    def run(self):
        while self.running:
            self.log_heartbeat()
            time.sleep(self.interval)

    def log_heartbeat(self):
        if self.current_lines >= self.max_lines:
            open(self.log_file, 'w').close()
            self.current_lines = 0

        with open(self.log_file, 'a') as f:
            f.write(f"Heartbeat sent at {time.asctime()}\n")
            self.current_lines += 1
