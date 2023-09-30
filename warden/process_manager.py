import os
import signal
import os
import json
import datetime

class ProcessManager:

    def __init__(self, storage_path="processes.json"):
        self.storage_path = storage_path
        self.processes = self._load_processes()

    def _load_processes(self):
        """Load processes from the storage file."""
        if os.path.exists(self.storage_path):
            with open(self.storage_path, 'r') as file:
                return json.load(file)
        return {}

    def _save_processes(self):
        """Save processes to the storage file."""
        with open(self.storage_path, 'w') as file:
            json.dump(self.processes, file)

    def add_process(self, pid, command):
        """Add a process with its details."""
        self.processes[str(pid)] = {
            "pid": pid,
            "command": command,
            "start_time": datetime.datetime.now().isoformat()
        }
        self._save_processes()

    def remove_process(self, pid):
        """Remove a process."""
        pid_str = str(pid)
        if pid_str in self.processes:
            del self.processes[pid_str]
            self._save_processes()

    def kill_process(self, pid):
        """Kill a specific process."""
        try:
            os.kill(pid, signal.SIGTERM)
            self.remove_process(pid)
        except ProcessLookupError:
            print(f"Process {pid} not found.")
            self.remove_process(pid)
        except Exception as e:
            print(f"Error while killing process {pid}: {e}")

    def kill_all(self):
        """Kill all tracked processes."""
        for pid_str in list(self.processes.keys()):
            self.kill_process(int(pid_str))

    def get_processes(self):
        """Get all tracked processes."""
        return self.processes.values()

