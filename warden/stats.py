import socket
import psutil
import getpass

def get_local_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            return  socket.gethostname(), local_ip
          
    except Exception as e:
        return str(e)


def get_user():
    return getpass.getuser()


def get_cmdline(pid):
    try:
        process = psutil.Process(pid)
        return " ".join(process.cmdline())
    
    except Exception as e:
        return str(e)


def get_call_details(pid):
    hostname, ip = get_local_ip()
    user = get_user()
    cmdline = get_cmdline(pid)

    return {
        "hostname": hostname,
        "ip": ip,
        "user": user,
        "cmdline": cmdline
    }