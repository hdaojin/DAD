from configparser import ConfigParser
import os

from .base import *


# SECURITY
# DON'T CHANGE THE FILE PATH OF "secret_key.conf".
with open('/etc/django/secret_key.conf', 'r') as f:
    SECRET_KEY = f.read().strip()

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

# ALLOWED_HOSTS = ['itnsa.cn', '192.168.238.101', 'localhost']
ALLOWED_HOSTS = ['*']

# Database
# https://docs.djangoproject.com/en/3.2/ref/settings/#databases
# DON'T CHANGE THESE SETTINGS. --->START

config = ConfigParser()
config.read('/etc/django/db.conf')
engine = config.get('db', 'ENGINE')
name = config.get('db', 'NAME')
user = config.get('db', 'USER')
password = config.get('db', 'PASSWORD')
host = config.get('db', 'HOST')

DATABASES = {
    'default': {
        'ENGINE': engine,
        'NAME': name,
        'USER': user,
        'PASSWORD': password,
        'HOST': host,
    }
}

# Static files (CSS, JavaScript, Images)

MY_BASE_DIR = os.environ.get('STATIC_FILES_BASE_DIR', '/var/www/mysite')

STATIC_ROOT = MY_BASE_DIR / 'static'

MEDIA_ROOT = MY_BASE_DIR / 'media'

# DON'T CHANGE THESE SETTINGS. END<---