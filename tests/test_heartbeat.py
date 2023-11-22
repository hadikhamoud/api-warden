from warden import heartbeat
import time

heartbeat_interval = 2
log_file = 'heartbeat.log'
heartbeat_sender = heartbeat.HeartbeatSender(heartbeat_interval, log_file)
heartbeat_sender.start()

while True:
    time.sleep(1)