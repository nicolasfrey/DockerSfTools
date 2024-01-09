About
------------------

Commandline utility that make Docker usage easy

Pré-requis
------------
Symfony / Docker

Install
------------

````bash
git clone --branch master https://github.com/nicolasfrey/DockerSfTools.git bin && bin/app config
````

Development
------------
Remove bin folder in your project directory and clone the repository. WARNING: config command remove .git folder

````bash
git clone --branch master https://github.com/nicolasfrey/DockerSfTools.git bin
````

Prometheus php-fpm
----------
Add to your docker-compose.yaml the export service to format the fpm /status correctly for prometheus:

````yaml
  phpfpm-exporter:
    image: ${ARTIFACTORY_PATH}/hipages/php-fpm_exporter
    environment:
      PHP_FPM_SCRAPE_URI: "tcp://phpfpm:9000/status"
      PHP_FPM_LOG_LEVEL: "debug"
    depends_on:
      phpfpm:
        condition: service_started
````

Configuration Nginx
----------
Update your vhost and add this route:

````
location /metrics {
        proxy_pass http://phpfpm-exporter:9253/metrics;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    } 
````
