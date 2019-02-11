FROM ubuntu:bionic
RUN echo 'deb http://archive.canonical.com/ubuntu bionic partner' >> /etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y cmake valac libgee-0.8-dev libpoppler-glib-dev libgtk-3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-gtk3
COPY ./ ./
RUN rm -rf /usr/local/* && \
  mkdir build && cd build/ && \
  cmake .. && \
  make && \
  make install
ENV TAR=/pdfpc.tar.gz
RUN cd / && tar -czf $TAR usr/local/* && \
   tar --list -f $TAR && \
  echo "install via: tar -xzf $TAR"


### create local tar.gz file
# docker build . -t local/pdfpc && docker run -it -u $(id -u) -v $(pwd):/mnt local/pdfpc cp /pdfpc.tar.gz /mnt/app/pdfpc.tar.gz

### extract on /
# sudo tar -xzf app/pdfpc.tar.gz -C /
