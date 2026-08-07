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

Post-init hook (project extension point)
----------
Any project can declare a post-initialisation step by adding an executable
script at `tools/post-init.sh` (in the project itself, not in `bin/` —
`bin/app selfupdate` wipes and re-clones that folder). `bin/app init` runs it
automatically once the project is up; it can also be replayed on its own
with `bin/app postinit`, without going through a full `init` (typical use
case: a certificate that needs yearly renewal).

Projects that declare no `tools/post-init.sh` are completely unaffected —
nothing runs, nothing is printed. If the script exists:

- if it isn't executable, `init`/`postinit` warn (telling you to
  `chmod +x tools/post-init.sh`) and continue;
- if there's no interactive terminal (CI, a piped invocation), the hook is
  skipped with a message instead of hanging on a prompt nobody can answer;
- setting `SKIP_POST_INIT=1` skips it explicitly;
- if the hook fails, `init`/`postinit` warn but do **not** fail — a
  developer without whatever the hook needs (vault access, an internal
  service, …) must still end up with a working local stack.

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
