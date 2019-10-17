# Update In Progress

**The current state of the master branch of this project is that it contains many changes that will be in v2.0.0 of the
rminions package. However, as this version is not yet complete this branch is very much an update (or work) in
progress. Previous versions of this package have been tagged appropriately in this repo and a v2.0.0 tag will be
added whenever the new version is ready.**

# rminions

`rminions` is a package that provides functions to assist in setting up an environment for quickly running jobs across
any number of servers. This is accomplished by having a central control server which is in charge of accepting jobs and
distributing them among workers. The passing of jobs and results is handled via Redis message queues.

## Installation

In order to install the `rminions` package you will first need to install the `devtools` package.

```R
install.packages("devtools")
```

From here you can install the `rminions` package directly from GitHub.

```R
devtools::install_github("PieceMaker/rminions")
```

## Quickstart

A Docker Compose file has been provided in this repository that will automatically start Redis and workers. It assumes
the the Dockerfile in this repository has been built and tagged as `rminion`. To start a single instance of the server
and 4 workers, change to the directory the `docker-compose.yaml` is located and simply run the following:

```bash
docker-compose up -d --scale redis=1 --scale worker=4
```

It should output the following:

```bash
Creating network "rminions_default" with the default driver
Creating rminions_redis_1 ... done
Creating rminions_worker_1 ... done
Creating rminions_worker_2 ... done
Creating rminions_worker_3 ... done
Creating rminions_worker_4 ... done
```

The `-d` flag will ensure all instances are run in the background and the `--scale` options tell docker-compose how
many of each service to run. The redis service exposes port 6379 so others can connect to the same instance.

