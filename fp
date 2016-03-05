#!/bin/env python
# -*- coding: utf-8 -8-
"""
fp (FirePlug) ... Run your code on remote Docker hosts

Usage:
    $ cp -r ~/.aws .              # Copy your aws configuration
    $ docker-machine create       # Create docker machine
    $ fp --init                   # Initialize fp configuration
    $ fp python your_script.py    # Run your script on current directory

Author: Kohei
License: BSD3
"""
import os
import sys
import json
import subprocess
import argparse
import ConfigParser


VERSION = '1.1'


if os.path.exists('.fp'):
    __conf = ConfigParser.ConfigParser()
    __conf.read('.fp')


def conf(k1, k2):
    return __conf.get(k1, k2)


# --------------
# DOCKER-MACHINE


def _docker_machine_cmd(cmd):
    """
    Run docker-machine command and return the stdout as list of string.
    """
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    ret = []
    for line in proc.stdout:
        ret.append(line.rstrip())
        proc.stdout.flush()
    return ret


def docker_machine_inspect(docker_host):
    cmd = ['docker-machine', 'inspect', docker_host]
    ret = _docker_machine_cmd(cmd)
    ret_string = "\n".join(ret)

    return json.loads(ret_string)


def docker_machine_config(docker_host):
    cmd = ['docker-machine', 'config', docker_host]
    return _docker_machine_cmd(cmd)


def docker_hosts():
    cmd = ['docker-machine', 'ls']
    ret = _docker_machine_cmd(cmd)

    # TODO: considering the status is runnning or not.
    return [line.split(' ')[0] for line in ret[1:]]


# ------
# DOCKER


def _docker_cmd(cmd):
    """
    Run docker command and return the stdout as list of string.
    """
    pass


def calc_num_processors(docker_host, base_image='smly/alpine-kaggle'):
    docker_option_list = docker_machine_config(docker_host)

    docker_option_list += ['run', '--rm', '-i', base_image]
    run_cmd = ['grep', 'processor', '/proc/cpuinfo']
    docker_cmd = ['docker'] + docker_option_list + run_cmd

    proc = subprocess.Popen(docker_cmd, stdout=subprocess.PIPE)
    ret = []
    for line in proc.stdout:
        ret.append(line)
    proc.wait()

    return len(ret)


def calc_num_current_process(docker_host):
    docker_option_list = docker_machine_config(docker_host)

    docker_option_list += ['ps']
    docker_cmd = ['docker'] + docker_option_list

    proc = subprocess.Popen(docker_cmd, stdout=subprocess.PIPE)
    ret = []
    for line in proc.stdout:
        ret.append(line)
    proc.wait()

    # Subtract 1 for header
    num_proc = len(ret) - 1

    return num_proc


def build_docker_image(docker_host, args):
    working_image = conf('docker', 'working_image')
    docker_option_list = docker_machine_config(docker_host)

    docker_option_list += ['build', '-t', working_image, '.']
    docker_cmd = ['docker'] + docker_option_list

    print("({}) Build images ...".format(docker_host))
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(docker_cmd))
        proc = subprocess.Popen(docker_cmd)
        proc.wait()
    else:
        with open(os.devnull, 'w') as devnull:
            proc = subprocess.Popen(docker_cmd,
                                    stdout=devnull,
                                    stderr=devnull)
            proc.wait()
    return


# ----
# main


def _get_cpuset_option(docker_host):
    base_image = conf('docker', 'base_image')
    num_proc = calc_num_processors(docker_host, base_image=base_image)
    if num_proc == 1:
        return '--cpuset-cpus="0"'
    else:
        return '--cpuset-cpus="0-{}"'.format(num_proc - 1)


