import requests
from warden.stats import get_call_details
from warden.logger import logger

# Error class to handle API specific issues
class APIError(Exception):
    pass

def send_alert_to_api(endpoint_url, pattern_detected=None, message_content = None, api_key=None, *args, **kwargs):
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
    



    try:
        response = requests.post(endpoint_url, headers=headers, json=payload)
        response.raise_for_status() 
        print(response) # Raises a HTTPError if the HTTP request returned an unsuccessful status code
        return response

    except requests.RequestException as e:
        raise APIError(f"Error occurred while sending alert to API: {str(e)}")

