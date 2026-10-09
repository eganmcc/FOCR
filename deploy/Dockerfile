# FOCR web: static Flutter web app served by nginx.
# Build from the root of the extracted release package (the folder containing public/ and nginx/):
#   docker build -t focr-web:<version> .
#   docker run -d -p 8080:80 --name focr-web focr-web:<version>
FROM nginx:1.27-alpine

COPY nginx/focr.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1/version.json || exit 1
