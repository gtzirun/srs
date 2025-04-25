# 使用阿里云的 Ubuntu 20.04 基础镜像
ARG ARCH
ARG IMAGE=registry.cn-hangzhou.aliyuncs.com/aliyun-ubuntu/ubuntu:20.04
FROM ${ARCH}${IMAGE} AS build

ARG CONFARGS
ARG MAKEARGS
ARG INSTALLDEPENDS
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG SRS_AUTO_PACKAGER
RUN echo "BUILDPLATFORM: $BUILDPLATFORM, TARGETPLATFORM: $TARGETPLATFORM, PACKAGER: ${#SRS_AUTO_PACKAGER}, CONFARGS: ${CONFARGS}, MAKEARGS: ${MAKEARGS}, INSTALLDEPENDS: ${INSTALLDEPENDS}"

# 设置非交互式安装，优化 tzdata 安装
ENV DEBIAN_FRONTEND=noninteractive

# 使用阿里云的软件源加速 apt
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# 设置 bash 作为默认 shell
SHELL ["/bin/bash", "-c"]

# 安装依赖工具
RUN if [[ $INSTALLDEPENDS != 'NO' ]]; then \
        apt-get update && apt-get install -y gcc make g++ patch unzip perl git libasan5; \
    fi

# 复制源代码到容器
COPY . /srs
WORKDIR /srs/trunk

# 构建并安装 SRS
RUN ./configure ${CONFARGS} && make ${MAKEARGS} && make install

############################################################
# dist
############################################################
FROM ${ARCH}registry.cn-hangzhou.aliyuncs.com/aliyun-ubuntu/ubuntu:focal AS dist

ARG BUILDPLATFORM
ARG TARGETPLATFORM
RUN echo "BUILDPLATFORM: $BUILDPLATFORM, TARGETPLATFORM: $TARGETPLATFORM"

# 暴露 SRS 流媒体相关端口
EXPOSE 1935 1985 8080 5060 9000 8000/udp 10080/udp

# 复制 FFMPEG 和 SRS 相关文件
COPY --from=build /usr/local/bin/ffmpeg /usr/local/srs/objs/ffmpeg/bin/ffmpeg
COPY --from=build /usr/local/srs /usr/local/srs

# 测试二进制版本
RUN ldd /usr/local/srs/objs/ffmpeg/bin/ffmpeg && \
    /usr/local/srs/objs/ffmpeg/bin/ffmpeg -version && \
    ldd /usr/local/srs/objs/srs && \
    /usr/local/srs/objs/srs -v

# 设置工作目录和默认命令
WORKDIR /usr/local/srs
ENV SRS_DAEMON=off SRS_IN_DOCKER=on
CMD ["./objs/srs", "-c", "conf/docker.conf"]
