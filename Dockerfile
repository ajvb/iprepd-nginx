FROM openresty/openresty:1.19.3.1-centos AS base

# Update + Add nginx user
RUN dnf --nodocs -y upgrade-minimal &&\
	groupadd nginx && useradd -g nginx --shell /bin/false nginx

# Install iprepd-nginx from the local branch in the image, and our vendored Lua
# dependencies
COPY lib/resty/*.lua vendor/resty/ \
	/usr/local/openresty/site/lualib/resty/

# Copy base OpenResty configuration
COPY etc/conf.d /usr/local/openresty/nginx/conf/conf.d
COPY etc/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Create image for integration tests
FROM base AS integration-test

# Install utils for testing
# disable updates for openresty to ensure we test against
# same version as we use for production
RUN dnf install -y python3  && \
	pip3 install pytest requests && \
	mkdir -p /opt/iprepd-nginx/{etc,test} && \
	mkdir -p /opt/iprepd-nginx/etc/testconf && \
	cp -Rp /usr/local/openresty/nginx/conf /opt/iprepd-nginx/etc/testconf/rl &&\
	cp -Rp /usr/local/openresty/nginx/conf /opt/iprepd-nginx/etc/testconf/whitelist_only &&\
	cp -Rp /usr/local/openresty/nginx/conf /opt/iprepd-nginx/etc/testconf/both_lists

COPY test/configs/integration/etc/conf.d /usr/local/openresty/nginx/conf/conf.d
COPY test/configs/integration/etc/nginx.conf /usr/local/openresty/nginx/conf/
COPY test/configs/integration/etc/iprepd-nginx-ping.txt /opt/iprepd-nginx/etc/iprepd-nginx-ping.txt

# Copy additional configs used as part of integration testing
COPY test/configs/integration/etc/testconf /opt/iprepd-nginx/etc/testconf

COPY test/integration_test.py /opt/iprepd-nginx/test/
WORKDIR /opt/iprepd-nginx/test
ENTRYPOINT ["pytest", "-s", "--log-cli-level=INFO"]

# Create production image
FROM base as production

WORKDIR /
EXPOSE 80
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/openresty", "-g", "daemon off;"]