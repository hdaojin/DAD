from configparser import ConfigParser

CONFIG_FILE = '/etc/django/django.conf'

try:
    with open(CONFIG_FILE, 'r') as f:
        conf = f.read()
        config = ConfigParser()
        config.read_string(conf)
        env = config.get('DEFAULT', 'Env')
        if env == 'production':
            from .production import *
        else:
            from .development import *

except IOError:
    from .development import *