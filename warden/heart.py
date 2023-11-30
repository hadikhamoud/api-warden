import threading
import time

class Beat:
    def __init__(self, interval, log_file, max_lines = 5):
        self.interval = interval
        self.log_file = log_file
        self.max_lines = max_lines
        self.current_lines = 0
        self.thread = threading.Thread(target=self.run)
        self.thread.daemon = True
        self.running = False

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


