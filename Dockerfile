FROM alpine:3.4
MAINTAINER Kirill Sevryugin <kirill@sevryugin.ru>

ENV OPENRESTY_VERSION 1.9.15.1
ENV LUAROCKS_VERSION 2.3.0
ENV LUA_AUTO_SSL_VERSION 0.8.6-1
ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV VAR_PREFIX /var/nginx

RUN echo "--- Installing dependencies ---" \
  && apk update \
  && apk add --virtual build-deps \
     make gcc musl-dev \
     pcre-dev openssl openssl-dev zlib-dev ncurses-dev readline-dev \
     curl perl \
  && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
  && mkdir -p /root/ngx_openresty \
  && cd /root/ngx_openresty \
  && echo "--- Downloading OpenResty ---" \
  && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xz \
  && cd openresty-* \
  && echo "--- Configuring OpenResty ---" \
  && ./configure \
     --prefix=${OPENRESTY_PREFIX} \
     --http-client-body-temp-path=${VAR_PREFIX}/client_body_temp \
     --http-proxy-temp-path=${VAR_PREFIX}/proxy_temp \
     --http-log-path=${VAR_PREFIX}/access.log \
     --error-log-path=${VAR_PREFIX}/error.log \
     --pid-path=${VAR_PREFIX}/nginx.pid \
     --lock-path=${VAR_PREFIX}/nginx.lock \
     --with-http_gzip_static_module \
     --with-http_ssl_module \
     --with-http_v2_module \
     --with-luajit \
     --with-pcre-jit \
     --with-ipv6 \
     -j${NPROC} \
  && echo "--- Building OpenResty ---" \
  && make -j${NPROC} \
  && echo "--- Installing OpenResty ---" \
  && make install \
  && ln -sf ${NGINX_PREFIX}/sbin/nginx /usr/local/bin/nginx \
  && ln -sf ${NGINX_PREFIX}/sbin/nginx /usr/local/bin/openresty \
  && ln -sf ${OPENRESTY_PREFIX}/bin/resty /usr/local/bin/resty \
  && ln -sf ${OPENRESTY_PREFIX}/luajit/bin/luajit-* ${OPENRESTY_PREFIX}/luajit/bin/lua \
  && ln -sf ${OPENRESTY_PREFIX}/luajit/bin/luajit-* /usr/local/bin/lua \
  && echo "--- Downloading LuaRocks ---" \
  && curl -sSL http://keplerproject.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar -xz \
  && cd luarocks-* \
  && echo "--- Configuring LuaRocks ---" \
  && ./configure \
     --prefix=${OPENRESTY_PREFIX}/luajit \
     --with-lua=${OPENRESTY_PREFIX}/luajit \
     --with-lua-include=${OPENRESTY_PREFIX}/luajit/include/luajit-2.1 \
     --lua-suffix=jit-2.1.0-beta2 \
  && echo "--- Building LuaRocks ---" \
  && make -j${NPROC} \
  && echo "--- Installing LuaRocks ---" \
  && make install \
  && ln -sf ${OPENRESTY_PREFIX}/luajit/bin/luarocks /usr/local/bin/luarocks \
  && echo "--- Installing lua-resty-auto-ssl module ---" \
  && luarocks install lua-resty-auto-ssl ${LUA_AUTO_SSL_VERSION} \
  && echo "--- Configuring lua-resty-auto-ssl ---" \
  && mkdir -p /etc/resty-auto-ssl \
  && openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
     -subj '/CN=sni-support-required-for-valid-ssl' \
     -keyout /etc/ssl/resty-auto-ssl-fallback.key \
     -out /etc/ssl/resty-auto-ssl-fallback.crt \
  && echo "--- Cleanup ---" \
  && apk del build-deps \
  && echo "--- Installing required packages ---" \
  && apk add \
     bash curl libpcrecpp libpcre16 libpcre32 openssl libssl1.0 pcre libgcc libstdc++ \
  && rm -rf /var/cache/apk/* \
  && rm -rf /root/ngx_openresty

WORKDIR ${NGINX_PREFIX}/

RUN rm -rf conf/*
COPY nginx ${NGINX_PREFIX}/

CMD ["nginx", "-g", "daemon off; error_log /dev/stderr info;"]
