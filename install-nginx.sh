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
      # auth_basic "Registry realm";
      # auth_basic_user_file /etc/nginx/conf.d/nginx.htpasswd;

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
      # auth_basic "Registry realm";
      # auth_basic_user_file /etc/nginx/conf.d/nginx.htpasswd;
      proxy_pass         http://127.0.0.1:8082/stop;
    }

  }
}
EOF

echo ${NGINX_CONF_MD5SUM} | md5sum -c || (echo config changed, so restarting nginx; systemctl restart nginx)
