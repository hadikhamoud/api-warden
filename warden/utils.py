import os
import re
import socket
import argparse
import ast

def file_exists(filepath):
    """Check if a file exists."""
    return os.path.exists(filepath) and os.path.isfile(filepath)

def tail_file(filepath, num_lines):
    """Get the last num_lines from a file. Mimics the 'tail' Unix command."""
    with open(filepath, 'r') as f:
        content = f.readlines()
    return content[-num_lines:]

def sanitize_string(input_string):
    """Remove sensitive or unwanted information from a log line or string."""
    # This is just an example; adjust based on your specific needs.
    sanitized = re.sub(r"(?i)password=\w+", "password=REDACTED", input_string)
    return sanitized

def validate_ip(ip_str):
    """Check if a given string is a valid IPv4 address."""
    pattern = re.compile(r"^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$")
    return bool(pattern.match(ip_str))


def get_machine_name():
    """Return the machine's name."""
    return socket.gethostname()

def get_local_ip():
    """Return the local IP address of the machine."""
    # The following retrieves the IP address that is used as the source when connecting to an external location.
    # It doesn't actually establish a connection but is a commonly used trick to get the local IP.
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))  # Using Google's public DNS
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception as e:
        raise RuntimeError("Failed to determine local IP address") from e


def parse_dict(arg):
    try:
        return ast.literal_eval(arg)
    except Exception as e:
        raise argparse.ArgumentTypeError(f"Invalid dict: {arg} - {e}")

