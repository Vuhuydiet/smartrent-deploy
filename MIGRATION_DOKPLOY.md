# SmartRent — Migration sang VM mới + Dokploy

> Runbook chuyển hạ tầng từ DO Droplet cũ (hết credit) sang VM mới trên account DO
> mới, quản lý bằng **Dokploy**. Cập nhật trạng thái `[x]` khi xong từng việc.

## Bối cảnh & quyết định
- **Lý do:** account DO cũ hết credit; droplet + managed MySQL cũ sẽ bị khoá.
- **Tool mới:** [Dokploy](https://dokploy.com) — PaaS self-host (Traefik + SSL tự động,
  env UI, deploy-from-registry, auto-deploy webhook). Thay cho: Caddy, `deploy.sh`,
  SSH-action CD, cơ chế bump `tags.env`.
- **DB:** migrate (managed cũ nằm trên account hết credit).
- **Domain:** đổi sang domain MỚI → phải cập nhật nhiều nơi (xem §Domain).
- **Scraper:** hoãn (đang chạy Helm/values.yaml, không nằm trong compose droplet).
- **FE:** vẫn trên Vercel (không đưa vào VM).

## Kiến trúc đích
```
Internet → (DNS domain mới) → Dokploy Traefik (80/443, SSL Let's Encrypt) trên VM mới
   ├── api.<domain>  → app "backend" (image vuhuydiet/smartrent-backend)
   └── ai.<domain>   → app "ai"      (image vuhuydiet/smartrent-ai)
backend/ai → MySQL mới (managed DO account mới HOẶC self-host Dokploy)
backend    → Redis (service trong Dokploy)
FE (Vercel) → gọi api.<domain> / ai.<domain>
CI (GitHub Actions): lint/test/build → push image DockerHub → gọi Dokploy webhook
CD (Dokploy): pull image mới → redeploy (log/health trong UI)
```

---

## Phase 1 — VM + Dokploy  ✅
- [x] Tạo Droplet account mới (Ubuntu 24.04, SGP1, 2vCPU/4GB/120GB, SSH key).
- [x] Cài Dokploy: `curl -sSL https://dokploy.com/install.sh | sh` (tự cài Docker + Swarm + Traefik).
- [x] Tạo admin tại `http://<IP>:3000`.
- [ ] (Phase 4) Gắn domain panel + SSL: `deploy.<domain>` → Settings → Domains.
- [ ] Settings → Git → GitHub App; Settings → API → tạo token (lưu cho CI).

> `dokploy-redis` + `dokploy-postgres` là datastore NỘI BỘ của Dokploy — không phải DB app.
> ⚠️ VM 4GB: đặt **memory limit** cho app `backend` (1.5–2GB) ở Phase 3 để JVM không OOM cả máy.

## Phase 2 — Database
- [ ] **Backup file (gấp):** `mysqldump` DB cũ ra `.sql`, tải về local + cloud (phao an toàn).
- [ ] Tạo MySQL mới: **Cách A** managed DO account mới (khuyến nghị, đỡ RAM droplet 4GB) /
      **Cách B** self-host MySQL trong Dokploy (rẻ, tự backup).
- [ ] Đưa data: Cách A dùng cluster mới → **"Set up migration"** (source = cluster cũ; tạm mở
      Trusted Sources cluster cũ). Fallback: restore từ file dump.
- [ ] Verify: số bảng khớp + có `flyway_schema_history` + data mẫu.
- [ ] Whitelist IP VM Dokploy vào Trusted Sources của DB mới.
- [ ] Ghi lại connection details DB mới (cho Phase 3).

## Phase 3 — Apps trong Dokploy
- [ ] App `backend`: source = image `vuhuydiet/smartrent-backend:<tag>`; set memory limit; env (xem §Env).
- [ ] App `ai`: image `vuhuydiet/smartrent-ai:<tag>`; env.
- [ ] Redis: tạo service Redis trong Dokploy → `REDIS_HOST` trỏ vào đó.
- [ ] Gắn domain + SSL: `api.<domain>` → backend:8080, `ai.<domain>` → ai:8000.
- [ ] **Rate-limit (Traefik middleware)** thay Caddyfile cũ:
      `/v1/listings/search` 30/min · `/v1/*` 120/min · `/api/v1/verify-listing` 10/min (bảo vệ quota Vertex).

## Phase 4 — Domain mới (DNS + cập nhật mọi nơi)
- [ ] DNS A record: `api.<domain>` + `ai.<domain>` (+ `deploy.<domain>`) → IP VM mới.
- [ ] Backend env: `API_DOMAIN`, `CORS_ALLOWED_ORIGINS`, `CLIENT_URL`, `ADMIN_URL`.
- [ ] FE (Vercel) env: `NEXT_PUBLIC_URL_API_BASE`, `NEXT_PUBLIC_URL_API_AI`, `NEXT_PUBLIC_SITE_URL`,
      `NEXT_PUBLIC_GOOGLE_REDIRECT_URI`.
