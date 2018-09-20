
# What is Matomo?

> Matomo is a free and open source web analytics application written by a team of international developers that runs on a PHP/MySQL webserver. It tracks online visits to one or more websites and displays reports on these visits for analysis. As of September 2015, Matomo was used by nearly 900 thousand websites, or 1.3% of all websites, and has been translated to more than 45 languages. New versions are regularly released every few weeks.

https://www.matomo.org/

# Prerequisites

To run this application you need [Docker Engine](https://www.docker.com/products/docker-engine) >= `1.10.0`. [Docker Compose](https://www.docker.com/products/docker-compose) is recommended with a version `1.6.0` or later.


## Run the Matomo image using the Docker Command Line

If you want to run the application manually instead of using docker-compose, these are the basic steps you need to run:

1. Create a new network for the application and the database:

  ```bash
  $ docker network create matomo_network
  ```

2. Create a volume for MariaDB persistence and create a MariaDB container

  ```bash
  $ docker volume create --name mariadb_data
  $ docker run -d --name mariadb \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -e MARIADB_USER=bn_matomo \
    -e MARIADB_DATABASE=bitnami_matomo \
    --net matomo_network \
    --volume mariadb_data:/bitnami \
    bitnami/mariadb:latest
  ```

3. Create volumes for Matomo persistence and launch the container

  ```bash
  $ docker volume create --name matomo_data
  $ docker run -d --name matomo -p 80:80 -p 443:443 \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -e MATOMO_DATABASE_USER=bn_matomo \
    -e MATOMO_DATABASE_NAME=bitnami_matomo \
    --net matomo_network \
    --volume matomo_data:/bitnami \
    bitnami/matomo:latest
  ```

Then you can access your application at http://your-ip/

## Persisting your application

If you remove the container all your data and configurations will be lost, and the next time you run the image the database will be reinitialized. To avoid this loss of data, you should mount a volume that will persist even after the container is removed.

For persistence you should mount a volume at the `/bitnami` path. Additionally you should mount a volume for [persistence of the MariaDB data](https://github.com/bitnami/bitnami-docker-mariadb#persisting-your-database).

The above examples define docker volumes namely `mariadb_data` and `matomo_data`. The Matomo application state will persist as long as these volumes are not removed.

To avoid inadvertent removal of these volumes you can [mount host directories as data volumes](https://docs.docker.com/engine/tutorials/dockervolumes/). Alternatively you can make use of volume plugins to host the volume data.

### Mount host directories as data volumes with Docker Compose

This requires a minor change to the `docker-compose.yml` template previously shown:

```yaml
version: '2'

services:
  mariadb:
    image: 'bitnami/mariadb:latest'
    environment:
      - ALLOW_EMPTY_PASSWORD=yes
      - MARIADB_USER=bn_matomo
      - MARIADB_DATABASE=bitnami_matomo
    volumes:
      - '/path/to/mariadb-persistence:/bitnami'
  matomo:
    image: 'bitnami/matomo:latest'
    environment:
      - MATOMO_DATABASE_USER=bn_matomo
      - MATOMO_DATABASE_NAME=bitnami_matomo
      - ALLOW_EMPTY_PASSWORD=yes
    depends_on:
      - mariadb
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - '/path/to/matomo-persistence:/bitnami'
```

### Mount host directories as data volumes using the Docker command line

In this case you need to specify the directories to mount on the run command. The process is the same than the one previously shown:

1. Create a network (if it does not exist):

  ```bash
  $ docker network create matomo_network
  ```

2. Create a MariaDB container with host volume:

  ```bash
  $ docker run -d --name mariadb
    -e ALLOW_EMPTY_PASSWORD=yes \
    -e MARIADB_USER=bn_matomo \
    -e MARIADB_DATABASE=bitnami_matomo \
    --net matomo_network \
    --volume /path/to/mariadb-persistence:/bitnami \
    bitnami/mariadb:latest
  ```
   *Note:* You need to give the container a name in order to Matomo to resolve the host

3. Create the Matomo container with host volumes:

  ```bash
  $ docker run -d --name matomo -p 80:80 -p 443:443 \
    -e ALLOW_EMPTY_PASSWORD=yes \
    -e MATOMO_DATABASE_USER=bn_matomo \
    -e MATOMO_DATABASE_NAME=bitnami_matomo \
    --net matomo_network \
    --volume /path/to/matomo-persistence:/bitnami \
    bitnami/matomo:latest
  ```

# Upgrading Matomo

Bitnami provides up-to-date versions of MariaDB and Matomo, including security patches, soon after they are made upstream. We recommend that you follow these steps to upgrade your container. We will cover here the upgrade of the Matomo container. For the MariaDB upgrade you can take a look at https://github.com/bitnami/bitnami-docker-mariadb/blob/master/README.md#upgrade-this-image

1. Get the updated images:

  ```bash
  $ docker pull bitnami/matomo:latest
  ```

2. Stop your container

 * For docker-compose: `$ docker-compose stop matomo`
 * For manual execution: `$ docker stop matomo`

3. Take a snapshot of the application state

```bash
$ rsync -a /path/to/matomo-persistence /path/to/matomo-persistence.bkp.$(date +%Y%m%d-%H.%M.%S)
```

Additionally, [snapshot the MariaDB data](https://github.com/bitnami/bitnami-docker-mariadb#step-2-stop-and-backup-the-currently-running-container)

You can use these snapshots to restore the application state should the upgrade fail.

4. Remove the currently running container

 * For docker-compose: `$ docker-compose rm -v matomo`
 * For manual execution: `$ docker rm -v matomo`

5. Run the new image

 * For docker-compose: `$ docker-compose up matomo`
 * For manual execution ([mount](#mount-persistent-folders-manually) the directories if needed): `docker run --name matomo bitnami/matomo:latest`

# Configuration

## Environment variables

When you start the Matomo image, you can adjust the configuration of the instance by passing one or more environment variables either on the docker-compose file or on the docker run command line.

##### User and Site configuration

 - `MATOMO_USERNAME`: Matomo application username. Default: **User**
 - `MATOMO_HOST`: Matomo application host. Default: **127.0.0.1**
 - `MATOMO_PASSWORD`: Matomo application password. Default: **bitnami**
 - `MATOMO_EMAIL`: Matomo application email. Default: **user@example.com**
 - `MATOMO_WEBSITE_NAME`: Name of a website to track in Matomo. Default: **example**
 - `MATOMO_WEBSITE_HOST`: Website's host or domain to track in Matomo. Default: **https://example.org**

##### Use an existing database

- `MARIADB_HOST`: Hostname for MariaDB server. Default: **mariadb**
- `MARIADB_PORT_NUMBER`: Port used by MariaDB server. Default: **3306**
- `MATOMO_DATABASE_NAME`: Database name that Matomo will use to connect with the database. Default: **bitnami_matomo**
- `MATOMO_DATABASE_USER`: Database user that Matomo will use to connect with the database. Default: **bn_matomo**
- `MATOMO_DATABASE_PASSWORD`: Database password that Matomo will use to connect with the database. No defaults.
- `ALLOW_EMPTY_PASSWORD`: It can be used to allow blank passwords. Default: **no**

##### Create a database for Matomo using mysql-client

- `MARIADB_HOST`: Hostname for MariaDB server. Default: **mariadb**
- `MARIADB_PORT_NUMBER`: Port used by MariaDB server. Default: **3306**
- `MARIADB_ROOT_USER`: Database admin user. Default: **root**
- `MARIADB_ROOT_PASSWORD`: Database password for the `MARIADB_ROOT_USER` user. No defaults.
- `MYSQL_CLIENT_CREATE_DATABASE_NAME`: New database to be created by the mysql client module. No defaults.
- `MYSQL_CLIENT_CREATE_DATABASE_USER`: New database user to be created by the mysql client module. No defaults.
- `MYSQL_CLIENT_CREATE_DATABASE_PASSWORD`: Database password for the `MYSQL_CLIENT_CREATE_DATABASE_USER` user. No defaults.
- `ALLOW_EMPTY_PASSWORD`: It can be used to allow blank passwords. Default: **no**

If you want to add a new environment variable:

 * For docker-compose add the variable name and value under the application section:

```yaml
application:
  image: bitnami/matomo:latest
  ports:
    - 80:80
  environment:
    - MATOMO_PASSWORD=my_password
```

 * For manual execution add a `-e` option with each variable and value:

```bash
 $ docker run -d -e MATOMO_PASSWORD=my_password -p 80:80 --name matomo -v /your/local/path/bitnami/matomo:/bitnami --net=matomo_network bitnami/matomo
```

### SMTP Configuration

To configure Matomo to send email using SMTP you can set the following environment variables:

 - `SMTP_HOST`: Matomo SMTP host.
 - `SMTP_PORT`: Matomo SMTP port.
 - `SMTP_USER`: Matomo SMTP account user.
 - `SMTP_PASSWORD`: Matomo SMTP account password.
 - `SMTP_PROTOCOL`: Matomo SMTP protocol to use.

This would be an example of SMTP configuration using a Gmail account:

 * docker-compose:

```yaml
  application:
    image: bitnami/matomo:latest
    ports:
      - 80:80
    environment:
      - MARIADB_HOST=mariadb
      - MARIADB_PORT_NUMBER=3306
      - MATOMO_DATABASE_USER=bn_matomo
      - MATOMO_DATABASE_NAME=bitnami_matomo
      - SMTP_HOST=smtp.gmail.com
      - SMTP_USER=your_email@gmail.com
      - SMTP_PASSWORD=your_password
      - SMTP_PROTOCOL=tls
      - SMTP_PORT=587
```

 * For manual execution:

```bash
 $ docker run -d --name matomo -p 80:80 -p 443:443 \
   --net matomo_network \
   -e MARIADB_HOST=mariadb \
   -e MARIADB_PORT_NUMBER=3306 \
   -e MATOMO_DATABASE_USER=bn_matomo \
   -e MATOMO_DATABASE_NAME=bitnami_matomo \
   -e SMTP_HOST=smtp.gmail.com \
   -e SMTP_PROTOCOL=TLS \
   -e SMTP_PORT=587 \
   -e SMTP_USER=your_email@gmail.com \
   -e SMTP_PASSWORD=your_password \
   -v /your/local/path/bitnami/matomo:/bitnami \
 bitnami/matomo:latest
```
