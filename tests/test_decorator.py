from functools import wraps
from warden.stats import get_call_details
import unittest
from unittest.mock import patch
from warden.decorators import monitor_api
from warden.api import send_alert_to_api
from warden.stats import get_call_details
from warden.config import load_config
import os
from dotenv import load_dotenv
load_dotenv()

class TestMonitorApiDecorator(unittest.TestCase):

    @patch('warden.api.send_alert_to_api')
    @patch('warden.stats.get_call_details')
    @patch('warden.config.load_config')
    def test_monitor_api_success(self, mock_load_config, mock_get_call_details, mock_send_alert_to_api):
        mock_load_config.return_value = {"api": {"endpoint": os.environ.get("TEST_API_ROUTE")}}

        mock_get_call_details.return_value = {"function": "sample_function", "details": "some details"}

        @monitor_api(url = os.environ.get("TEST_API_ROUTE"))
        def sample_function(x):
            return x * 2

        result = sample_function(5)

        self.assertEqual(result, 10)
        # mock_send_alert_to_api.assert_called_once()

        expected_payload = {
            "source": mock_get_call_details.return_value,
            "type": "decorator",
            "status": "success"
        }

        print(os.environ.get("TEST_API_ROUTE"))

        mock_send_alert_to_api.assert_called_once_with(os.environ.get("TEST_API_ROUTE"), payload=expected_payload)

    @patch('warden.api.send_alert_to_api')
    @patch('warden.stats.get_call_details')
    @patch('warden.config.load_config')
    def test_monitor_api_exception(self, mock_load_config, mock_get_call_details, mock_send_alert_to_api):
        mock_load_config.return_value = {"api": {"endpoint": os.environ.get("TEST_API_ROUTE")}}

        mock_get_call_details.return_value = {"function": "sample_function", "details": "some details"}

        @monitor_api()
        def sample_function(x):
            raise ValueError("An error occurred")

        with self.assertRaises(ValueError):
            sample_function(5)

        # mock_send_alert_to_api.assert_called_once()

        expected_payload = {
            "source": mock_get_call_details.return_value,
            "type": "decorator",
            "status": "failed",
            "error:": "An error occurred"
        }

        mock_send_alert_to_api.assert_called_with(os.environ.get("TEST_API_ROUTE"), payload=expected_payload)
