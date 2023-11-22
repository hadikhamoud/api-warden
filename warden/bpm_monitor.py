import os
import time

class BPMWatcher:
    def __init__(self, path, interval):
        self.path = path
        self.interval = interval
        self.last_modified = self.get_last_modified_time()
        self.last_checked = time.time()

    def get_last_modified_time(self):
        if os.path.isdir(self.path):
            return max(os.path.getmtime(os.path.join(self.path, f)) for f in os.listdir(self.path))
        else:
            return os.path.getmtime(self.path)

    def start(self, callback, endpoint_url):
        while True:
            current_modified_time = self.get_last_modified_time()
            current_time = time.time()

            if current_modified_time > self.last_modified:
                self.last_modified = current_modified_time
                self.last_checked = current_time
            elif current_time - self.last_checked >= self.interval:
                callback(endpoint_url)
                self.last_checked = current_time

            time.sleep(self.interval)