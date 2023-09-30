import argparse
from config import load_config, edit_config
from watcher import LogWatcher
from api import send_alert_to_api

def watch_logs(args):
    """Starts watching logs based on the configuration."""
    config = load_config(args.config)
    log_file_path = config["logfile"]
    patterns = config["patterns"]

    def detected_change(pattern, line):
        print(f"Detected pattern '{pattern}' in line: {line}")
        send_alert_to_api(config["api"]["endpoint"], pattern, line, api_key=config["api"]["key"])

    watcher = LogWatcher(log_file_path, patterns, detected_change)
    watcher.start()

def edit_configuration(args):
    """Edits a configuration value."""
    config = load_config(args.config)
    edit_config(config, args.key, args.value, args.config)
    print(f"Configuration '{args.key}' updated to '{args.value}'.")

def main():
    parser = argparse.ArgumentParser(description="LogWatcher - Watch logs and alert on specific patterns.")
    parser.add_argument("--config", type=str, default="config.yaml", help="Path to the configuration file.")

    subparsers = parser.add_subparsers(title="commands")

    # Watch logs command
    watch_parser = subparsers.add_parser("watch", help="Start watching logs based on the configuration.")
    watch_parser.set_defaults(func=watch_logs)

    # Edit configuration command
    edit_parser = subparsers.add_parser("edit-config", help="Edit a specific configuration value.")
    edit_parser.add_argument("key", type=str, help="Configuration key to edit.")
    edit_parser.add_argument("value", type=str, help="New value for the configuration key.")
    edit_parser.set_defaults(func=edit_configuration)

    args = parser.parse_args()
    if "func" in args:
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
