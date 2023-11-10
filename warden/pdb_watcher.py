import subprocess
import time
import platform
from warden.stats import get_call_details


class PDBWatcher:
    def __init__(self, pid, throttle, check_interval, num_of_checks, long_pause_duration):
        self.pid = pid
        self.throttle = throttle
        self.check_interval = check_interval
        self.num_of_checks = num_of_checks
        self.long_pause_duration = long_pause_duration
        



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


    def watch(self, alert_func, *args, **kwargs):
        consecutive_S_plus = 0
        is_long_pause_active = False  # Flag to track if the long pause is active

        while True:
            if is_long_pause_active:
                time.sleep(self.long_pause_duration)
                is_long_pause_active = False  # Reset the long pause flag

            state = self.get_process_state()

            if state is None: 
                break

            elif 'S+' in state:
            
                consecutive_S_plus += 1

                if consecutive_S_plus >= self.num_of_checks:
                    alert_func(*args, **kwargs)
                    consecutive_S_plus = 0
                    is_long_pause_active = True  # Activate the long pause

                time.sleep(self.throttle)
            else:
            
                consecutive_S_plus = 0  

            time.sleep(self.check_interval) 