- [ ] Google Cloud Console: Authorized redirect URIs + JS origins → domain mới; `GOOGLE_AUTH_CLIENT_REDIRECT_URI`.
- [ ] VNPay: `VNPAY_RETURN_URL`. ZaloPay: `ZALOPAY_RETURN_URL` (+ IPN trong dashboard).
- [ ] R2: CORS allowed origins (nếu giới hạn theo domain).

## Phase 5 — CI/CD restructure (tách CI ↔ CD)
- [ ] Mỗi repo: giữ CI (lint/test trên PR; build+push image trên push main/dev) — **bỏ** job deploy SSH + bump `tags.env`.
- [ ] Thêm step gọi **Dokploy redeploy webhook** (sau khi push image).
- [ ] GitHub secrets: ❌ xoá `DROPLET_HOST/USER/SSH_KEY`, `DEPLOY_REPO_TOKEN`;
      ➕ thêm `DOKPLOY_URL`, `DOKPLOY_TOKEN`, `DOKPLOY_BACKEND_ID`, `DOKPLOY_AI_ID`.
- [ ] Branch protection: required check = CI trên PR (monitor merge-to-main rõ; deploy quan sát trong Dokploy).
- [ ] (Tùy chọn) Dokploy → Notifications: Slack/Discord khi deploy success/fail.

## Phase 6 — Cutover & dọn
- [ ] Smoke test: health backend+ai · chat streaming · login Google · payment callback · upload R2 · search.
- [ ] Tắt droplet + DB cũ (sau khi chắc chắn) — **giữ file dump**.
- [ ] Repo này: archive `docker/Caddyfile`, `docker/deploy.sh`, flow SSH cũ; trỏ README sang runbook này.

---

## §Env — bản đồ thay đổi cho CI/CD

| Biến / Secret | Hành động khi migrate |
|---|---|
| `DROPLET_HOST` / `DROPLET_USER` / `DROPLET_SSH_KEY` | ❌ Bỏ (Dokploy lo CD, không SSH) |
| `DEPLOY_REPO_TOKEN` | ❌ Bỏ (không bump `tags.env` nữa) |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | ✅ Giữ (CI vẫn build/push) |
| `DOKPLOY_URL` / `DOKPLOY_TOKEN` / `DOKPLOY_BACKEND_ID` / `DOKPLOY_AI_ID` | ➕ Thêm mới (CI gọi webhook) |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USERNAME` / `DB_PASSWORD` | ⚠️ Đổi → DB mới (set trong Dokploy env, không còn ở `.env`/`tags.env`) |
| `REDIS_HOST` / `REDIS_PWD` | ⚠️ Đổi → Redis service Dokploy |
| `API_DOMAIN` / `CORS_ALLOWED_ORIGINS` / `CLIENT_URL` / `ADMIN_URL` | ⚠️ Đổi → domain mới |
| FE `NEXT_PUBLIC_URL_API_BASE` / `NEXT_PUBLIC_URL_API_AI` / `NEXT_PUBLIC_SITE_URL` / `NEXT_PUBLIC_GOOGLE_REDIRECT_URI` | ⚠️ Đổi → domain mới (Vercel env) |
| `GOOGLE_AUTH_CLIENT_REDIRECT_URI` / VNPay `*_RETURN_URL` / ZaloPay `*_RETURN_URL` | ⚠️ Đổi → domain mới (+ cập nhật console nhà cung cấp) |
| `GCP_CREDENTIALS_BASE64` / `GCP_PROJECT_ID` / R2_* / Brevo / Langfuse / LLM_* | ✅ Giữ (account-level, không đổi) |

App env đầy đủ: xem `docker/.env.example` (chuyển hết sang **Dokploy env UI per app**, không dùng `.env`/`tags.env` nữa).

## §CI/CD model mới (chi tiết)
- **CI (GitHub Actions, giữ):** PR → lint/test (gate). Push main/dev → `docker build` + push lên DockerHub (tag = SHA + `dev`/`prod`).
- **Trigger CD:** step cuối của CI gọi:
  `curl -X POST "$DOKPLOY_URL/api/application.deploy" -H "Authorization: Bearer $DOKPLOY_TOKEN" -d '{"applicationId":"<APP_ID>"}'`
  (xác nhận đúng endpoint/redeploy webhook trong Dokploy UI khi tạo app).
- **CD (Dokploy):** app cấu hình deploy-from-registry → nhận webhook → pull image mới → redeploy; log + health trong UI.
- **Dockerfile:** cả 4 đã multi-stage sạch (build vs runtime tách rõ) — không cần đổi. Việc lẫn lộn CI/CD nằm ở **workflow**, không ở Dockerfile.

## §Rollback / an toàn
- Không tắt droplet/DB cũ tới khi Phase 6 verify xong.
- Giữ file dump `.sql` ở ≥ 2 nơi.
- DNS đổi từ từ (TTL thấp) để rollback nhanh nếu cần.
