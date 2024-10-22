from functools import wraps
import traceback
from warden.stats import get_call_details
from warden.api import send_alert_to_api
from warden.config import load_config

def monitor_api(url=None, headers=None, body=None):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            nonlocal url, headers, body
            try:
                if url is None:
                    config = load_config()
                    url = config["api"]["endpoint"]
                result = func(*args, **kwargs)
                payload = {
                    "source": get_call_details(),
                    "type": "decorator",
                    "status": "success"
                }
                if body:
                    payload.update(body)

                send_alert_to_api(url, headers=headers, payload=payload)

                return result
            except Exception as e:
                payload = {
                    "source": get_call_details(),
                    "type": "decorator",
                    "status": "error",
                    "error": str(e),
                    "stack_trace": traceback.format_exc()
                }
                if body:
                    payload.update(body)
                send_alert_to_api(url, headers=headers, payload=payload)

                raise
        return wrapper
    return decorator
