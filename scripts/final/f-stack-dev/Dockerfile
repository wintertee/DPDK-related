FROM fstack-env:latest
WORKDIR /root/
RUN apt-get install -y libpcre3 libpcre3-dev zlib1g-dev && \
    cd ~/f-stack-dev/app/nginx-1.16.1 && \
    ./configure --prefix=/root/nginx_fstack --with-ff_module && \
    make && \
    make install