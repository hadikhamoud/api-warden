import argparse
import subprocess
import sys
from warden.config import load_config, edit_config, save_config
from warden.logger import logger
from warden.process_manager import ProcessManager
from warden.api import send_alert_to_api
from warden.stats import get_call_details
from warden.bpm_monitor import BPMWatcher

process_manager = ProcessManager()



def watch_bpm(args):
    """Starts monitoring a directory and sends API call if no changes are detected."""
    logger.debug('Entered watch_bpm function.')
    config = load_config()
    directory_or_file_path = args.directory_or_file
    print(f"directory_or_file_path: {directory_or_file_path}")
    
    check_interval = args.check_interval
    num_of_checks = args.tries
    endpoint_url = config["api"]["endpoint"]
 

    def send_alert(endpoint_url, *args, **kwargs):
        print("Sending alert to API due to inactivity")
        payload = {"source": get_call_details(),
                   "type": "heartbeat"}
        send_alert_to_api(endpoint_url, *args, **kwargs, payload=payload)

    watcher = BPMWatcher(directory_or_file_path, check_interval, num_of_checks)
    watcher.start(send_alert, endpoint_url)



def set_api_url(args):
    config = load_config()
    print(config)
    config['api']['endpoint'] = args.url
    save_config(config)
    print(f"API endpoint URL set to: {args.url}")

def edit_configuration(args):
    """Edits a configuration value."""
    config = load_config()
    edit_config(config, args.key, args.value, args.config)
    
    print(f"Configuration '{args.key}' updated to '{args.value}'.")



def main():
    # Parse the arguments at the start so we can use them in multiple places
    args, parser = parse_args()

  
    if 'watch' in sys.argv:
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
    parser.add_argument("--config", type=str, default="config.json", help="Path to the configuration file.")
    subparsers = parser.add_subparsers(title="commands")

    set_url_parser = subparsers.add_parser("set-url", help="Set the API endpoint URL.")
    set_url_parser.add_argument("url", type=str, help="The API endpoint URL to set.")
    set_url_parser.set_defaults(func=set_api_url)
    

    # Watch bpm command
    watch_bpm_parser = subparsers.add_parser("bpm", help="Monitor a directory and send alert if no changes are detected.")
    watch_bpm_parser.add_argument("-d", "--directory_or_file",type=str, help="Directory path to monitor.")
    watch_bpm_parser.add_argument("-i", "--check-interval", type=int, default=60, help="Interval in seconds to check for changes.")
    watch_bpm_parser.add_argument("-t", "--tries", type=int, default=3, help="consecutives callbacks to send alert.")
    watch_bpm_parser.set_defaults(func=watch_bpm)
    
    return parser.parse_args(), parser

    

if __name__ == "__main__":
    main()
