from configparser import ConfigParser

CONFIG_FILE = '/etc/django/django.conf'

try:
    with open(CONFIG_FILE, 'r') as f:
        config = ConfigParser()
        config.read(f)
        env = config.get('DEFAULT', 'ENV')
        if env == 'production':
            from .production import *
        else:
            from .development import *

except IOError:
    from .development import *