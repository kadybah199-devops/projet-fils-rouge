FROM python:3.6-alpine

# working dir
WORKDIR /opt

# copy releases file early so build can parse it
COPY releases.txt /tmp/releases.txt

# parse releases.txt and write env exports to an env file
RUN ODOO_URL="$(awk 'NR==1{print $2}' /tmp/releases.txt)" \
    && PGADMIN_URL="$(awk 'NR==2{print $2}' /tmp/releases.txt)" \
    && VERSION="$(awk 'NR==3{print $2}' /tmp/releases.txt)" \
    && echo "export ODOO_URL=$ODOO_URL" > /etc/profile.d/icenv.sh \
    && echo "export PGADMIN_URL=$PGADMIN_URL" >> /etc/profile.d/icenv.sh \
    && echo "export VERSION=$VERSION" >> /etc/profile.d/icenv.sh

# install runtime deps
RUN pip install --no-cache-dir flask

# copy app sources
COPY . /opt

# make entrypoint executable
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 8080

# default envs (can be overridden at container run)
ENV ODOO_URL=https://www.odoo.com
ENV PGADMIN_URL=https://www.pgadmin.org

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["python", "app.py"]
