# MLflow Tracking Server

Servidor MLflow con Postgres, MinIO y Nginx. Pensado para desarrollo local y despliegue en servidor Ubuntu con acceso mediante SSH tunneling.

Repositorio: https://github.com/cesar-upv/mlflow-tracking-server

## Componentes

- **Postgres**: backend store de MLflow.
- **MinIO**: artifact store compatible con S3.
- **MLflow Tracking Server**: interfaz y API de tracking.
- **Nginx**: reverse proxy con Basic Auth.
- **create-buckets**: contenedor temporal que crea el bucket de MinIO.

## Requisitos

- Docker y Docker Compose.
- Bash, `openssl`, `sed`, `grep`, `awk` y `tr`.
- En servidor: Linux/Ubuntu recomendado.

### Windows

El proyecto está destinado a entornos Linux porque el servidor objetivo está basado en Ubuntu. Para ejecutarlo localmente en Windows se necesita una shell compatible con Bash:

- **Git Bash**: opción más sencilla para la demo local.
- **WSL (Windows Subsystem for Linux)**: opción más cercana a un entorno Linux real.
- **Bash disponible en PATH**: válido si los comandos requeridos están instalados.

Los comandos de inicialización deben ejecutarse desde esa shell, no desde `cmd.exe`.

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

## Inicialización local

```bash
git clone https://github.com/cesar-upv/mlflow-tracking-server
cd mlflow-tracking-server

cp .env.example .env
chmod +x scripts/bootstrap-secrets.sh
chmod +x scripts/create-minio-bucket.sh

./scripts/bootstrap-secrets.sh

docker compose up -d
```

## Inicialización en servidor

```bash
git clone https://github.com/cesar-upv/mlflow-tracking-server
cd mlflow-tracking-server

cp .env.example .env
chmod +x scripts/bootstrap-secrets.sh
chmod +x scripts/create-minio-bucket.sh

./scripts/bootstrap-secrets.sh

docker compose -f docker-compose.yml -f docker-compose.server.yml up -d
```

El archivo `docker-compose.server.yml` publica MLflow y MinIO solo en `127.0.0.1`, por lo que el acceso externo se hace mediante SSH tunnel.
En modo servidor, MLflow se publica en el puerto `8081` del host para evitar conflictos con servicios externos. MinIO se publica como API en `9002` y consola en `9003`; dentro de la red de Docker sigue escuchando en `storage:9000`.

## Comandos útiles

### Local

```bash
# Ver estado de los contenedores
docker compose ps

# Ver logs de los servicios principales
docker compose logs -f postgres storage create-buckets mlflow nginx

# Detener contenedores conservando datos
docker compose down
```

### Servidor

```bash
# Ver estado de los contenedores
docker compose -f docker-compose.yml -f docker-compose.server.yml ps

# Ver logs de los servicios principales
docker compose -f docker-compose.yml -f docker-compose.server.yml logs -f postgres storage create-buckets mlflow nginx

# Detener contenedores conservando datos
docker compose -f docker-compose.yml -f docker-compose.server.yml down
```

## URLs

En desarrollo local:

```text
MLflow:      http://localhost:8080
MinIO:       http://localhost:9001
Healthcheck: http://localhost:8080/health
```

Credenciales de MLflow/Nginx:

```dotenv
NGINX_BASIC_AUTH_USER=...
NGINX_BASIC_AUTH_PASSWORD=...
```

Credenciales de MinIO:

```dotenv
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

`./scripts/bootstrap-secrets.sh` muestra la contraseña de Nginx al generarla. Guardarla en un lugar seguro.

## SSH tunnel

Solo MLflow:

```bash
ssh -L 8081:127.0.0.1:8081 user@server
```

MLflow y MinIO:

```bash
ssh \
  -L 8081:127.0.0.1:8081 \
  -L 9003:127.0.0.1:9003 \
  user@server
```

Mientras el tunnel esté abierto:

```text
MLflow:       http://localhost:8081
MinIO Console: http://localhost:9003
```

## Regenerar secretos

```bash
./scripts/bootstrap-secrets.sh
```

Esto sobrescribe secretos en `.env` y regenera `.htpasswd`. Después se deben reiniciar los servicios que dependen de esas variables.

Local:

```bash
docker compose restart nginx mlflow storage postgres
```

Servidor:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml restart nginx mlflow storage postgres
```

## Datos persistentes

El entorno usa directorios locales para persistir información:

```text
data-db  -> metadata de MLflow en Postgres
data-s3  -> artifacts de MLflow en MinIO
```

Para borrar todo y empezar desde cero:

```bash
sudo rm -rf data-db data-s3
```

No borrar estos directorios si se quieren conservar experimentos y artifacts.
