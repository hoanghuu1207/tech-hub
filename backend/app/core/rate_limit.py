from slowapi import Limiter
from slowapi.util import get_remote_address

# Định danh user limit thông qua IP Address
limiter = Limiter(key_func=get_remote_address)
