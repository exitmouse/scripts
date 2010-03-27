#!/usr/bin/python

import os, os.path, sys
from trac.web import fcgi_frontend

env_path = os.getcwd()+'/tracdata'
os.environ['TRAC_ENV'] = env_path

def send_upgrade_message(environ, start_response):
    import pwd
    start_response('500 Internal Server Error', [])
    locker = pwd.getpwuid(os.getuid())[0]
    return ['''This Trac instance needs to be upgraded.

From an Athena machine, type
  ssh %s@scripts trac-admin %s upgrade --no-backup
  ssh %s@scripts trac-admin %s wiki upgrade
to upgrade, and then
  add scripts
  for-each-server -l %s pkill trac.fcgi
to get this message out of the way.

Please ask the scripts.mit.edu maintainers for help
if you have any trouble, at scripts@mit.edu.
''' % (locker, env_path, locker, env_path, locker)]

def setup_env():
    '''Obtain the environment, handling the needs-upgrade check, and cache it.

    This mimics open_environment in trac/env.py.'''
    import trac.env
    env = trac.env.Environment(env_path)
    needs_upgrade = False
    try:
        needs_upgrade = env.needs_upgrade()
    except Exception, e: # e.g. no database connection
        env.log.exception(e)
    if env.needs_upgrade():
        fcgi_frontend._fcgi.WSGIServer(send_upgrade_message).run()
        sys.exit(0)
    if hasattr(trac.env, 'env_cache'):
        trac.env.env_cache[env_path] = env
setup_env()

def my_dispatch_request(environ, start_response):
    if ('REDIRECT_URL' in environ and 'PATH_INFO' in environ
        and environ['REDIRECT_URL'].endswith(environ['PATH_INFO'])):
        environ['SCRIPT_NAME'] = environ['REDIRECT_URL'][:-len(environ['PATH_INFO'])]
    return fcgi_frontend.dispatch_request(environ, start_response)

fcgi_frontend._fcgi.WSGIServer(my_dispatch_request).run()
