import argparse
import subprocess
import sys
import time

from warden.config import load_config, edit_config
from warden.watcher import Warden 
from warden.api import send_alert_to_api
from warden.logger import logger
from warden.process_manager import ProcessManager


process_manager = ProcessManager()

def watch_logs(args):
    """Starts watching logs based on the configuration."""
    logger.debug('Entered watch_logs function.')
    config = load_config(args.config)
    log_file_path = config["logfile"]
    patterns = config["patterns"]
    logger.debug(f"Loaded configuration: {config}")
    logger.debug(f"patterns: {patterns}")

    def detected_change(pattern, line):
        print(f"Detected pattern '{pattern}' in line: {line}")
        # send_alert_to_api(config["api"]["endpoint"], pattern, line, api_key=config["api"]["key"])

    watcher = Warden(log_file_path, patterns, detected_change)
    watcher.start()
    logger.debug(f"Watching logs for file: {log_file_path}")



def edit_configuration(args):
    """Edits a configuration value."""
    config = load_config(args.config)
    edit_config(config, args.key, args.value, args.config)
    
    print(f"Configuration '{args.key}' updated to '{args.value}'.")



def list_processes(args):
    """List all tracked processes."""
    processes = process_manager.get_processes()
    if not processes:
        print("No processes are currently being tracked.")
        return
    print("Tracked Processes:")
    for process_info in processes:
        print(f"PID: {process_info['pid']}, Command: {process_info['command']}, Start Time: {process_info['start_time']}")


def kill_process(args):
    """Kill a specific process."""
    pid = args.pid
    if pid in process_manager.get_pids():
        process_manager.kill_process(pid)
        print(f"Killed process with PID: {pid}")
    else:
        print(f"No tracked process with PID: {pid}")

def kill_all_processes(args):
    """Kill all tracked processes."""
    process_manager.kill_all()
    print("All tracked processes have been killed.")

def main():
    # Parse the arguments at the start so we can use them in multiple places
    args, parser = parse_args()
    
    # If the special argument is present, it implies the 'watch' command is being executed.
    if '--run-in-background' in sys.argv:
        logger.debug('Running with --run-in-background flag.')
        watch_logs(args)  # Pass the parsed args to watch_logs

    # If the argument is not present and the command is 'watch', 
    # re-run the script with the argument in the background.
    elif 'watch' in sys.argv:
        process = subprocess.Popen(
            [sys.executable, sys.argv[0], '--run-in-background'] + sys.argv[1:],
            #stdout=subprocess.DEVVULL,
            #stderr=subprocess.DEVNULL
        )
        process_manager.add_process(process.pid, ' '.join(process.args))
        logger.debug(f"Started watch process with PID: {process.pid}")

    # Otherwise, just execute the relevant function.
    else:
        if "func" in args:
            args.func(args)
        else:
            parser.print_help()


def parse_args():
    logger.debug('Entered watch_or_edit_config function.')
    parser = argparse.ArgumentParser(description="Warden - Watch logs and alert on specific patterns.")
    parser.add_argument("--config", type=str, default="config.yaml", help="Path to the configuration file.")
    parser.add_argument("--run-in-background", action="store_true", help=argparse.SUPPRESS)
    subparsers = parser.add_subparsers(title="commands")
    
    # Watch logs command
    watch_parser = subparsers.add_parser("watch", help="Start watching logs based on the configuration.")
    watch_parser.set_defaults(func=watch_logs)

    # Kill command
    list_processes_parser = subparsers.add_parser("list", help="List all tracked PIDs.")
    list_processes_parser.set_defaults(func=list_processes)

    # Kill a specific process command
    kill_process_parser = subparsers.add_parser("kill", help="Kill a specific process by PID.")
    kill_process_parser.add_argument("pid", type=int, help="The process ID to kill.")
    kill_process_parser.set_defaults(func=kill_process)

    # Kill all processes command
    kill_all_parser = subparsers.add_parser("kill-all", help="Kill all tracked processes.")
    kill_all_parser.set_defaults(func=kill_all_processes)

    # Edit configuration command
    edit_parser = subparsers.add_parser("edit-config", help="Edit a specific configuration value.")
    edit_parser.add_argument("key", type=str, help="Configuration key to edit.")
    edit_parser.add_argument("value", type=str, help="New value for the configuration key.")
    edit_parser.set_defaults(func=edit_configuration)
    
    return parser.parse_args(), parser

    

if __name__ == "__main__":
    main()
