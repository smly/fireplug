# FirePlug

A plug to multiple remote Docker hosts.

## Requirements

* docker
* docker-machine
* rsync
* awscli (optional)

## Usage

```bash
### Make directory for new proejct
$ mkdir telstra-kaggle; cd telstra-kaggle

### Write your code
$ vim beat_the_benchmark.py

### Assume that you have remote Docker hosts
$ docker-machine ls
NAME    ACTIVE   DRIVER      STATE     URL                        SWARM   DOCKER   ERRORS
aws01   -        amazonec2   Running   tcp://52.36.102.243:2376           v1.9.1
aws02   -        amazonec2   Running   tcp://52.36.102.244:2376           v1.9.1

### Initialize Fireplug configuration: `.fp`, `Dockerfile` and `.dockerfile` are generated.
$ fp --init
[1/4] Enter your project name: telstra
[2/4] Enter your s3 bucket name (Default: None):
[3/4] Enter data path on local client (Default: data):
[4/4] Enter your base docker image (Default: smly/alpine-kaggle):

### Run your code on your PC
$ python beat_the_benchmark.py
[0]     valid_0-mlogloss:1.074342       valid_1-mlogloss:1.075862
[1]     valid_0-mlogloss:1.050940       valid_1-mlogloss:1.054601
[2]     valid_0-mlogloss:1.028755       valid_1-mlogloss:1.034398
(snip)

### Run the sample code on remote Docker host
$ fp python beat_the_benchmark.py
(aws01) Build images ...
(aws01) Sync files...
sending incremental file list
(aws01) Run container ...
[0]     valid_0-mlogloss:1.074342       valid_1-mlogloss:1.075862
[1]     valid_0-mlogloss:1.050940       valid_1-mlogloss:1.054601
[2]     valid_0-mlogloss:1.028755       valid_1-mlogloss:1.034398
(snip)
```

## BSRS-flow

FirePlug uses the sequence of following commands: Build-Sync-Run-Sync.
