import yaml

DEFAULT_CONFIG_PATH = "config.yaml"

class InvalidConfigurationError(Exception):
    pass

def load_config(config_path=DEFAULT_CONFIG_PATH):
    """
    Load the configuration from a YAML file.
    """
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

def edit_config(config, key, value, config_path=DEFAULT_CONFIG_PATH):
    """
    Edit a specific configuration item and save it back to the file.
    """
    config[key] = value
    save_config(config, config_path)

def save_config(config, config_path=DEFAULT_CONFIG_PATH):
    """
    Save the configuration back to the YAML file.
    """
    with open(config_path, 'w') as file:
        yaml.dump(config, file, default_flow_style=False)
