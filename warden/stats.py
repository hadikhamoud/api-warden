import socket
import os
import pwd



def get_local_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            return socket.gethostname(), local_ip
    except Exception as e:
        return str(e)

def get_user():
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        return os.environ.get('USER') or os.environ.get('LOGNAME') or 'unknown'

def get_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "r") as f:
            return f.read().replace('\x00', ' ').strip()
    except:
        return str(pid)

def get_call_details(pid=None):
    hostname, ip = get_local_ip()
    user = get_user()
    cmdline = get_cmdline(pid or os.getpid())

    return {
        "hostname": hostname,
        "ip": ip,
        "user": user,
        "cmdline": cmdline
    }
