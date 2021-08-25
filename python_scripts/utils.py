import os


class EnvironmentExtractor:
    """Recovers any environment variables.
    Once called, self.XXX stores the environment variable XXX value,
    for faster subsequent calls"""

    def __getattr__(self, name):
        """Will only be called the first time self.XXX is called"""
        env_var = os.getenv(name)
        if not env_var:
            raise ValueError(f"No value found for environment variable {name}")
        setattr(self, name, env_var)
        return env_var


env = EnvironmentExtractor()
