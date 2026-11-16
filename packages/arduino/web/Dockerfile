FROM nginx:stable-alpine@sha256:0e52bd054126cdc040b1276c0af347aeb02a41b9cfe305d6094767ac30e97949
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx-router.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY cyd.jpg    /usr/share/nginx/html/cyd.jpg
COPY poe.jpg    /usr/share/nginx/html/poe.jpg
EXPOSE 80
