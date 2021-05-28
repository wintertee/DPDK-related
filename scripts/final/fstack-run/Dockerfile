FROM ubuntu:18.04
WORKDIR /root/
COPY --from=fstack-dev:latest /root/nginx_fstack /root/nginx_fstack
COPY --from=fstack-dev:latest /usr/local/lib/x86_64-linux-gnu /usr/local/lib/x86_64-linux-gnu
COPY --from=fstack-dev:latest /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/
CMD ["bash"]