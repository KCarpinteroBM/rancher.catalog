version: "2"
services:
  postfix:
    image: eeacms/postfix:2.10-3.6
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      sentry: "true"
      postfix: "true"
    environment:
      MTP_HOST: "${sentry_server_name}"
      MTP_RELAY: "ironports.eea.europa.eu"
      MTP_PORT: "8587"
      MTP_USER: "${sentry_email_user}"
      MTP_PASS: "${sentry_email_password}"
      TZ: "${TZ}"
    mem_limit: ${postfix_mem_limit}
    mem_reservation: ${postfix_mem_reservation}

  memcached:
    image: memcached:1.6.9-alpine
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      sentry: "true"
      memcached: "true"
    environment:
      TZ: "${TZ}"
    mem_limit: ${memcached_mem_limit}
    mem_reservation: ${memcached_mem_reservation}
    command:
    - "-m"
    - "2048"

  redis:
    image: redis:6.2.4-alpine
    labels:
      io.rancher.container.hostname_override: container_name
      {{- if .Values.sentry_host_labels}}
      io.rancher.scheduler.affinity:host_label: ${sentry_host_labels}
      {{- else}}
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      {{- end}}
      sentry: "true"
      redis: "true"
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
    {{- if (.Values.redisdata_volume) }}
    - ${redisdata_volume}:/data
    {{- else}}
    - redisdata:/data
    {{- end}}
    ulimits:
      nofile:
        soft: 10032
        hard: 10032
    environment:
      TZ: "${TZ}"
    mem_limit: ${redis_mem_limit}
    mem_reservation: ${redis_mem_reservation}

  postgres:
    image: eeacms/sentry-postgres:21.6.1
    labels:
      io.rancher.container.hostname_override: container_name
      {{- if .Values.sentry_host_labels}}
      io.rancher.scheduler.affinity:host_label: ${sentry_host_labels}
      {{- else}}
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      {{- end}}
      sentry: "true"
      postgres: "true"
    environment:
      POSTGRES_DB: "${sentry_db_name}"
      POSTGRES_USER: "${sentry_db_user}"
      POSTGRES_PASSWORD: "${sentry_db_pass}"
      POSTGRES_CRONS: "${sentry_db_crons}"
      TZ: "${TZ}"
    mem_limit: ${db_mem_limit}
    mem_reservation: ${db_mem_reservation}
    volumes:
    {{- if (.Values.sentrypostgres_volume) }}
    - ${sentrypostgres_volume}:/var/lib/postgresql/data
    {{- else}}
    - sentrypostgres:/var/lib/postgresql/data
    {{- end}}
    {{- if (.Values.sentrybackup_volume) }}
    - ${sentrybackup_volume}:/postgresql.backup
    {{- else}}
    - sentrybackup:/postgresql.backup
    {{- end}}
  

  zookeeper:
    image: confluentinc/cp-zookeeper:5.5.0
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    environment:
      ZOOKEEPER_CLIENT_PORT: '2181'
      CONFLUENT_SUPPORT_METRICS_ENABLE: 'false'
      ZOOKEEPER_LOG4J_ROOT_LOGLEVEL: 'WARN'
      ZOOKEEPER_TOOLS_LOG4J_LOGLEVEL: 'WARN'
      KAFKA_OPTS: "-Dzookeeper.4lw.commands.whitelist=ruok"
    volumes:
      - sentry-zookeeper:/var/lib/zookeeper/data
      - sentry-zookeeper-log:/var/lib/zookeeper/log
      - sentry-secrets:/etc/zookeeper/secrets

 

  kafka:
    image: confluentinc/cp-kafka:5.5.0
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - zookeeper
    environment:
      KAFKA_ZOOKEEPER_CONNECT: "zookeeper:2181"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: "1"
      KAFKA_OFFSETS_TOPIC_NUM_PARTITIONS: "1"
      KAFKA_LOG_RETENTION_HOURS: "24"
      KAFKA_MESSAGE_MAX_BYTES: "50000000" #50MB or bust
      KAFKA_MAX_REQUEST_SIZE: "50000000" #50MB on requests apparently too
      CONFLUENT_SUPPORT_METRICS_ENABLE: "false"
      KAFKA_LOG4J_LOGGERS: "kafka.cluster=WARN,kafka.controller=WARN,kafka.coordinator=WARN,kafka.log=WARN,kafka.server=WARN,kafka.zookeeper=WARN,state.change.logger=WARN"
      KAFKA_LOG4J_ROOT_LOGLEVEL: "WARN"
      KAFKA_TOOLS_LOG4J_LOGLEVEL: "WARN"
    volumes:
      - sentry-kafka:/var/lib/kafka/data
      - sentry-kafka-log:/var/lib/kafka/log
      - sentry-secrets:/etc/kafka/secrets
   
    


  clickhouse:
    image: yandex/clickhouse-server:20.3.9.70
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    entrypoint:
      - /bin/sh
      - -c
      - echo '<yandex><max_server_memory_usage_to_ram_ratio from_env=\"MAX_MEMORY_USAGE_RATIO\" /><logger><level>information</level><console>1</console></logger><merge_tree><enable_mixed_granularity_parts>1</enable_mixed_granularity_parts></merge_tree></yandex>' > /etc/clickhouse-server/config.d/sentry.xml;cat /etc/clickhouse-server/config.d/sentry.xml;/entrypoint.sh
    volumes:
      - sentry-clickhouse:/var/lib/clickhouse
      - sentry-clickhouse-log:/var/log/clickhouse-server
    environment:
      MAX_MEMORY_USAGE_RATIO: 0.3    
      
  geoipupdate:
    image: "maxmindinc/geoipupdate:latest"
    # Override the entrypoint in order to avoid using envvars for config.
    # Futz with settings so we can keep mmdb and conf in same dir on host
    # (image looks for them in separate dirs by default).
    environment:
     - GEOIPUPDATE_ACCOUNT_ID - Your MaxMind account ID.
     - GEOIPUPDATE_LICENSE_KEY - Your case-sensitive MaxMind license key.
     - GEOIPUPDATE_EDITION_IDS 
    volumes:
      - sentry-geoip:/usr/share/GeoIP


  snuba-api:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:

  snuba-consumer:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: consumer --storage errors --auto-offset-reset=latest --max-batch-time-ms 750


  snuba-outcomes-consumer:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: consumer --storage outcomes_raw --auto-offset-reset=earliest --max-batch-time-ms 750

  snuba-sessions-consumer:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: consumer --storage sessions_raw --auto-offset-reset=latest --max-batch-time-ms 750

  snuba-transactions-consumer:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: consumer --storage transactions --consumer-group transactions_group --auto-offset-reset=latest --max-batch-time-ms 750 --commit-log-topic=snuba-commit-log
    
  snuba-replacer:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: replacer --storage errors --auto-offset-reset=latest --max-batch-size 3
    
  snuba-subscription-consumer-events:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
    # Leaving the value empty to just pass whatever is set
    # on the host system (or in the .env file)
      SENTRY_EVENT_RETENTION_DAYS:
    command: subscriptions --auto-offset-reset=latest --consumer-group=snuba-events-subscriptions-consumers --topic=events --result-topic=events-subscription-results --dataset=events --commit-log-topic=snuba-commit-log --commit-log-group=snuba-consumers --delay-seconds=60 --schedule-ttl=60
  
  snuba-subscription-consumer-transactions:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
      SENTRY_EVENT_RETENTION_DAYS:
    command: subscriptions --auto-offset-reset=latest --consumer-group=snuba-transactions-subscriptions-consumers --topic=events --result-topic=transactions-subscription-results --dataset=transactions --commit-log-topic=snuba-commit-log --commit-log-group=transactions_group --delay-seconds=60 --schedule-ttl=60
    
 
  snuba-cleanup:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.container.start_once: 'true'
      cron.schedule: "0 */5 * * * *"
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
      SENTRY_EVENT_RETENTION_DAYS:
    command: 'gosu snuba snuba cleanup --storage errors --dry-run False'
    
  snuba-transactions-cleanup:
    image: getsentry/snuba:21.6.1
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.container.start_once: 'true'
      cron.schedule: "0 */5 * * * *"
    depends_on:
      - redis
      - clickhouse
      - kafka
    environment:
      SNUBA_SETTINGS: docker
      CLICKHOUSE_HOST: clickhouse
      DEFAULT_BROKERS: "kafka:9092"
      REDIS_HOST: redis
      UWSGI_MAX_REQUESTS: "10000"
      UWSGI_DISABLE_LOGGING: "true"
      SENTRY_EVENT_RETENTION_DAYS:
    command: 'gosu snuba snuba cleanup --storage transactions --dry-run False'



  symbolicator:
    image: getsentry/symbolicator:0.3.4
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    environment: 
      SYMBOLICATORCONFIG:  |
        cache_dir: "data"\nbind: "0.0.0.0:3021"\nlogging:\n  level: "warn"\nmetrics:\n  statsd: null \nsentry_dsn: null
    command: 
    - /bin/sh 
    - -c
    - echo -e $$SYMBOLICATORCONFIG > /etc/symbolicator/config.yml; run -c /etc/symbolicator/config.yml
    volumes:
      - sentry-symbolicator:/data

  symbolicator-cleanup:
    image: getsentry/symbolicator:0.3.4
    labels:
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.container.start_once: 'true'
      cron.schedule: "0 55 23 * * *"
    command: 'gosu symbolicator symbolicator cleanup'
    volumes:
      - sentry-symbolicator:/data

  web:
    <<: *sentry_defaults
  cron:
    <<: *sentry_defaults
    command: run cron
  worker:
    <<: *sentry_defaults
    command: run worker
  ingest-consumer:
    <<: *sentry_defaults
    command: run ingest-consumer --all-consumer-types
  post-process-forwarder:
    <<: *sentry_defaults
    # Increase `--commit-batch-size 1` below to deal with high-load environments.
    command: run post-process-forwarder --commit-batch-size 1
  subscription-consumer-events:
    <<: *sentry_defaults
    command: run query-subscription-consumer --commit-batch-size 1 --topic events-subscription-results
  subscription-consumer-transactions:
    <<: *sentry_defaults
    command: run query-subscription-consumer --commit-batch-size 1 --topic transactions-subscription-results
    
    
  sentry-cleanup:
    <<: *sentry_defaults
    image: sentry-cleanup-onpremise-local
    build:
      context: ./cron
      args:
        BASE_IMAGE: "$SENTRY_IMAGE"
    entrypoint: "/entrypoint.sh"
    command: '"0 0 * * * gosu sentry sentry cleanup --days $SENTRY_EVENT_RETENTION_DAYS"'
  nginx:
    <<: *restart_policy
    ports:
      - "$SENTRY_BIND:80/tcp"
    image: "nginx:1.16"
    volumes:
      - type: bind
        read_only: true
        source: ./nginx
        target: /etc/nginx
    depends_on:
      - web
      - relay
  relay:
    <<: *restart_policy
    image: "$RELAY_IMAGE"
    volumes:
      - type: bind
        read_only: true
        source: ./relay
        target: /work/.relay
      - type: bind
        read_only: true
        source: ./geoip
        target: /geoip
    depends_on:
      - kafka
      - redis
      - web
      
      
    
  sentry:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      {{- if .Values.sentry_host_labels}}
      io.rancher.scheduler.affinity:host_label: ${sentry_host_labels}
      {{- else}}
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      {{- end}}
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      sentry: "true"
      master: "true"
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
      SNUBA: "http://snuba-api:1218"
    mem_limit: ${sentry_mem_limit}
    mem_reservation: ${sentry_mem_reservation}
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    command:
    - "/bin/bash"
    - "-c"
    - "sentry upgrade --noinput && sentry createuser --email ${sentry_initial_user_email} --password ${sentry_initial_user_password} --superuser && /entrypoint.sh run web || /entrypoint.sh run web"
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached


  worker:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      sentry: "true"
      worker: "true"
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
      SNUBA: "http://snuba-api:1218"
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    mem_limit: ${worker_mem_limit}
    mem_reservation: ${worker_mem_reservation}
    command:
    - "run"
    - "worker"
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached

  web:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached


  cron:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      sentry: "true"
      cron: "true"
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
    mem_limit: ${cron_mem_limit}
    mem_reservation: ${cron_mem_reservation}
    command:
    - "run"
    - "cron"
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached

  ingest-consumer:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
    command: 
    - "run"
    - "ingest-consumer"
    - "--all-consumer-types"
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached

  post-process-forwarder:
    image: eeacms/sentry:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
    command: 
    - "run"
    - "post-process-forwarder"
    - "--commit-batch-size 1"
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached

  sentry-cleanup:
    image: viitanener/sentry-cleanup-onpremise-local:latest
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
    environment:
      SENTRY_EMAIL_HOST: "postfix"
      SENTRY_EMAIL_PORT: "25"
      SENTRY_SECRET_KEY: "${sentry_secret_key}"
      SENTRY_SERVER_EMAIL: "${sentry_server_email}"
      SENTRY_POSTGRES_HOST: "postgres"
      SENTRY_DB_NAME: "${sentry_db_name}"
      SENTRY_DB_USER: "${sentry_db_user}"
      SENTRY_DB_PASSWORD: "${sentry_db_pass}"
      SENTRY_SINGLE_ORGANIZATION: "${sentry_single_organization}"
      LDAP_SERVER: "${LDAP_SERVER}"
      LDAP_BIND_DN: "${LDAP_BIND_DN}"
      LDAP_BIND_PASSWORD: "${LDAP_BIND_PASSWORD}"
      LDAP_USER_DN: "${LDAP_USER_DN}"
      LDAP_DEFAULT_SENTRY_ORGANIZATION: "${LDAP_DEFAULT_SENTRY_ORGANIZATION}"
      LDAP_LOGLEVEL: "${LDAP_LOGLEVEL}"
      TZ: "${TZ}"
    command: '"0 0 * * * gosu sentry sentry cleanup --days $SENTRY_EVENT_RETENTION_DAYS"'
    volumes:
    {{- if (.Values.sentryconf_volume) }}
    - ${sentryconf_volume}:/etc/sentry
    {{- else}}
    - sentryconf:/etc/sentry
    {{- end}}
    {{- if (.Values.sentryfiles_volume) }}
    - ${sentryfiles_volume}:/var/lib/sentry/files
    {{- else}}
    - sentryfiles:/var/lib/sentry/files
    {{- end}}
    depends_on:
    - postgres
    - redis
    - postfix
    - memcached
    links:
    - postgres:postgres
    - redis:redis
    - postfix:postfix
    - memcached:memcached

