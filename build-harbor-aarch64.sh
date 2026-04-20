#!/bin/bash

# 设置构建参数
VERSIONTAG=arm64-dev
BASEIMAGETAG=arm64-dev
DEVFLAG=true
GOBUILDIMAGE=golang:1.24.11

# 设置Docker Buildx参数
export DOCKER_BUILDKIT=1

# 编译Harbor组件（使用ARM64编译）
echo "=== 编译Harbor组件 ==="
# 使用Docker Buildx编译ARM64架构的二进制文件
# 编译core组件
docker buildx build --platform linux/arm64 --rm -o make/photon/core/ -f - << EOF
FROM --platform=linux/arm64 $GOBUILDIMAGE
WORKDIR /harbor/src/core
COPY src/ /harbor/src/
RUN go build -buildvcs=false -tags "" --ldflags "-w -s -X github.com/goharbor/harbor/src/pkg/version.GitCommit=dev -X github.com/goharbor/harbor/src/pkg/version.ReleaseVersion=2.14.2" -o /harbor/make/photon/core/harbor_core
EOF

# 编译jobservice组件
docker buildx build --platform linux/arm64 --rm -o make/photon/jobservice/ -f - << EOF
FROM --platform=linux/arm64 $GOBUILDIMAGE
WORKDIR /harbor/src/jobservice
COPY src/ /harbor/src/
RUN go build -buildvcs=false -tags "" --ldflags "-w -s" -o /harbor/make/photon/jobservice/harbor_jobservice
EOF

# 编译registryctl组件
docker buildx build --platform linux/arm64 --rm -o make/photon/registryctl/ -f - << EOF
FROM --platform=linux/arm64 $GOBUILDIMAGE
WORKDIR /harbor/src/registryctl
COPY src/ /harbor/src/
RUN go build -buildvcs=false -tags "" --ldflags "-w -s" -o /harbor/make/photon/registryctl/harbor_registryctl
EOF

# 构建基础镜像
echo "=== 构建基础镜像 ==="
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-core-base:$BASEIMAGETAG -f make/photon/core/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-jobservice-base:$BASEIMAGETAG -f make/photon/jobservice/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-portal-base:$BASEIMAGETAG -f make/photon/portal/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-db-base:$BASEIMAGETAG -f make/photon/db/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-log-base:$BASEIMAGETAG -f make/photon/log/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-nginx-base:$BASEIMAGETAG -f make/photon/nginx/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-redis-base:$BASEIMAGETAG -f make/photon/redis/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-registry-base:$BASEIMAGETAG -f make/photon/registry/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-registryctl-base:$BASEIMAGETAG -f make/photon/registryctl/Dockerfile.base .
docker buildx build --platform linux/arm64 --load --tag goharbor/harbor-prepare-base:$BASEIMAGETAG -f make/photon/prepare/Dockerfile.base .

# 使用Buildx构建ARM64镜像
echo "=== 构建ARM64镜像 ==="
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-core:$VERSIONTAG -f make/photon/core/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-jobservice:$VERSIONTAG -f make/photon/jobservice/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-portal:$VERSIONTAG -f make/photon/portal/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-db:$VERSIONTAG -f make/photon/db/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-log:$VERSIONTAG -f make/photon/log/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/nginx-photon:$VERSIONTAG -f make/photon/nginx/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/redis-photon:$VERSIONTAG -f make/photon/redis/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/registry-photon:$VERSIONTAG -f make/photon/registry/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/harbor-registryctl:$VERSIONTAG -f make/photon/registryctl/Dockerfile .
docker buildx build --platform linux/arm64 --load --build-arg harbor_base_image_version=$BASEIMAGETAG --build-arg harbor_base_namespace=goharbor --tag goharbor/prepare:$VERSIONTAG -f make/photon/prepare/Dockerfile .

# 构建离线安装包
echo "=== 构建离线安装包 ==="
# 注意：需要先将构建的ARM64镜像保存到本地
mkdir -p harbor
docker save goharbor/harbor-core:$VERSIONTAG goharbor/harbor-jobservice:$VERSIONTAG goharbor/harbor-portal:$VERSIONTAG goharbor/harbor-db:$VERSIONTAG goharbor/harbor-log:$VERSIONTAG goharbor/nginx-photon:$VERSIONTAG goharbor/redis-photon:$VERSIONTAG goharbor/registry-photon:$VERSIONTAG goharbor/harbor-registryctl:$VERSIONTAG goharbor/prepare:$VERSIONTAG > harbor/harbor.$VERSIONTAG.tar
gzip harbor/harbor.$VERSIONTAG.tar

# 复制必要文件
cp -r make harbor/
cp LICENSE harbor/
cp make/prepare harbor/
cp make/install.sh harbor/
cp make/common.sh harbor/
cp make/harbor.yml.tmpl harbor/

# 创建离线安装包
tar -zcvf harbor-offline-installer-$VERSIONTAG.tgz harbor/
rm -rf harbor/

echo "=== 构建完成 ==="