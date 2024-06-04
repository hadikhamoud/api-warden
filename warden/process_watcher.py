import os
import threading
import logging
import time
import sys
import psutil


log_filename = os.path.join(os.path.dirname(__file__), 'process_watcher.log')
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    filename=log_filename,
                    filemode='a')

console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logging.getLogger('').addHandler(console_handler)

class ProcessWatcher:
    def __init__(self, pid, command=None, callback=None):
        self.pid = pid
        self.command = command
        self.callback = callback
        self.thread = threading.Thread(target=self.monitor_process)
        self.running = False

    def start(self):
        self.running = True
        self.thread.start()

    def stop(self):
        self.running = False
        self.thread.join()

    def monitor_process(self):
        try:
            p = psutil.Process(self.pid)
            logging.info(f"Started monitoring process {self.pid} - {p.name()}")
        except psutil.NoSuchProcess:
            logging.info(f"Process {self.pid} does not exist.")
            return

        while self.running:
            try:
                if not psutil.pid_exists(self.pid):
                    logging.info(f"Process {self.pid} has stopped.")
                    break

                p_status = p.status()
                if p_status == psutil.STATUS_ZOMBIE:
                    logging.info(f"Process {self.pid} - {p.name()} has become a zombie.")
                    break

            except psutil.NoSuchProcess:
                logging.info(f"Process {self.pid} has stopped.")
                break

            time.sleep(10)

def daemonize():
    pid = os.fork()
    if pid > 0:
        sys.exit()

    os.setsid()

    pid = os.fork()
    if pid > 0:
        sys.exit()

    os.chdir('/')

    sys.stdout.flush()
    sys.stderr.flush()
    with open('/dev/null', 'r') as dev_null:
        os.dup2(dev_null.fileno(), sys.stdin.fileno())
    with open('/dev/null', 'a+') as dev_null:
        os.dup2(dev_null.fileno(), sys.stdout.fileno())
        os.dup2(dev_null.fileno(), sys.stderr.fileno())

if __name__ == "__main__":
    daemonize()
    watcher = ProcessWatcher(1017)  
    watcher.start()
    