You can now test the workers by running the example in [Message Functions](#message-functions).

To stop the workers, simply run in the same directory

```bash
docker-compose down
```

## Central Server Setup

The central server must have a working [Redis](http://redis.io/) server running that has the ability to accept incoming
connections. It is highly recommended that you use the Redis Docker image for your server. This section will document
both using a Dockerized Redis server, as well as manual setup.
  
Note, in the rest of this document the central server will be referenced as Gru-svr.

### Docker

This section assumes you have Docker installed and running. If you do not, then first follow the
[Docker installation instructions](https://docs.docker.com/install/).

To pull down the latest Redis Docker image, run the following command:

```bash
docker pull redis:latest
```

Once you have the image locally, simply start your server by running the following command:

```bash
docker run -d -p 6379:6379 --restart=unless-stopped --name redis-server redis
```

### Manual Setup

If you wish to manually setup your Redis server, it is highly recommended that the server be running a version of Linux
as this is the primary operating system supported by Redis. If desired, a build of Redis exists for
[Windows](https://github.com/MSOpenTech/redis). This section will focus on getting Redis running in an Ubuntu
environment.

First install Redis.

```bash
sudo apt-get install redis-server
```

Once Redis is installed, it will likely only accept connections originating from the localhost. To change this you need
to edit the Redis config file located at `/etc/redis/redis.conf`. Navigate to the section that is summarized below:

```
# By default Redis listens for connections for all the network interfaces
# ...
#
# Examples:
#
# bind 192.168.1.100 10.0.0.1
bind 127.0.0.1
```

If you are willing to accept connections originating from all addresses, simply comment out the last line. If you have
special requirements for addresses, add a new bind line and specify whatever rules you desire.

Once you have finished updating the IP address rules, save the file and restart the Redis service.

```bash
sudo service redis-server restart
```

### Testing Redis

To test whether you can access your new Redis server from R, open a new R session from any computer that has network
access to Gru-svr and run the following test:

```R
library(redux)
conn <- hiredis(host = 'Gru-svr')
conn$RPUSH("testKey", object_to_bin(list(x = 1, y = 2)))
# [1] 1
result <- conn$RPOP('testKey')
bin_to_object(result)
# $x
# [1] 1
#
# $y
# [1] 2
```

If the result of your `bin_to_object(result)` command was to print the list you pushed, then your server is now working.

# Minion Workers

The core of this system is the workers. Each worker connects to a message queue and then waits until a job is ready to
be processed. When it receives a job, it processes it and pushes the results to the provided results queue. It then
connects back to the jobs queue and waits to receive another job to begin the cycle again. The recommended number of
workers per server is the number of CPU cores or threads plus 2.

Although you can run a worker by launching it inside of a separate R process on the worker server, it is recommended
that you instead make use of the provided Dockerfile to build an image that will run one worker for each instance of
the image run.

## Docker

This project contains a Dockerfile that will install the appropriate Debian package to run the rminions package,
will install the R package devtools, will install the rminions package, and finally will execute a shell script
that will start a worker. This worker looks for the environment variables `REDIS`, `PORT`, `QUEUE`, and `USEJSON`
to know what server to connect to and what queue to listen to. If `REDIS` is not exported, then it will default to
`"localhost"`. Similarly, if `QUEUE` is not exported, then it will default to `"jobsQueue"`. Finally, `USEJSON`
is either the string "true" or "false".

To build the Docker image, clone this project locally and change directory into it. Then run the following:

```bash
docker build -t minion-worker .
```

This will build the image locally and tag it as "minion-worker".

Since we are referring to our Redis server as Gru-svr, we need to set the environment variable appropriately:

```bash
export REDIS="Gru-svr"
```

We are now ready to run the Dockerized worker.

```bash
docker run --rm minion-worker
```

You should now have a worker running that is connected to the central Redis server and awaiting requests on the
queue `"jobsQueue"`.

## R Process

To start a worker on a server via R process instead of Docker, make sure the server can connect to the central
Redis server and that the rminions package has been installed. Then simply run the following command.

```R
library(rminions)
minionWorker(host = "Gru-svr")
```

This will connect to the central Redis server and wait for jobs to be pushed to the default `"jobsQueue"`. Note this
will block the running process.

# Bundling and Pushing Jobs

The first version of the rminions package required anonymous function definitions to be passed to the worker. Even if
you wanted to call a simple native R function, you still had to pass an anonymous function that wrapped the call to the
R function. This was archaic, tough to deal with, and introduced a lot of room for error. The new version of this
package scraps this and now requires any function you want a worker to run to be defined in a package.

## Job Definition

A job requires the following four parameters: `package`, `func`, `parameters`, and `resultsQueue`. A job can also have
the following optional parameter: `errorQueue`. `package` is the name of the package containing the function you want
the worker to run and `func` is the name of said function. `parameters` will be addressed separately in the next
subsection. `resultsQueue` is the queue to send results to. `errorQueue` can be defined separately if you wish for
errors to be diverted to a different queue. If `errorQueue` is not defined, then errors will be returned to
`resultsQueue`.

### Parameters

To allow minion workers to be accessed from languages other than R, they can accept parameters in two formats:
R lists and JSON. Currently a worker can accept one or the other, not both. This choice is made by setting the `useJSON`
flag at worker startup.

Suppose we want to calculate the 0, 0.25, 0.50, 0.75, and 1 quantiles for a normal distribution with a mean of 100 and
standard deviation of 10. Then `package` would be `"stats"` and `func` would be `"qnorm"`. The parameter would depend
on the `useJSON` flag.

If `useJSON` is false, then `parameters` would be a named list where the entries match the parameters of `func`, or in
this case `"qnorm"`.

```R
list(
    p = c(0, 0.25, 0.5, 0.75, 1),
    mean = 100,
    sd = 10
)
```

If `useJSON` is true, then `parameters` would be a named JSON object, again where the entries match the parameters of
`func`.

```javascript
{
    "p": [0, 0.25, 0.5, 0.75, 1],
    "mean": 100,
    "sd": 10
}
```

Due to the serialization made available via `redux::object_to_bin` and `redux::bin_to_object`, R data types can be
passed in the `parameters` list when `useJSON` is false, but only string and numeric types can be used when `useJSON`
is true.

Note a helper function, `sendMessage`, has been included in this package that will automatically construct a request
based on the inputs. It is recommended you use this function when making requests in R.

## Results Messages

Results messages will have all of the properties that were passed in the original job definition. They will also have
the `status` property and will have either the `results` or the `error` property, depending on the status.

### Status

`status` will be one of three strings: `"succeeded"`, `"failed"`, or `"catastrophic"`.

#### Succeeded

If `status` is `"succeeded"`, then the job ran successfully and the results of the function execution are stored in
the response in the `results` key.

#### Failed

If `status` is `"failed"`, then either there was an error validating the job or there was an error executing the
requested function. Refer to the `error` key of the response message for more information.

#### Catastrophic

If `status` is "catastrophic", then an error somehow got through the first set of error handling built into the minion
worker. See `error` key of the response message for more information. Due to their unexpected nature, jobs resulting
in a catastrophic status will not be placed in either `resultsQueue` or `errorQueue`, but rather a special queue
called `"unhandledErrors"`.

Note, if you receive a `"catastrophic"` status, please open an issue as this may be indicative of a bug in the
package.

## Blacklist and Whitelist

By default, `rminions` implements a blacklist to try to block functions that can pose a security threat. This
list is stored in the internal function `blacklist`. The function `minionWorker` also allows you to configure
a whitelist which is recommended. If a whitelist is implemented, then the blacklist will be ignored.

A whitelist can be configured in two ways: defining a list or specifying the path to a JSON file. A whitelist
should contain package names as the keys and arrays (or vectors) of strings giving the names of the functions
in the given package that are being allowed. If a whitelist is configured and a request is made for a function
that is not in the whitelist, then the request will be rejected.

### Example

The following is an R list whitelist:

```R
list(
    stealTheMoon = "simulateTrip",
    stats = c("dnorm", "pnorm", "qnorm", "rnorm")
)
```

The following is the equivalent whitelist defined using JSON:

```JSON
{
    "stealTheMoon": ["simulateTrip"],
    "stats": ["dnorm", "pnorm", "qnorm", "rnorm"]
}
```

## Message Functions

Two functions are provided to facilitate sending and fetching single messages. These are `sendMessage` and
`getMessage`. `sendMessage` can be used to make an initial request of a worker and `getMessage` can be used to get
the results of the request.

### Example

Referring back to our `"qnorm"` example above, we could make the request (using native R types) by running the
following:

```R
redisConn <- redux::hiredis(host = 'Gru-svr')
sendMessage(
    conn = redisConn,
    package = 'stats',
    func = 'qnorm',
    p = c(0, 0.25, 0.5, 0.75, 1),
    mean = 100,
    sd = 10
)
```

By default, `sendMessage` assumes JSON will not be used for messages and automatically serializes the request.
Once this function is executed, the message will be pushed to the central server and the first worker in line
will get the request and execute the function with the specified parameters. Once the execution has been
completed, the results will be sent back on the appropriate queue. Assuming the execution was a success, the
results can be fetched by running the following (assuming `redisConn` has not been closed):

```R
results <- getMessage(
    conn = redisConn,
    queue = 'resultsQueue'
)
```
 
# Steal The Moon Example

This example has moved to the [steal-the-moon](https://github.com/PieceMaker/steal-the-moon) project. It shows how
to extend the Dockerfile built in this repository to add a new custom package and then start a worker that can then
run the new functions.

# TODO

These are things that need to be completed for v2.0.0.

1. ~~Convert `minionWorker` to execute functions from packages rather than execute arbitrary function definitions.~~
2. ~~The `rredis` package is deprecated. Convert to a newer package such as `redux`, which is recommended by the creator
of `rredis`.~~
3. Update documentation.
4. ~~Figure out how to make redis serialization optional so it will be easier for non-R clients to send and receive
messages.~~
5. ~~Add docker file and make that recommended deployment method in README, instead of the Upstart method.~~
6. Update changelog.
    * Add removal of `BRPOPLPUSH` command in favor of `BRPOP` in worker.
7. ~~Convert section for testing Redis from rredis to redux.~~
8. With v2.0.0 deployment, publish Docker image to hub.docker.com and then add steps to pull it down in Minion Workers
   section.
9. ~~Remove `*lplyQueueJobs` helper functions.~~
