from functools import wraps
from warden.stats import get_call_details
from warden.api import send_alert_to_api
from warden.config import load_config

def monitor_api(url = None):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                if url is None:
                    config = load_config()
                    url = config["api"]["endpoint"]                    
                result = func(*args, **kwargs)
                payload = {"source": get_call_details(),
                   "type": "decorator",
                   "status": "success"}
            
                send_alert_to_api(url, payload=payload)
                
                return result
            except Exception as e:                                
                payload = {"source": get_call_details(),
                   "type": "decorator",
                   "status": "success",
                   "error:": str(e)}
                send_alert_to_api(url, payload=payload)
                
                
                raise
        return wrapper
    return decorator