FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html
# The server config is not part of the website
RUN rm /usr/share/nginx/html/nginx.conf

EXPOSE 80
