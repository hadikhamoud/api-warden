import os
import time

class BPMWatcher:
    def __init__(self, path, interval, num_of_checks):
        self.path = path
        self.interval = interval
        self.num_of_checks = num_of_checks
        self.callback_counter = 0

    def get_last_modified_time(self):
        if os.path.isdir(self.path):
            return max(os.path.getmtime(os.path.join(self.path, f)) for f in os.listdir(self.path))
        else:
            return os.path.getmtime(self.path)

    def start(self, callback, endpoint_url):
        last_modified_time = self.get_last_modified_time()

        while True:
            current_time = time.time()
            current_modified_time = self.get_last_modified_time()

            # Reset the counter if the file is modified
            if current_modified_time != last_modified_time:
                self.callback_counter = 0
                last_modified_time = current_modified_time

            # Check if the file hasn't been modified for the specified interval
            if current_time - last_modified_time >= self.interval:
                if self.callback_counter < self.num_of_checks:
                    callback(endpoint_url)
                    self.callback_counter += 1

            time.sleep(self.interval)