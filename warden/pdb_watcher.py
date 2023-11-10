import subprocess
import time
import logging
import platform

class PDBWatcher:
    def __init__(self, pid, log_file_path, throttle, check_interval, num_of_checks, long_pause_duration):
        self.pid = pid
        self.log_file_path = log_file_path
        self.throttle = throttle
        self.check_interval = check_interval
        self.num_of_checks = num_of_checks
        self.long_pause_duration = long_pause_duration



        logging.basicConfig(filename=self.log_file_path, level=logging.DEBUG)

    def get_process_state_unix(self):
        try:
            output = subprocess.check_output(['ps', '-o', 'stat=', '-p', str(self.pid)], text=True).strip()
            return output
        except subprocess.CalledProcessError:
            return None

    def get_process_state_windows(self):
        try:
            output = subprocess.check_output(['tasklist', '/FI', f'PID eq {self.pid}'], text=True).strip()
            return output
        except subprocess.CalledProcessError:
            return None

    def get_process_state(self):
        if platform.system() == 'Windows':
            return self.get_process_state_windows()
        else:
            return self.get_process_state_unix()


    def watch(self, alert_func):
        consecutive_S_plus = 0
        is_long_pause_active = False  # Flag to track if the long pause is active

        while True:
            if is_long_pause_active:
                logging.debug(f"Long pause active for {self.long_pause_duration} seconds.\n")
                time.sleep(self.long_pause_duration)
                is_long_pause_active = False  # Reset the long pause flag

            state = self.get_process_state()

            if state is None:
                logging.debug(f"Process {self.pid} is no longer running. Exiting.\n")
                break
            elif 'S+' in state:
                logging.debug(f"Process {self.pid} is likely waiting in pdb.\n")
                consecutive_S_plus += 1

                if consecutive_S_plus >= self.num_of_checks:
                    alert_func(self.pid)
                    consecutive_S_plus = 0
                    is_long_pause_active = True  # Activate the long pause

                time.sleep(self.throttle)
            else:
                logging.debug(f"Process {self.pid} is running.\n")
                consecutive_S_plus = 0  

            time.sleep(self.check_interval) 