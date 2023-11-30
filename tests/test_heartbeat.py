from warden.heart import Beat
import time

heartbeat_interval = 2
log_file = 'heartbeat_2.log'
heartbeat_sender = Beat(heartbeat_interval, log_file)
heartbeat_sender.start()


while True:
    time.sleep(1)


