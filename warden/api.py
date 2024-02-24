import json
from urllib import request, error
from warden.logger import logger

# Error class to handle API specific issues
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
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    logger.info("Sending alert to API.")
    
    if api_key:
        headers['Authorization'] = f'Bearer {api_key}'
    
    payload = kwargs['payload']
    data = json.dumps(payload).encode('utf-8')  # Convert payload to JSON and then to bytes

    req = request.Request(endpoint_url, data=data, headers=headers, method='POST')
    try:
        with request.urlopen(req) as response:
            response_body = response.read().decode('utf-8')
            print(response_body)
            return response_body
    except error.HTTPError as e:
        raise APIError(f"HTTP Error occurred while sending alert to API: {e.reason}")
    except error.URLError as e:
        raise APIError(f"URL Error occurred while sending alert to API: {e.reason}")
