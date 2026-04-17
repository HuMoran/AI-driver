# Deploy Document: <project-name>

## Build

### Dependencies
- OS:
- Runtime/SDK:
- Toolchain:
- Special hardware/platform:

### Build Steps
```bash
# Write step-by-step, AI will execute in order
```

### Build Artifacts
- Artifact path:
- Artifact type: (binary/container image/package/firmware/...)

### Credentials
- Required secrets: (list env vars or secret names)
- How to obtain:
- Storage method: (.env / vault / CI secrets)

---

## Dev

### Start Command
```bash
```

### Debug Config
- Debug port:
- Hot reload:
- Environment variables:

### Local Dependencies
- Database:
- Message queue:
- Other services:

---

## Staging

### Deploy Target
- Address/platform:
- Access method:

### Deploy Command
```bash
```

### Smoke Test
```bash
# Verify service is healthy after deploy
```

### Test Data
- Data source:
- Init command:

---

## Production

### Deploy Target
- Address/platform:
- Access method:

### Deploy Command
```bash
```

### Health Check
```bash
# Post-deploy verification, exit code 0 = healthy
```

### Rollback
```bash
# Rollback command if deploy fails
```

---

## Special Platforms [fill as needed]

### Cross-Compilation
- Target platform:
- Toolchain:
- Build command:
```bash
```

### Firmware Flashing
- Device model:
- Flash tool:
- Flash command:
```bash
```

### Mobile Packaging
- Android:
```bash
```
- iOS:
```bash
```

### Containerization
- Dockerfile path:
- Build command:
```bash
```
- Push command:
```bash
```

---

## Notes
- [Special considerations, known issues, permission requirements, etc.]
