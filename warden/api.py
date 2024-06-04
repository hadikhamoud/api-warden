from warden.logger import logger
from warden.config import load_config
import requests

config = load_config()

class APIError(Exception):
    pass

def send_alert_to_api(endpoint_url, pattern_detected=None, message_content=None, api_key=None, *args, **kwargs):
    """
    Sends an alert to the given API endpoint about a detected pattern.

    :param endpoint_url: URL of the API endpoint.
    :param pattern_detected: The pattern that was detected.
    :param message_content: The content of the message where the pattern was detected.
    :param api_key: Optional API key for authentication.
    :return: Response from the API.
    """
    headers_default = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    

    headers = config.get('api', {}).get('headers')

    headers.update(headers_default)
    print(headers)

    logger.info("Sending alert to API.")
    
    if api_key:
        headers['Authorization'] = f'Bearer {api_key}'
    
    payload = kwargs['payload']


    try:
        response = requests.post(endpoint_url, headers=headers, json=payload)
        response.raise_for_status() 
        logger.info("Alert sent to API successfully.")
        return response.text
    except requests.exceptions.HTTPError as e:
        raise APIError(f"HTTP Error occurred while sending alert to API: {e.response.reason}")
    except requests.exceptions.RequestException as e:
        raise APIError(f"Request Error occurred while sending alert to API: {str(e)}")
