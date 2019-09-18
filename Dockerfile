FROM openjdk:8-jdk-slim AS mesos-build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      wget gnupg \
      build-essential autoconf automake libtool \
      libcurl4-openssl-dev libsasl2-dev libsasl2-modules \
      libsvn-dev zlib1g-dev iputils-ping libevent-dev \
      libapr1-dev unzip

# Install Maven
ENV MAVEN_VERSION="3.6.1"
ENV MAVEN_URL="https://www-us.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"

RUN wget ${MAVEN_URL} && \
    unzip apache-maven-${MAVEN_VERSION}-bin.zip && \
    mv apache-maven-${MAVEN_VERSION} /maven

ENV PATH=${PATH}:/maven/bin

ARG MESOS_VERSION="1.8.1"
ENV MESOS_PACKAGE="mesos-${MESOS_VERSION}.tar.gz"
ENV MESOS_PACKAGE_URL="http://archive.apache.org/dist/mesos/${MESOS_VERSION}/${MESOS_PACKAGE}"

RUN  wget ${MESOS_PACKAGE_URL} && \
     wget ${MESOS_PACKAGE_URL}.sha512 && \
     sha512sum -c ${MESOS_PACKAGE}.sha512

# Remove javadoc as there is a problem generating javadoc with JDK 11.
# To keep the resutling image small, packaging of source code is also removed.
ADD Remove_javadoc_and_sources.patch /

# For showing in the Mesos UI who built the distribution
ENV USER="mesos"

RUN  tar -xvf ${MESOS_PACKAGE} && \
     cd mesos-${MESOS_VERSION} && \
     mv /Remove_javadoc_and_sources.patch . && \
     patch -p0 < Remove_javadoc_and_sources.patch && \
     ./bootstrap && \
     mkdir build && \
     cd build && \
     ../configure \
       --enable-gc-unused \
       --disable-dependency-tracking \
       --enable-libevent \
       --enable-optimize \
       --enable-lock-free-event-queue \
       --disable-python \
       --disable-werror \
       --prefix=/opt/mesos && \
     mkdir -p /opt/mesos && \
     make -j 4 V=1 && \
     make install && \
     mkdir -p /opt/mesos/java && \
     cp src/java/target/mesos-*.jar /opt/mesos/java

###############################
#     Mesos Master Image      #
###############################
FROM openjdk:8-jre-slim
COPY --from=mesos-build /opt/mesos /opt/mesos
ENV PATH="$PATH:/opt/mesos/bin:/opt/mesos/sbin"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/mesos/lib"
ENV MESOS_NATIVE_JAVA_LIBRARY=/opt/mesos/lib/libmesos.so
RUN apt-get update && \
    apt-get install -y --no-install-recommends busybox libcurl4 libcurl4-openssl-dev libevent-dev libsvn1 libsasl2-modules && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/mesos/data && \
    ldconfig

VOLUME ["/opt/mesos/data"]
EXPOSE 5050 5051

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

