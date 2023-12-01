#!/bin/bash

if [ $(id -u) -ne 0 ]; then
    echo "Should be run as root"
    exit $?
fi

DOMAIN_NAME=${EXTERNAL_NAME:-$(hostname -f)}
echo ${DOMAIN_NAME}

if ! nginx -v 2>/dev/null; then
  apt-get update
  apt-get install -y nginx
fi

systemctl enable nginx

NGINX_CONF_MD5SUM="$(md5sum /etc/nginx/nginx.conf)"
NGINX_HTML_DIR="/usr/share/nginx/html"
NGINX_HTML_FILE="${NGINX_HTML_DIR}/502.html"

# Create or update the 502.html file
cat << EOF > ${NGINX_HTML_FILE}
<!DOCTYPE html>
<html>
<head>
  <title>PlayPit Labs shutting down</title>
</head>
<body style="text-align: center;">
    <div>
        <h4 style="color: lightgray; padding: 0.6em; position: relative; text-align: center;">Wait while PlayPit Labs Login Page Loading...</h4>
    </div>
</body>
</html>
EOF

# Update the Nginx configuration
cat << EOF > /etc/nginx/nginx.conf
events {
  worker_connections 1024;
}

http {
  map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
  }

  upstream backend {
    server 127.0.0.1:8081;
  }

  server {
    listen      80 default_server;
    server_name _;
    return      444;
  }

  server {
    server_name ${DOMAIN_NAME};
    listen 80;
    chunked_transfer_encoding on;

    location / {
      proxy_http_version 1.1;
      proxy_set_header   Upgrade \$http_upgrade;
      proxy_set_header   Connection \$connection_upgrade;

      proxy_set_header   Host              \$http_host;
      proxy_set_header   X-Real-IP         \$remote_addr;
      proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto \$scheme;
      proxy_read_timeout 9000;

      proxy_pass         http://backend;
    }

    location ^~ /restart {
      proxy_pass         http://127.0.0.1:8082/stop;
    }

    error_page 502 /502.html;  # Use custom 502.html page
    location = /502.html {
        root ${NGINX_HTML_DIR};  # Adjust the path based on your setup
        internal;
    }
  }
}
EOF

# Check if the configuration has changed, and restart Nginx if necessary
echo ${NGINX_CONF_MD5SUM} | md5sum -c || (echo "Config changed, restarting Nginx"; systemctl restart nginx)

if [ "$SSL" == "yes" ]; then
  echo "Letsencrypt job"
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
  snap set certbot trust-plugin-with-root=ok
  if [ ! -f /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem ]; then
    certbot --nginx --register-unsafely-without-email --agree-tos -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME}
  fi
fi
