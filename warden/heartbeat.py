import threading
import time
import logging

class HeartbeatSender:
    def __init__(self, interval, log_file):
        self.interval = interval
        self.log_file = log_file
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
        logging.basicConfig(filename=self.log_file, level=logging.INFO, format='%(asctime)s %(message)s')
        logging.info("Heartbeat sent")