def sync_s3_bucket(docker_host, args, reverse=False):
    # Get info from configuration file
    working_image = conf('docker', 'working_image')
    bucket_path = conf('sync', 's3')
    sync_to = conf('sync', 'datapath')
    mount_path = "{}:{}".format(
        conf('filesystem', 'hostside_path'),
        conf('filesystem', 'mount_point'))

    docker_option_list = docker_machine_config(docker_host)
    docker_option_list += [
        'run', '--rm', '-i', '-v', mount_path, working_image]
    run_cmd = ['aws', 's3', 'sync', bucket_path, sync_to]

    # Upload base
    if reverse is True:
        run_cmd = ['aws', 's3', 'sync', sync_to, bucket_path]

    docker_cmd = ['docker'] + docker_option_list + run_cmd

    print("({}) Sync files ...".format(docker_host))
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(docker_cmd))
        proc = subprocess.Popen(docker_cmd)
        proc.wait()
    else:
        with open(os.devnull, 'w') as devnull:
            proc = subprocess.Popen(docker_cmd,
                                    stdout=devnull,
                                    stderr=devnull)
            proc.wait()
    return


def run_docker(docker_host, script_args, args):
    working_image = conf('docker', 'working_image')
    mount_path = "{}:{}".format(
        conf('filesystem', 'hostside_path'),
        conf('filesystem', 'mount_point'))

    docker_option_list = docker_machine_config(docker_host)
    cpuset = _get_cpuset_option(docker_host)
    docker_option_list += [
        'run', cpuset, '--rm', '-i', '-v', mount_path, working_image
    ]
    docker_cmd = ['docker'] + docker_option_list + script_args

    print("({}) Run container ...".format(docker_host))
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(docker_cmd))

    proc = subprocess.Popen(docker_cmd)
    proc.wait()
    return


def mkdir_datapath(docker_host, args):
    sync_datapath = conf('sync', 'datapath')
    cmd = ['sudo', 'mkdir', '-p', sync_datapath]
    cmd = ['docker-machine', 'ssh', docker_host] + cmd

    # Run
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(cmd))

    # TODO: error handling
    _docker_machine_cmd(cmd)


