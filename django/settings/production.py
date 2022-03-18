from configparser import ConfigParser

from .base import *


DEBUG = False

# ALLOWED_HOSTS = ['itnsa.cn', 'www.itnsa.cn', '192.168.238.101']
ALLOWED_HOSTS = ['*']

with open('/etc/django/secret_key.txt', 'r') as f:
    SECRET_KEY = f.read().strip()

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'OPTIONS': {
            'read_default_file': '/etc/django/my.cnf',
        },
    }
}

config = ConfigParser()
config.read('/etc/django/django.conf')
static_root_dir = config.get('DIR', 'StaticRoot')
media_root_dir = config.get('DIR', 'MediaRoot')

STATIC_ROOT = static_root_dir
MEDIA_ROOT = media_root_dir