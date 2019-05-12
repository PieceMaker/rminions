# rminions

`rminions` is a package that provides functions to assist in setting up an environment for quickly running jobs across any number of servers. This is accomplished by having a central control server which is in charge of accepting jobs and distributing them among workers. The passing of jobs and results is handled via Redis message queues.

This package also contains functions to allow R-level server maintenance on all servers simultaneously. This is accomplished via the Redis PUB/SUB system.

## Installation

In order to install the `rminions` package you will first need to install the `devtools` package.

```R
install.packages("devtools")
```

From here you can install the `rminions` package directly from GitHub.

```R
devtools::install_github("PieceMaker/rminions")
```

## Central Server Setup

The central server must have a working [Redis](http://redis.io/) server running that has the ability to accept incoming connections. It is highly recommended that the server be running a version of Linux as this is the primary operating system supported by Redis. If desired, a build of Redis exists for [Windows](https://github.com/MSOpenTech/redis). However, this section will focus on getting Redis running in an Ubuntu environment.
  
Note, in the rest of this document the central server will be referenced as Gru-svr.

First install Redis.

```bash
sudo apt-get install redis-server
```

Once Redis is installed, it will likely only accept connections originating from the localhost. To change this you need to edit the Redis config file located at `/etc/redis/redis.conf`. Navigate to the section that is summarized below:

```
# By default Redis listens for connections for all the network interfaces
# ...
#
# Examples:
#
# bind 192.168.1.100 10.0.0.1
bind 127.0.0.1
```

If you are willing to accept connections originating from all addresses, simply comment out the last line. If you have special requirements for addresses, add a new bind line and specify whatever rules you desire.

Once you have finished updating the IP address rules, save the file and restart the Redis service.

```bash
sudo service redis-server restart
```

To test whether you can access your new Redis server from R, open a new R session from any computer that has network access to Gru-svr and run the following test:

```R
library(rredis)
conn <- redisConnect("Gru-svr", returnRef = T)
redisRPush("testKey", list(x = 1, y = 2))
# [1] "1"
# attr(,"redis string value")
# TRUE
redisRPop("testKey")
# $x
# [1] 1
#
# $y
# [1] 2
redisClose(conn)
```

If the result of your `redisRPop` command was to print the list you pushed, then your server is now working.

# PUB/SUB Server Maintenance

Unlike message queues, which run on a first-come-first-served basis, Redis has a publish/subscribe (PUB/SUB) system available. Whenever a message is published on a channel, any Redis connection that is subscribed to the channel receives the published message. A connection can be subscribed to any number of channels. Since the PUB/SUB messages can be received by any number of connections, this system has been used to allow R-level server maintenance among all connected (and listening) servers simultaneously. The `minionListener` function has been included in the package for this express purpose.

The `minionListener` is written with the idea that each type of maintenance task will be published on its own channel. To subscribe to channels with the `minionListener`, you need to pass in a function defining a channel and how to handle messages when they are received. This handling definition is a function known as a callback and it will be executed with the published message as the input parameter any time a message is broadcast. The `rminions` package comes with three predefined channel functions, all for installing packages on the servers. These are: `cranPackageChannel()`, `gitHubPackageChannel()`, and `gitPackageChannel()`.

To define a custom channel, you need to define a function that takes a channel name to subscribe to and a channel name where errors will be published. The first part of the function should then define the callback function that handles the contents of the received message. If you wish to publish errors that occur, then you should put a `tryCatch` in your callback and, on error, run a function similar to the following:

```R
    error = function(e) {
        e <- sprintf("An error occurred processing job on channel '%s' on listener for server '%s': %s",
            channel,
            listenerHost,
            e
        )
        rredis::redisSetContext(outputConn)
        rredis::redisPublish(errorChannel, e)
        rredis::redisSetContext(subscribeConn)
    }
```

Redis does not allow both publishing and subscribing on the same channel. Thus, the listener creates two connections and they must be switched in order to publish and then switched again in order to continue monitoring the subscribed channel. Currently `outputConn` and `subscribeConn` have been placed in the global environment and will be accessible as long as the channel definition function is being run as part of the `minionListener`. It is a goal for the near future to get away from using the global environment for connection management and instead pass connections as arguments to the channel definition functions.

Once you have all the channel definition functions you need, you can run the listener. The following example starts the listener and subscribes to the CRAN and GitHub package installation channels.

```R
library(rminions)
minionListener(host = "Gru-svr", channels = list(cranPackageChannel(), gitHubPackageChannel()))
```

Once the listener is running it will block the running process so it is recommended that you background the process or create an Upstart job to begin the listener in your working environment.

To test server maintenance using this system, run the following in a new R process, preferably on a computer or server that is not running the minion listener. This example will install the `data.table` package from CRAN.

```R
library(rredis)
conn <- redisConnect("Gru-svr", returnRef = T)
redisPublish("cranPackage", jsonlite::serializeJSON(list(packageName = "data.table")))
redisClose(conn)
```

You should see install information in the process running the listener and in the listener log file.

If you wish to monitor any errors that occur while handling published messages, subscribe to the error channel(s) that were used in the channel definitions. The following will monitor the default error channel.

```R
library(rredis)
conn <- redisConnect("Gru-svr", returnRef = T)
errorChannel <- function(message) {
    print(message)
}
redisSubscribe("errorChannel")
while(1) {
    redisMonitorChannels()
}
```

# Minion Workers

The core of this system is the workers. Each worker connects to a message queue and then waits until a job is ready to be processed. When it receives a job, it processes it and pushes the results to the provided results queue. It then connects back to the jobs queue and waits to receive another job to begin the cycle again. Whenever a job is started, the message it received is also saved in a queue unique to the worker to provide the ability to recover in the event that the worker goes down in the middle of processing. Recovery functionality has not been added at this time.

To start a worker on a server, make sure the server can connect to the central Redis server. Then simply run the following command.

```R
library(rminions)
minionWorker(host = "Gru-svr")
```

This will connect to the central Redis server and wait for jobs to be pushed to the default `jobsQueue`. This will block the running process so it is recommended that you background the process or create an Upstart job to begin the worker. The recommended number of workers per server is the number of CPU cores or threads plus 2.

# Bundling and Pushing Jobs

The workers have been written to run any task as long as it is bundled into a function. The job that is passed to the worker should be a list with the following keys: `Function`, `Parameters`, `ResultsQueue`, `ErrorQueue`, and optionally, `Packages`. The `Function` key contains the function that the worker will execute. This function should contain all the logic that is required for the job and it should accept one argument, denoted here as `params`, a list object. Any arguments the function needs should be accessed as keys in the `params` object. `Function` can return anything that a regular function will return. The returned value or object will be stored in the message queue identified by the `ResultsQueue` key. The `Parameters` key should be a list containing any arguments that `Function` needs to be executed with and will be passed in as `params`. `ErrorQueue` should be a message queue where any error-related information is stored. Finally, the `Packages` key is optional but if supplied should contain a vector of one or more strings with the names of packages to be loaded before executing `Function`.

For complex jobs that require calls to multiple custom functions, it is recommended you bundle them into a package and have a controller function which contains the logic that would usually be placed in a script. This controller function is what will be passed to the workers.

Since this package was developed to satisfy a need to replicate jobs numerous times, several helper functions have been provided to assist in quickly pushing multiple jobs to a queue. These are the `*lplyQueueJobs` functions, where `*` is `a`, `d`, and `l`. These functions accept an object to be iterated over, the function for the worker to execute, the parameters it needs to run, and the response and error queue. These functions also accept a function used to build the job message in the above list format. By default they call a default builder function whose only task is to accept the inputs and return the formatted list. If you require calculations or data wrangling to arrive at the inputs to your function, then you will need to write a custom job builder function and pass it in the `buildJobsList` parameter.
 
# Steal The Moon Example

An example has been included with this package. It can be run with the following code:

```R
library(rminions)
source('./buildMoonSimJobsList.R')
source('./stealTheMoonSim.R')

alplyQueueJobs(
    host = 'Gru-svr',
    iter = c(1:10000),
    margins = 1,
    func = stealTheMoonSim,
    buildJobsList = buildMoonSimJobsList,
    resultsQueue = 'stealTheMoonSim',
    errorQueue = 'stealTheMoonSimErrors'
)
```

In this example, `buildMoonSimJobsList` generates distributional parameters and returns the job lists that `alplyQueueJobs` will queue. The workers then pick up these jobs and execute `stealTheMoonSim` with the parameters generated in `buildMoonSimJobsList`.

# Upstart

As was mentioned earlier in the README, Upstart can be used to automatically launch workers whenever a server is brought online. Below are some sample scripts that start one listener and ten workers on the server. The directories have been placed as comments at the top of each script for illustrative purposes only and may be changed for your implementation.

```bash
# /etc/init/rminions.conf

description "Spawn R minion workers and listener"
 
start on filesystem and static-network-up
 
pre-start script
    for inst in $(seq 10)
    do
        start minion-worker id=$inst
    done
 
    start minion-listener id=1
end script
 
post-stop script
    for inst in $(initctl list | grep "^minion-worker " | awk '{print $2}' | tr -d ')' | tr -d '(')
    do
        stop minion-worker id=$inst
    done
 
    stop minion-listener id=1
end script
```

```bash
# /etc/init/minion-listener.conf

description "R Minion Listener"
 
instance $id
 
console log
 
respawn
exec start-stop-daemon --start --make-pidfile --pidfile /run/minionListener$id.pid --exec /usr/bin/R CMD BATCH /usr/local/lib/R/site-library/launchMinionListener.R /var/log/rminions/minionListener$id.log
```

```bash
# /etc/init/minion-worker.conf

description "R Minion Worker"
 
instance $id
 
console log
 
respawn
exec start-stop-daemon --start --make-pidfile --pidfile /run/minionWorker$id.pid --exec /usr/bin/R CMD BATCH /usr/local/lib/R/site-library/launchMinionWorker.R /var/log/rminions/minionWorker$id.log
```

```R
# /usr/local/lib/R/site-library/launchMinionListener.R

library(rminions)

minionListener(host = "Gru-svr", channels = list(cranPackageChannel(), gitHubPackageChannel(), gitPackageChannel()))
```

```R
# /usr/local/lib/R/site-library/launchMinionWorker.R

library(rminions)
 
minionWorker(host = "Gru-svr")
```

To manually start or stop the listener and workers, simply run the following command (choosing one of start or stop):

```bash
sudo start/stop rminions
```