def rsync_files(docker_host, args, reverse=False):
    inspect_ret = docker_machine_inspect(docker_host)
    sshkey_path = inspect_ret['Driver']['SSHKeyPath']
    ipaddr = inspect_ret['Driver']['IPAddress']

    # Load configurations
    sync_datapath = conf('sync', 'datapath')
    sync_localpath = conf('sync', 'localpath')

    # Enable to ssh login as root (need to consider here)
    cmd = ['sudo', 'cp', '/home/ubuntu/.ssh/authorized_keys', '/root/.ssh/']
    cmd = ['docker-machine', 'ssh', docker_host] + cmd

    # Run
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(cmd))

    # TODO: error handling
    _docker_machine_cmd(cmd)

    # Run rsync (Note that the end of copy source shoud be '/')
    ssh_cmd = " ".join([
        'ssh', '-i', sshkey_path,
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null'])
    cmd = [
        'rsync', '-az', '-e',
        '{}'.format(ssh_cmd),
        '--copy-links',
        '--progress',
        sync_localpath,
        'root@{}:{}'.format(ipaddr, sync_datapath)]

    if reverse is True:
        source_place = cmd[-2]
        target_place = cmd[-1]
        cmd[-2] = target_place
        cmd[-1] = source_place

    # TODO: check the end of source
    if not cmd[-2].endswith('/'):
        cmd[-2] = cmd[-2] + '/'

    print("({}) Sync files...".format(docker_host))
    if args.verbose:
        print("({}) >>> ".format(docker_host) + " ".join(cmd))

    # Start rsync command
    with open(os.devnull, 'w') as devnull:
        proc = subprocess.Popen(cmd, stderr=devnull)
        proc.wait()


def check_host_is_ready(docker_host):
    # TODO: check running status
    if calc_num_current_process(docker_host) == 0:
        return True
    else:
        return False


def run(args, remaining_args):
    """
    Build docker image, sync files and run the specified command.

    sync path is defined on a config file, which is located on `.fp`.
    """
    host_list = docker_hosts()
    bucket_path = conf('sync', 's3')

    if args.host is not None:
        if args.host in host_list:
            host_list = [args.host]
        else:
            print("RuntimeError: Unknown host: {}".format(args.host))
            sys.exit(1)

    for docker_host in host_list:
        if not check_host_is_ready(docker_host):
            continue

        # Check datapath (mkdir -p)
        mkdir_datapath(docker_host, args)

        # >>> Build
        if not args.nobuild:
            build_docker_image(docker_host, args)

        # >>> Sync
        if not args.nosync and not args.outsync:
            if bucket_path == 'None':
                rsync_files(docker_host, args)
            else:
                sync_s3_bucket(docker_host, args)

        # >>> Run
        if not args.norun:
            run_docker(docker_host, remaining_args, args)

        # >>> Sync
        if not args.nosync and not args.insync:
            if bucket_path == 'None':
                rsync_files(docker_host, args, reverse=True)
            else:
                sync_s3_bucket(docker_host, args, reverse=True)

        sys.exit(0)

    print("RuntimeError: No docker host is ready to run.")
    sys.exit(1)


def show_version():
    print(VERSION)
    sys.exit(0)


def init():
    # ask project name and s3 bucket
    project_name = raw_input("[1/4] Enter your project name: ")
    s3_bucket = raw_input("[2/4] Enter your s3 bucket name (Default: None): ")
    localpath = raw_input(
        "[3/4] Enter data path on local client (Default: data): ")
    docker_img = raw_input(
        "[4/4] Enter your base docker image (Default: smly/alpine-kaggle): ")

    # Set default value if input value is empty
    if s3_bucket.strip() == '':
        s3_bucket = 'None'
    if docker_img.strip() == '':
        docker_img = 'smly/alpine-kaggle'
    if localpath.strip() == '':
        localpath = 'data'

    # TODO: check .aws files work correctly.
    if s3_bucket != 'None' and not os.path.exists('.aws'):
        print("RuntimeError: Put your .aws config on current directory!")
        sys.exit(1)

    # path
    datapath = os.path.join("/data", project_name)
    s3_path = "s3://{name:s}/{proj_name:s}".format(
        name=s3_bucket,
        proj_name=project_name)
    if s3_bucket == 'None' or s3_bucket == 'False':
        s3_path = 'None'

    # write out .dockerignore
    if os.path.exists('./.dockerignore'):
        raise RuntimeError(".dockerignore is already exists.")

    with open('./.dockerignore', 'w') as f:
        f.write("""*.swp
data
trunk
.git
Dockerfile
.dockerignore
*~
""")

    # write out dockerfile
    if os.path.exists('./Dockerfile'):
        raise RuntimeError("Dockerfile is already exists.")

    with open("./Dockerfile", 'w') as f:
        f.write("""FROM {docker_img:s}
RUN ln -s {datapath:s} /root/data
COPY ./ /root/
WORKDIR /root
""".format(docker_img=docker_img,
           datapath=datapath))

    # write out fp configuration file
    if os.path.exists('./.fp'):
        raise RuntimeError(".fp is already exists.")

    with open("./.fp", 'w') as f:
        f.write("""[filesystem]
hostside_path = /data
mount_point = /data

[docker]
base_image = {base_name:s}
working_image = {proj_name:s}

[sync]
s3 = {s3path:s}
datapath = {filepath:s}
localpath = {localpath:s}
""".format(s3path=s3_path,
           proj_name=project_name,
           filepath=datapath,
           localpath=localpath,
           base_name=docker_img))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--init",
        action='store_true',
        default=False,
        help='Create configuration file and Dockerfile.')
    parser.add_argument(
        "--version",
        action='store_true',
        default=False,
        help='Show version info')
    parser.add_argument(
        "--norun",
        action='store_true',
        default=False,
        help="No run")
    parser.add_argument(
        "--nobuild",
        action='store_true',
        default=False,
        help="No build")
    parser.add_argument(
        "--nosync",
        action='store_true',
        default=False,
        help="No sync")
    parser.add_argument(
        "--insync",
        action='store_true',
        default=False,
        help="insync only")
    parser.add_argument(
        "--outsync",
        action='store_true',
        default=False,
        help="outsync only")
    parser.add_argument(
        "--verbose",
        action='store_true',
        default=False,
        help="Verbose mode")
    parser.add_argument(
        "--host",
        default=None,
        help='Specify a docker host to run.')
    args, remaining_args = parser.parse_known_args()

    if args.init:
        init()
    elif args.version:
        show_version()
    else:
        run(args, remaining_args)
