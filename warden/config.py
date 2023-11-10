import yaml
import os


DEFAULT_CONFIG = {
    "logfile": "default.log",
    "patterns": [],
    "api": {
        "endpoint": ""
    }
}

home_dir = os.path.expanduser('~')
config_dir = os.path.join(home_dir, '.api-warden')
config_path = os.path.join(config_dir, 'config.yaml')

class InvalidConfigurationError(Exception):
    pass

def ensure_config_directory():
    if not os.path.exists(config_dir):
        os.makedirs(config_dir)

def load_config():
    ensure_config_directory()
    if not os.path.isfile(config_path):
        return DEFAULT_CONFIG
    with open(config_path, 'r') as file:
        config = yaml.safe_load(file)
    validate_config(config)
    return config
def validate_config(config):
    """
    Validate the loaded configuration.
    Throws InvalidConfigurationError if the config is invalid.
    """
    required_keys = ["logfile", "patterns", "api"]
    for key in required_keys:
        if key not in config:
            raise InvalidConfigurationError(f"Missing key in config: {key}")

    # You can add more specific validation for each configuration item if needed

def edit_config(config, key, value):
    config[key] = value
    save_config(config)

def save_config(config):
    ensure_config_directory()
    with open(config_path, 'w') as file:
        yaml.dump(config, file, default_flow_style=False)