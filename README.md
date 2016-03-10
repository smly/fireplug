# FirePlug

A plug to multiple remote Docker hosts.

## Usage

```bash
### Create a directory for your proejct
$ mkdir telstra-kaggle; cd telstra-kaggle

### Write your code
$ vim beat_the_benchmark.py

### Assume that you have remote Docker hosts
$ docker-machine ls
NAME    ACTIVE   DRIVER      STATE     URL                        SWARM   DOCKER    ERRORS
aws01   -        amazonec2   Running   tcp://52.34.194.113:2376           v1.10.2
aws02   -        amazonec2   Running   tcp://52.24.241.67:2376            v1.10.2
gcp01   -        google      Running   tcp://104.155.221.1:2376           v1.10.2

### Initialize FirePlug configuration: `.fp`, `Dockerfile` and `.dockerignore` are generated.
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

### Run your code on remote Docker host!
$ fp python beat_the_benchmark.py
(aws01) Build images ...
(aws01) Sync files...
sending incremental file list
(aws01) Run container ...
[0]     valid_0-mlogloss:1.074342       valid_1-mlogloss:1.075862
[1]     valid_0-mlogloss:1.050940       valid_1-mlogloss:1.054601
[2]     valid_0-mlogloss:1.028755       valid_1-mlogloss:1.034398
(snip)

### Run xgboooooost command on remote Docker host
$ fp xgboost data/input/mushroom.conf model_out=data/working/mushroom.model
(aws01) Build images ...
(aws01) Sync files...
sending incremental file list
input/
(aws01) Run container ...
6513x126 matrix with 143286 entries is loaded from
data/input/agaricus.txt.train.buffer
[0]     test-error:0.016139     train-error:0.014433
[1]     test-error:0.000000     train-error:0.001228
1611x126 matrix with 35442 entries is loaded from
data/input/agaricus.txt.test.buffer
boosting round 0, 0 sec elapsed
tree pruning end, 1 roots, 12 extra nodes, 0 pruned nodes, max_depth=3
boosting round 1, 0 sec elapsed
tree pruning end, 1 roots, 10 extra nodes, 0 pruned nodes, max_depth=3

updating end, 0 sec in all
(aws01) Sync files...
receiving incremental file list
working/
working/mushroom.model
          1,505 100%    1.44MB/s    0:00:00 (xfr#1, to-chk=11/1531)

### Then, now you have the model file trained on remote Docker host.
$ file data/working/mushroom.model
data/working/mushroom.model: data
```

## Requirements

* docker
* docker-machine
* rsync

Recommended Dependencies:

* awscli: for synchronizing local folders with Amazon S3 buckets on sync step.
* gcloud: for inspecting remote docker host on google cloud platform.
* pyyaml: for handling the output from gcloud.

## BSRS-flow

FirePlug uses the sequence of following steps: Build-Sync-Run-Sync.
By default, Sync step issues `rsync` command to sync local data and remote data.
AWS S3 bucket is also supported on Sync step, by using `aws s3 sync`.

### How to create a remote Docker host

For example, if you are using Amazon AWS, you can create a remote Docker host by following command:

```bash
$ docker-machine create \
    --driver amazonec2 \
    --amazonec2-vpc-id <VPC ID> \
    --amazonec2-subnet-id <SUBNET ID> \
    --amazonec2-region <REGION> \
    --amazonec2-zone <ZONE NAME> \
    --amazonec2-instance-type <INSTANCE TYPE> \
    --amazonec2-root-size <ROOT SIZE> \
    --amazonec2-ami ami-16b1a077 \
    --amazonec2-security-group <SECURITY GROUP> \
    --amazonec2-request-spot-instance \
    --amazonec2-spot-price <SPOT PRICE> \
    <HOST NAME>
Running pre-create checks...
Creating machine...
(aws02) Launching instance...
(aws02) Waiting for spot instance...
(aws02) Created spot instance request %v sir-0399wx71
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with ubuntu(systemd)...
Installing Docker...
```

In some case, it causes error while running provisioning. Then,

```bash
$ docker-machine rm <HOST NAME>
$ aws ec2 delete-key-pair --key-name <HOST NAME>
```

It's also possible to create a remote docker host on Google Cloud Platform:

```bash
$ docker-machine create \
  --driver google \
  --google-zone <ZONE> \
  --google-project <PROJECT NAME> \
  --google-machine-type <MACHINE TYPE> \
  <HOST NAME>
Running pre-create checks...
(gcp01) Check that the project exists
(gcp01) Check if the instance already exists
Creating machine...
(gcp01) Generating SSH Key
(gcp01) Creating host...
(gcp01) Opening firewall ports

(gcp01) Creating instance
(gcp01) Waiting for Instance
(gcp01) Uploading SSH Key
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with ubuntu(systemd)...
Installing Docker...
```

For this step, `gcloud` command is required to be installed.

## Related project

* https://github.com/smly/alpine-kaggle
