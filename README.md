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

### Run xgboooooost command on remote Dcoker host
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

## BSRS-flow

FirePlug uses the sequence of following commands: Build-Sync-Run-Sync.

## Related project

* https://github.com/smly/alpine-kaggle
