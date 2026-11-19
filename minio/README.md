# MinIO / mc 双架构测试打包

当前只构建、测试并上传 GitHub Actions artifacts，**不登录镜像仓库、不 push
镜像、不创建 Release、不更新 latest**。没有发布 tag 触发器，工作流仅有 `contents: read`。

`versions.json` 固定 MinIO / mc 源码提交、公开源码压缩包 SHA256、Go 1.24.8 和
Debian 基础镜像摘要。两组件来自 ob-operator 当前使用的上游版本；这里是全新的
源码构建，不依赖其内网 r2/r3 镜像或源码下载服务器。

当前候选保持 MinIO、mc 上游源码不修改，不应用之前的重加入补丁。
新增独立部署检查组件，源码和限制见 [deployment/README.md](deployment/README.md)。
CI 对照原始源码归档逐文件校验，mc 镜像额外包含部署辅助程序；两组件的中英文声明不变。

**当前候选尚未通过错误 404 验收：ARM 仍复现 9 次。** 上层探针兼容已解决，
但独立就绪检查不足以完整替代此前的 MinIO 重加入修复，暂不具备发版结论。

| 组件 | 源码版本 |
| --- | --- |
| MinIO | RELEASE.2025-10-15T17-29-55Z |
| mc | RELEASE.2025-08-13T08-35-41Z |

GitHub workflow：`.github/workflows/test-minio.yml`。
修改 `minio/` 或该 workflow 后推送测试分支即可运行，也支持手动运行。
AMD64 使用 `ubuntu-24.04`，ARM64 使用 `ubuntu-24.04-arm`，两个架构均原生编译、
原生启动测试。每个架构生成 MinIO 服务端镜像（同时包含 mc）及独立 mc 镜像。

测试检查：版本和架构、许可证与源码说明、两镜像中的 mc 一致性、非 root + 只读
根文件系统启动、Console HTTP、桶创建幂等、空/1 MiB/80 MiB 文件往返一致性、
列举/复制/删除、错误密码及匿名访问拒绝、重启/SIGKILL/重建后的数据保留。
测试使用隔离的容器网络命名空间和临时 Docker volume，退出时清理测试资源。

每个架构的 Actions artifacts（保留 7 天）：

- `minio-test-packages-<arch>`：`minio-images-<arch>.tar.gz`、源码/依赖/Go runtime
  源码/构建配方压缩包、`SHA256SUMS`。
- `minio-test-evidence-<arch>`：编译日志、镜像配置、版本信息及功能测试结果。

下载后可在相同架构的测试机器加载（请勿在开发机器启动测试服务）：

```bash
sha256sum -c SHA256SUMS
gzip -dc minio-images-amd64.tar.gz | docker load
```

镜像名为 `minio:test-<run-id>-<arch>` 和 `minio-mc:test-<run-id>-<arch>`。
这是分别可加载的两种架构测试包，尚未发布 registry 多架构 manifest。

手动构建和测试（需对应原生架构、Go 1.24.8、Docker/Buildx、jq、Python 3）：

```bash
bash minio/build.sh amd64 /tmp/minio-build-new minio:local-test minio-mc:local-test
bash minio/test.sh amd64 /tmp/minio-test-new minio:local-test minio-mc:local-test
```

构建输出目录及测试目录必须不存在。运行测试前确认当前是获准的测试环境。
构建脚本只生成本地镜像；CI 在测试通过后再导出镜像归档。

沿用上游 LICENSE、CREDITS 和依赖声明，镜像内的 `SOURCE-CODE.txt` 指向对应构建材料。
公开发版前仍需补齐正式版本命名、长期源码附件、运行时依赖源码材料和三个仓库
发布配置；本轮不启用这些发布操作。

当前无上游补丁候选的双架构对照、分布式和启停验证见
[无补丁方案验证记录](validation-no-patch-20261119.md)。
[早先的补丁版验证记录](validation-20261119.md) 仅作历史对照，不代表当前镜像。
