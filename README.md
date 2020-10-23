# resource.artefacts

This repository contains the source code for the Resource-Artefacts.Storage image, the image that
contains an instance of the [Nexus artefact server](https://www.sonatype.com/nexus-repository-oss).

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and ammending it using a [Chef](https://www.chef.io/chef/) cookbook which installs the Java
Development Kit, Nexus and Jolokia.

When the image is created the following additional virtual hard drives are attached:

* `nexus_artefacts.vhdx` -> `/srv/nexus/blob/artefacts`
* `nexus_docker.vhdx` -> `/srv/nexus/blob/docker`
* `nexus_npm.vhdx` -> `/srv/nexus/blob/npm`
* `nexus_nuget.vhdx` -> `/srv/nexus/blob/nuget`
* `nexus_scratch.vhdx` -> `/srv/nexus/blob/scratch`
* `nexus_scratch_backup.vhdx` -> `/srv/backup/scratch`

NOTE: The disks are attached by using a powershell command so that we can attach the disk and then go
find it and set the drive assigment to the unique  signature of the disk. When we deploy the VM we
only use the disks and create a new VM with those disks but that might lead to a different order in
which disks are attached. By having the drive assignments linked to the drive signature we prevent
issues with missing drives

### Contents

* The OpenJDK Java development kit which is requried to run Nexus. The version of which is determined
  by the version of the `java` cookbook in the `metadata.rb` file.
* The Nexus JAR file. The version of which is determined by the `default['nexus3']['version']`
  attribute in the `default.rb` attributes file in the cookbook.
* The [Jolokia](https://jolokia.org/) JAR file which is used to collect metrics from Nexus. The
  version of which is determined by the `default['jolokia']['version']` attribute in the `default.rb`
  attributes file in the cookbook.

### Configuration

* The Nexus JAR file is installed in the `/opt/nexus/bin` directory.
* The service is added to [Consul](https://consul.io) under the `artefacts` name so that other services
  can locate the artefact storage. The following services are registered with Consul:
  * The management API which can be reached on port 8081. This port also provides an entry
    for the proxy via `edgeproxyprefix-/artefacts`.
  * The different package storage services are registered as follows:
    * Artefacts storage, i.e. generic file blob storage, provides the following services and ports:
      * `read-development` on port 8081.
      * `write-development` on port 8081.
      * `read-production` on port 8081.
      * `write-production` on port 8081.
      * `read-qa` on port 8081.
      * `write-qa` on port 8081.
    * Docker storage for storing [Docker](https://www.docker.com) containers provides the following
      services and ports:
      * `read-production` on port 5000. This service also provides a mirror for the official docker
        [hub](https://hub.docker.com/).
      * `write-production` on port 5002.
      * `read-qa` on port 5010. This service also provides a mirror for the offical docker
        [hub](https://hub.docker.com/) as well as linking to the production docker registry.
      * `write-qa` on port 5012.
    * Gems storage for storing [Ruby Gems](https://guides.rubygems.org/what-is-a-gem/) only provides
      a read mirror of the [official Ruby gems store](https://rubygems.org/). This service is called
      `read-mirror` and can be reached on port 8081.
    * Npm storage for Node.Js packages provides the following services and ports:
      * `read-production` on port 8081. This service also provides a mirror for the official
        NPM [registry](https://www.npmjs.com/)
      * `write-production` on port 8081.
    * NuGet storage provides the following services and ports:
      * `read-production` on port 8081. This service also provides a mirror for the official
        NuGet [registry](https://www.nuget.org/)
      * `write-production` on port 8081.
* The Jolokia JAR file is installed in the `/usr/local/jolokia` directory
* The jolokia service publishes metrics on the `localhost` address only, using port `8090`. This port
  should not be reachable from outside the machine

The service also adds instructions for the Fabio load balancer so that the Jenkins UI is available
via the proxy.

### Authentication

The Nexus resource needs a number of credentials. These are:

* The credentials which are used to connect to Active Directory are obtained from the Consul K-V, for user
  names, and Vault, for the passwords.

### Backup and restore

A scheduled task is created in Nexus to execute a backup of the Nexus database and the blob files, which
contain all the packages. The task is set to run at 13:00 UTC time (i.e. 1:00 AM NZ standard time).
The backup task takes the following steps:

* Create the backup directories in `\srv\backup\scratch`
* Backup the Nexus databases by:
  * Creating a new automated task that backs up the Nexus databases
  * Starting the task and waiting for it to finish
  * Deleting the task
* Create a `tar` archive of the Nexus databases
* Append to the `tar` archive the files in the different blob directories, except for the
  files that are in the blob scratch directory because those are used by the mirror
  repositories
* Upload the 'tar' archive to the backup file server
* Send metrics for the backup process to Telegraf on the `9090` port reporting the
  time taken for the backup process, the size of the backup file and the status

The restore process runs as a systemd daemon. This service will be started on first start-up
of the image. When it runs it will take the following steps:

* Search for a suitable backup on the backup server. The host name of the server is determined by the
  `config/services/backups/protocols/write/host` K-V key and the datacenter by the `config/services/nexus/restore/datacenter`
  K-V key. This means that it is possible to point the restore process to a backup server in a different
  environment
* If a backup is found then download the backup file to the `\srv\backup\scratch\restore` directory
* Untar the backup file
* Copy the database backup files to `/home/nexus/restore-from-backup`
* Copy the blob files, i.e. the files containing the actual packages, to the appropriate
  `/srv/nexus/blob` directories
* Start the nexus service and wait till it is ready for HTTP connections
* Set a flag to indicate to other scripts and services that Nexus is up and running and ready to
  receive further commands
* Disable the restore service.

The restore service is only designed to run on first start up of the image, once Nexus has started
writing to the blobs and the database it is very difficult to perform a restore, so it is safer
to re-create the VM.

### Provisioning

No changes to the provisioning steps provided by the base image are applied.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

Metrics are collected from Nexus and the JVM via [Jolokia](https://jolokia.org/) and
[Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).

## Build, test and deploy

The build process follows the standard procedure for
[building Calvinverse images](https://www.calvinverse.net/documentation/how-to-build).

### Hyper-V

For building Hyper-V images use the following command line

    msbuild entrypoint.msbuild /t:build /P:ShouldCreateHypervImage=true /P:RepositoryArchive=PATH_TO_ARTIFACTLOCATION

where `PATH_TO_ARTIFACTLOCATION` is the full path to the directory where the base image artifact
file is stored.

In order to run the smoke tests on the generated image run the following command line

    msbuild entrypoint.msbuild /t:test /P:ShouldCreateHypervImage=true

## Deploy

Nexus requires a decent amount of memory to function well. The
[Nexus user manual suggests](https://help.sonatype.com/repomanager3/system-requirements#SystemRequirements-Memory)
the following rules:

* Set minimum heap should always equal set maximum heap
* Minimum heap size 1200MB
* Maximum heap size <= 4GB
* Minimum MaxDirectMemory size 2GB
* Minimum unallocated physical memory should be no less than 1/3 of total physical RAM to allow for virtual memory swap
* Max heap + max direct memory <= host physical RAM * 2/3

With the following suggestions for hardware configurations

| Usage                               | Configuration                    |
| ----------------------------------- | -------------------------------- |
| small / personal                    | Memory: 4GB                      |
|   repositories < 20                 |    -Xms1200M                     |
|   total blobstore size < 20GB       |    -Xmx1200M                     |
|   single repository format type     |    -XX:MaxDirectMemorySize=2G    |
| medium / team                       | Memory: 8GB                      |
|   total blobstore size < 200GB      |    -Xms2703M                     |
|   a few repository formats          |    -Xmx2703M                     |
|                                     |    -XX:MaxDirectMemorySize=2703M |
|                                     | Memory: 12GB                     |
|                                     |    -XX:MaxDirectMemorySize=2703M |
|                                     |    -Xms4G                        |
|                                     |    -Xmx4G                        |
|                                     |    -XX:MaxDirectMemorySize=4014M |
| large / enterprise                  | Memory: 16GB                     |
|    repositories > 50                |    -Xms4G                        |
|   total blobstore size > 200GB      |    -Xmx4G                        |
|   diverse set of repository formats |    -XX:MaxDirectMemorySize=6717M |


### Environment

Prior to the provisioning of a new Nexus host the following information should be available in
the environment in which the Jenkins instance will be created.

Make sure that the following keys exist in the Consul key-value store

* `config/environment/directory/endpoints/mainhost` - Add an entry for the 'main' AD host. This
  host will be queried for AD information.
* `config/environment/directory/name` - The name of the Active Directory.
* `config/environment/directory/filter/users/getuser` - The AD query that will be used to find
  a user based on the CN.
* `config/environment/directory/query/groups/artefacts/administrators` - The name of the AD group
  which will be used as administrators on Nexus.
* `config/environment/directory/query/groups/artefacts/developers` - The name of the AD group that
  will be assumed to be developers.
* `config/environment/directory/query/groups/lookupbase` - The AD base that is used for group look ups.
* `config/environment/directory/query/lookupbase` - The AD base that is used for all non-user and
  non-group queries.
* `config/environment/directory/query/users/lookupbase` - The AD base that is used for user look ups.
* `config/environment/directory/users/bindcn` - The fully qualified name of the user that can
  be used to perform Active Directory searches. In general this will be the `Test` user

Finally add the secrets to Vault at the following paths

* `secret/environment/directory/users/bind` - Add the `password` of the bindcn user

### Image provisioning

Once the environment is configured take the following steps to provision the Nexus image

* Download the new image to one the Hyper-V hosts. The open source version of Nexus (that we use)
  cannot be clustered so it only needs to be put on a single host.
* Create a directory for the image and copy the image VHDX file there.
* Create a VM that points to the image VHDX file with the following settings
  * Generation: 2
  * RAM: 4096 Mb minimum. Do *not* use dynamic memory. See the note above for useful suggestions
    for the amount of RAM to allocate. Production machines probably need closer to 8Gb.
  * Network: VM
  * Hard disk: Use existing. Copy the path to the VHDX file
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Set the number of CPUs to 2
  * Attach the additional HDDs
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
  * Disable checkpoints
  * Set the VM to always start
  * Set the VM to shut down on stop
* Set the existing Nexus to read-only mode
  * On the admin page navigate to System -> Nodes -> Enable read-only mode
* Execute a backup on the existing Nexus
  * Run the backup task in System -> Tasks -> backup
  * Make sure the backup file is available in the backup file store
* Get a pre-restore verification list for all the repos you care about
* Stop the existing Nexus
  * Stop the nexus service
    * SSH into the machine and call `sudo systemctl stop nexus`
  * Leave the consul cluster
    * From the machine call `consul leave`
  * Shut the machine down
    * From the machine call `sudo shutdown now`
  * Set the VM to never start
  * Do NOT delete the VM yet
* Start the new VM, it should automatically connect to the correct environment once it has provisioned.
  As it provisions it will also restore the backup. Note that this make take some time as restoring
  backups requires moving large files over the network, un-archiving them and restoring the files
  in the correct locations
* Provide the machine with credentials for Consul-Template so that it can configure the Nexus instance
  with the appropriate secrets
  * Wait for it to apply the Active Directory configuration and then log in.
  * Make sure that it has pulled in the latest backup and restored it.
* Get a post-restore verification list for all the repos you care about and compare that list to
  the previously made list. If there are differences it might be good to revert the change.
* Once the new Nexus instance is up and running delete the old VM

## Usage

Once the resource is started and provided with the correct permissions to retrieve information
from [Vault](https://vaultproject.io) it will automatically become the active Nexus server. The
UI for Nexus can be found via the portal page on `http://<PORTAL_HOST_NAME>/artefacts`.
