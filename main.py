import os
import argparse
import subprocess
import threading
from http.client import HTTPConnection
import tailer
import psutil
import json
import time

# Function to update .env file
def set_default_endpoint(endpoint):
    try:
        with open('.env', 'r') as f:
            lines = f.readlines()

        with open('.env', 'w') as f:
            for line in lines:
                if line.startswith('DEFAULT_ENDPOINT='):
                    continue
                f.write(line)
            f.write(f"DEFAULT_ENDPOINT={endpoint}\n")
        print(f"Default endpoint set to {endpoint}")

    except Exception as e:
        print(f"Failed to update .env file: {e}")

# Function to load .env file into environment variables
def load_env():
    try:
        with open('.env', 'r') as f:
            for line in f:
                name, value = line.strip().split('=', 1)
                os.environ[name] = value
    except Exception as e:
        print(f"Failed to load .env file: {e}")

def watch_log_file(log_file_path, keyword, endpoint):
    for line in tailer.follow(open(log_file_path)):
        if keyword in line:
            send_http_request(f'Keyword {keyword} found in log file.', endpoint=endpoint)
            break

# Function to watch a process by name
def watch_process_by_name(process_name, endpoint):
    while True:
        found_process = False
        for process in psutil.process_iter(['pid', 'name']):
            if process.info['name'] == process_name:
                found_process = True
                break
        if not found_process:
            send_http_request(f'Process {process_name} has been killed.', endpoint)
            break
        time.sleep(5)

# Function to watch a process by PID
def watch_process_by_pid(pid, endpoint):
    while True:
        try:
            process = psutil.Process(pid)
            # if the process doesn't exist, Process constructor will raise a NoSuchProcess exception
        except psutil.NoSuchProcess:
            send_http_request(f'Process with PID {pid} has been killed.', endpoint)
            break
        time.sleep(5)

# Function to send HTTP request
def send_http_request(message, endpoint):
    headers = {'Content-Type': 'application/json'}
    conn = HTTPConnection(endpoint)
    conn.request("POST", "/", json.dumps({'message': message}), headers)
    response = conn.getresponse()
    print(f"Sent HTTP request to {endpoint}: {response.status}, {response.reason}")

def main():
    load_env()
    default_endpoint = os.environ.get("DEFAULT_ENDPOINT", "localhost:8080")

    parser = argparse.ArgumentParser(description='Run and/or watch a process, and watch a log file.')
    parser.add_argument('--set-default-endpoint', help='Set default HTTP endpoint.')
    parser.add_argument('--command', help='Command to run a process.')
    parser.add_argument('--process', help='Name of the process to watch.')
    parser.add_argument('--pid', type=int, help='PID of the process to watch.')
    parser.add_argument('--log', help='Path of the log file to watch.')
    parser.add_argument('--keyword', help='Keyword to watch in the log file.')
    parser.add_argument('--endpoint', default=default_endpoint, help='HTTP endpoint to send requests to.')

    args = parser.parse_args()

    if args.set_default_endpoint:
        set_default_endpoint(args.set_default_endpoint)
        return

    endpoint = args.endpoint

    if args.command:
        process = subprocess.Popen(args.command, shell=True)
        pid = process.pid
        process_thread = threading.Thread(target=watch_process_by_pid, args=(pid, endpoint), daemon=False)
        process_thread.start()
    elif args.process:
        process_thread = threading.Thread(target=watch_process_by_name, args=(args.process, endpoint), daemon=False)
        process_thread.start()
    elif args.pid:
        process_thread = threading.Thread(target=watch_process_by_pid, args=(args.pid, endpoint), daemon=False)
        process_thread.start()

    if args.log and args.keyword:
        log_thread = threading.Thread(target=watch_log_file, args=(args.log, args.keyword, endpoint), daemon=False)
        log_thread.start()

    if args.command:
        process.wait()

if __name__ == '__main__':
    main()
