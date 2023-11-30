import pytest
from unittest.mock import patch, Mock
from warden.bpm_monitor import BPMWatcher  

def test_start():

    path = "."
    interval = 10
    num_of_checks = 3
    watcher = BPMWatcher(path, interval, num_of_checks)

    # Mocks
    mock_callback = Mock()
    mock_time = Mock(side_effect=[0, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
    mock_isdir = Mock(return_value=False)
    mock_getmtime = Mock(side_effect=[100, 100, 100, 200, 200, 200, 300, 300, 300])
    mock_listdir = Mock(return_value=[])

    with patch('time.time', mock_time):
        with patch('os.path.isdir', mock_isdir):
            with patch('os.path.getmtime', mock_getmtime):
                with patch('os.listdir', mock_listdir):
                    # Act and Assert
                    try:
                        watcher.start(mock_callback, "http://example.com")
                    except StopIteration:
                        pass

                    # Assert
                    assert mock_callback.call_count == num_of_checks
