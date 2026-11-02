FROM nginx:stable-alpine@sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx-router.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY cyd.jpg    /usr/share/nginx/html/cyd.jpg
COPY poe.jpg    /usr/share/nginx/html/poe.jpg
EXPOSE 80
