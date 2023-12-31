import requests

# Error class to handle API specific issues
class APIError(Exception):
    pass

def send_alert_to_api(endpoint_url, pattern_detected, message_content, api_key=None):
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
    
    if api_key:
        headers['Authorization'] = f'Bearer {api_key}'
    
    payload = {
        'pattern': pattern_detected,
        'message': message_content
    }

    try:
        response = requests.post(endpoint_url, headers=headers, json=payload)
        response.raise_for_status()  # Raises a HTTPError if the HTTP request returned an unsuccessful status code

    except requests.RequestException as e:
        raise APIError(f"Error occurred while sending alert to API: {str(e)}")

    return response.json()
