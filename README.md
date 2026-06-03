# MLflow Tracking Server

Servidor MLflow con Postgres, MinIO y Nginx. Apto para desarrollo local y producción utilizando SSH tunneling.

Incluye:

- **Postgres** como backend store de MLflow.
- **MinIO** como artifact store compatible con S3.
- **MLflow Tracking Server**.
- **Nginx** como reverse proxy con Basic Auth.
- **create-buckets** como contenedor temporal para crear el bucket de MinIO.

---

## Archivos principales

```text
docker-compose.yml
docker-compose.server.yml
.env.example
.env
nginx.conf
.htpasswd
scripts/bootstrap-secrets.sh
scripts/create-minio-bucket.sh
```

---

## 1. Preparación inicial local

Crear `.env` desde el template:

```bash
cp .env.example .env
```

Dar permisos de ejecución a los scripts:

```bash
chmod +x scripts/bootstrap-secrets.sh
chmod +x scripts/create-minio-bucket.sh
```

Generar secretos y `.htpasswd`:

```bash
./scripts/bootstrap-secrets.sh
```

---

## 2. Levantar en desarrollo local

Iniciar servicios:

```bash
docker compose up -d
```

Ver estado:

```bash
docker compose ps
```

Ver logs específicos:

```bash
docker compose logs -f postgres storage create-buckets mlflow nginx
```

---

## 3. URLs en desarrollo local

- MLflow: `http://localhost:8080`
- MinIO: `http://localhost:9001`
- Healthcheck: `http://localhost:8080/health`

Credenciales para MLflow/Nginx:

```dotenv
NGINX_BASIC_AUTH_USER=...
NGINX_BASIC_AUTH_PASSWORD=...
```

Credenciales para MinIO:

```dotenv
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

---

## 4. Detener entorno local

Detener contenedores conservando datos:

```bash
docker compose down
```

Detener contenedores y borrar volúmenes Docker:

```bash
docker compose down -v
```

Borrar datos locales manualmente, solo si se quiere reiniciar todo desde cero:

```bash
sudo rm -rf data-db data-s3
```

> **Advertencia:**  
> `data-db` contiene la metadata de MLflow.  
> `data-s3` contiene los artifacts de MLflow.  
> No borrar estos directorios si se quieren conservar experimentos y artifacts.

---

## 5. Levantar en servidor

Entrar al servidor y ubicarse en el proyecto:

```bash
cd /ruta/del/proyecto
```

Validar configuración combinada:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml config
```

Levantar stack:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml up -d
```

Ver estado:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml ps
```

Ver logs específicos:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml logs -f postgres storage create-buckets mlflow nginx
```

---


## 6. SSH tunnel al servidor

Tunnel básico solo para MLflow:

```bash
ssh -L 8080:127.0.0.1:8080 user@server
```

Mientras ese comando esté abierto, acceder desde el navegador local a:

```text
http://localhost:8080
```

Tunnel para MLflow y MinIO:

```bash
ssh \
  -L 8080:127.0.0.1:8080 \
  -L 9001:127.0.0.1:9001 \
  user@server
```

Luego abrir localmente:

```text
MLflow: http://localhost:8080
MinIO:  http://localhost:9001
```

---

## 7. Regenerar secretos

Esto sobrescribe secretos en `.env` y regenera `.htpasswd`:

```bash
./scripts/bootstrap-secrets.sh
```

Después reiniciar Nginx y servicios que dependan de variables cambiadas.

Local:

```bash
docker compose restart nginx mlflow storage postgres
```

Servidor:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml restart nginx mlflow storage postgres
```
