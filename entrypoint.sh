#!/bin/sh
# Source env file created at build-time (if present)
if [ -f /etc/profile.d/icenv.sh ]; then
  . /etc/profile.d/icenv.sh
fi

# Ensure defaults if not set
: ${ODOO_URL:="https://www.odoo.com"}
: ${PGADMIN_URL:="https://www.pgadmin.org"}
export ODOO_URL PGADMIN_URL VERSION

# Start the Flask app
exec python app.py
