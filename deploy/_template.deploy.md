# Deploy Document / 部署文档: <project-name>

## Build / 编译构建

### Dependencies / 依赖环境
- OS / 操作系统:
- Runtime/SDK / 运行时:
- Toolchain / 工具链:
- Special hardware/platform / 特殊硬件/平台:

### Build Steps / 构建步骤
```bash
# Write step-by-step, AI will execute in order
# 逐步写清楚，AI 会按顺序执行
```

### Build Artifacts / 构建产物
- Artifact path / 产物路径:
- Artifact type / 产物类型: (binary/container image/package/firmware/...)

### Credentials / 密钥凭证
- Required secrets / 必需的密钥: (list env vars or secret names)
- How to obtain / 获取方式:
- Storage method / 存储方式: (.env / vault / CI secrets)

---

## Dev / 开发环境

### Start Command / 启动命令
```bash
```

### Debug Config / 调试配置
- Debug port / 调试端口:
- Hot reload / 热重载:
- Environment variables / 环境变量:

### Local Dependencies / 本地依赖
- Database / 数据库:
- Message queue / 消息队列:
- Other services / 其他服务:

---

## Staging / 测试环境

### Deploy Target / 部署目标
- Address/platform / 地址/平台:
- Access method / 访问方式:

### Deploy Command / 部署命令
```bash
```

### Smoke Test / 冒烟测试
```bash
# Verify service is healthy after deploy
# 部署后验证服务是否正常
```

### Test Data / 测试数据
- Data source / 数据来源:
- Init command / 初始化命令:

---

## Production / 生产环境

### Deploy Target / 部署目标
- Address/platform / 地址/平台:
- Access method / 访问方式:

### Deploy Command / 部署命令
```bash
```

### Health Check / 健康检查
```bash
# Post-deploy verification, exit code 0 = healthy
# 部署后验证命令，退出码 0 = 健康
```

### Rollback / 回滚方案
```bash
# Rollback command if deploy fails
# 部署失败时的回滚命令
```

---

## Special Platforms / 特殊平台 [fill as needed / 按需填写]

### Cross-Compilation / 交叉编译
- Target platform / 目标平台:
- Toolchain / 工具链:
- Build command / 编译命令:
```bash
```

### Firmware Flashing / 固件烧录
- Device model / 设备型号:
- Flash tool / 烧录工具:
- Flash command / 烧录命令:
```bash
```

### Mobile Packaging / 移动端打包
- Android:
```bash
```
- iOS:
```bash
```

### Containerization / 容器化
- Dockerfile path / Dockerfile 路径:
- Build command / 构建命令:
```bash
```
- Push command / 推送命令:
```bash
```

---

## Notes / 注意事项
- [Special considerations, known issues, permission requirements, etc.]
- [部署相关的特殊注意事项、已知问题、权限要求等]
