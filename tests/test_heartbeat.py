import os 
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from warden.heart import Beat
import time

heartbeat_sender = Beat(log_file="/Users/hadihamoud/Desktop/hadi/sandbox/warden_log.log")
heartbeat_sender.start()


while True:
    time.sleep(1)


