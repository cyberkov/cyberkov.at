---
created: 2020-12-03T19:55:02+01:00
title: foreman provisioning tests mit gitlab-ci und serverspec
modified: 2020-12-03T20:13:56+01:00
layout: post
---

Eine meiner Hauptbeschäftigungen ist die Administration unseres [Foreman](https://theforeman.org/)/[orcharhino](https://orcharhino.com/) und Pflege der diversen Betriebssysteme, die wir tagtäglich an unsere Kunden ausliefern. Nachdem immer wieder neue Releases kommen, Anforderungen verändert werden oder einfach mal ein Update des Betriebssystems den Provisionierungsprozess verändert, habe ich mir mal die Zeit genommen einen automatischen Test des Provisionings zu bauen. Hier hat sich gitlab-ci mit den kürzlich eingeführten Rules als sehr nützlich erwiesen. Davor habe ich mir Jenkins von unseren Entwicklern ausgeborgt, aber voll integriert in gitlab find ichs irgendwie schöner.

## Der Ablauf in .gitlab-ci.yml:

```yaml
workflow:
    rules:
        - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
stages:
    - build
    - wait
    - verify
    - cleanup
```

-   hammer host create erzeugt den Server in VMWare.

```yaml
.build: &build
    image: hammer:latest
    stage: build
    resource_group: foreman
    only:
        - master
    before_script:
        - hammer auth login basic -u ${FOREMAN_USER} -p ${FOREMAN_PASSWORD}
    script:
        - ./build_${OS}.sh
```

[hammer](https://github.com/theforeman/hammer-cli) ist das commandline interface für Foreman.

Damit die Authentifizierung bei Foreman funktioniert muss der session support in hammer aktiviert werden. Dies mache ich bereits im hammer-image mit `sed`.

Das `build_ubuntu2004.sh` enthält dann die notwendigen Parameter. Hier fand ich möglichst wenig Dynamik vorteilhaft, da meine Kollegen gerne solche Commands kopieren wenn mal mehr hosts aufzusetzen sind. Der geneigte Leser kann dies auch gerne mit Makefiles (und [argbash](https://argbash.io/) zB) und/oder anderen Dingen vereinfachen.

```bash
hammer \
  host create \
  --name="ubuntu20" \
  --domain "test.lan" \
  --ip="192.168.5.20" \
\
  --operatingsystem "Ubuntu 20.04 LTS" \
  --partition-table "preseed-default" \
  --medium "Ubuntu" \
  --lifecycle-environment-id 1 \
  --content-view "Ubuntu 20.04" \
\
  --subnet 'provisioning_tests' \
  --organization 'APA-IT' \
  --location 'DC1' \
  --compute-profile "small" \
  --hostgroup-title "Canary" \
  --compute-resource='vcenter' \
  --compute-attributes='start=1,annotation="provisioning tests #nobackup# required.",guest_id="ubuntu64Guest"'
```

-   [wait-for-it.sh](https://github.com/vishnubob/wait-for-it) testet regelmäßig ob ein Login per ssh möglich ist. Da der Key erst mit dem ersten puppetrun ausgebracht wird, wird sichergestellt dass wir "nicht zu früh" vorbeikommen.

```yaml
.wait: &wait
    stage: wait
    image: toughiq/toolbox:gitlab
    only:
        - master
    before_script:
        - 'which ssh-agent || ( apk add openssh-client )'
        - eval $(ssh-agent -s)
    script:
        - ./wait.sh $OS_IP
```

wait.sh sieht entsprechend aus:

```bash
#!/bin/bash
# shellcheck disable=SC1090
set -euo pipefail
IFS=$'\n\t'
OS_IP=$1

# We need to wait for the ssh port to be reachable
./utils/wait-for-it.sh -h "${OS_IP}" -p 22 -t 1800 && \

echo "Waiting for puppet to finish..." # && sleep 600

until ssh "${OS_IP}" -l provtest -o "PasswordAuthentication=no" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" id; do
  echo "sleeping 2 seconds until ssh becomes available..." && sleep 2
done

echo "Login successful. Continuing in a few seconds..."
sleep 60

echo 'Done waiting.'
```

-   [serverspec](https://serverspec.org/) überprüft ob die Anforderung erfüllt sind und nicht versehentlich Settings geändert wurden

```yaml
.verify: &verify
    stage: verify
    image: serverspec:latest
    only:
        - master
    artifacts:
        when: always
        paths:
            - rspec.xml
        reports:
            junit: rspec.xml
    before_script:
        - 'which ssh-agent || ( apk add openssh-client )'
        - eval $(ssh-agent -s)
    script:
        - rake spec:${OS_FQDN}
```

`spec/base_spec.rb` sieht dann zum Beispiel so aus:

```ruby
require 'spec_helper'

describe port(22) do
  it { should be_listening }
end

describe cron do
  its(:table) do
    should match %r{/opt/puppetlabs/bin/puppet agent --onetime --no-daemonize}
  end
end

describe package('sudo') do
  it { should be_installed }
end
```

-   cleanup löscht den Server mittels `hammer host delete`:

```yaml
.cleanup: &cleanup
    stage: cleanup
    image: hammer:latest
    when: always
    resource_group: foreman
    allow_failure: true
    before_script:
        - hammer auth login basic -u ${FOREMAN_USER} -p ${FOREMAN_PASSWORD}
    script:
        - hammer host delete --name ${OS_FQDN}
    only:
        - master
```

-   Ab hier kopiert man die jeweilige Konfiguration und lädt die dazupassenden Steps:

```yaml
# OS Config
.ubuntu2004: &ubuntu2004
  variables:
    OS: ubuntu2004
    OS_FQDN: ubuntu20.test.lan
    OS_IP: '192.168.5.20'
ubuntu2004:build:
  <<: [*ubuntu2004, *build]
ubuntu2004:wait:
  needs: ['ubuntu2004:build']
  <<: [*ubuntu2004, *wait]
ubuntu2004:verify:
  needs: ['ubuntu2004:wait']
  <<: [*ubuntu2004, *verify]
ubuntu2004:cleanup:
  needs: ['ubuntu2004:verify']
  <<: [*ubuntu2004, *cleanup]
```

Jetzt nur noch den Build regelmäßig von gitlab triggern lassen - fertig.

{% responsive_image alt:"CI Pipeline" path: "assets/gitlab-provsioning-pipeline.png" %}

Leider musste ich nahezu alle DockerImages selbst bauen, welche jedoch relativ simpel sind (serverspec installieren, hammer nach Anleitung installieren).

Ein wenig störend fand ich jeden Tag ein Email von Foreman zu bekommen, dass alle Server erfolgreich gebaut wurden. Hier wäre es schön einen Schalter in hammer zu haben um built notifications für diesen Host abzuschalten.