volumes:
  {{- if (.Values.sentryconf_volume) }}
  {{.Values.sentryconf_volume}}:
    external: yes
  {{- else}}
  sentryconf:
  {{- end}}
    driver: ${sentry_config_driver}
    driver_opts:
      {{.Values.sentry_config_driver_opt}}
  {{- if (.Values.sentryfiles_volume) }}
  {{.Values.sentryfiles_volume}}:
    external: yes
  {{- else}}
  sentryfiles:
  {{- end}}
    driver: ${sentry_upload_driver}
    driver_opts:
      {{.Values.sentry_upload_driver_opt}}
  {{- if (.Values.sentrypostgres_volume) }}
  {{.Values.sentrypostgres_volume}}:
    external: yes
  {{- else}}
  sentrypostgres:
  {{- end}}
    driver: ${sentry_storage_driver}
    driver_opts:
      {{.Values.sentry_storage_driver_opt}}
  {{- if (.Values.sentrybackup_volume) }}
  {{.Values.sentrybackup_volume}}:
    external: yes
  {{- else}}
  sentrybackup:
  {{- end}}
    driver: ${sentry_backup_driver}
    driver_opts:
      {{.Values.sentry_backup_driver_opt}}
  {{- if (.Values.redisdata_volume) }}
  {{.Values.redisdata_volume}}:
    external: yes
  {{- else}}
  redisdata:
  {{- end}}
    driver: ${sentry_redis_driver}
    driver_opts:
      {{.Values.sentry_redis_driver_opt}}
  sentry-zookeeper:
    driver: rancher-nfs
  sentry-zookeeper-log:
    driver: rancher-nfs
  sentry-secrets:
    driver: rancher-nfs
  sentry-kafka:
    driver: rancher-nfs
  sentry-kafka-log:
    driver: rancher-nfs
  sentry-secrets:
    driver: rancher-nfs
  sentry-symbolicator:
    driver: rancher-nfs
  sentry-clickhouse:
    driver: rancher-nfs
  sentry-clickhouse-log:
    driver: rancher-nfs
 sentry-geoip:
    driver: rancher-nfs
 
