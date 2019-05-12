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

## Central Server Setup

The central server must have a working [Redis](http://redis.io/) server running that has the ability to accept incoming
connections. It is highly recommended that the server be running a version of Linux as this is the primary operating
system supported by Redis. If desired, a build of Redis exists for [Windows](https://github.com/MSOpenTech/redis).
However, this section will focus on getting Redis running in an Ubuntu environment.
  
Note, in the rest of this document the central server will be referenced as Gru-svr.

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

To test whether you can access your new Redis server from R, open a new R session from any computer that has network
access to Gru-svr and run the following test:

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

# Minion Workers

The core of this system is the workers. Each worker connects to a message queue and then waits until a job is ready to
be processed. When it receives a job, it processes it and pushes the results to the provided results queue. It then
connects back to the jobs queue and waits to receive another job to begin the cycle again. Whenever a job is started,
the message it received is also saved in a queue unique to the worker to provide the ability to recover in the event
that the worker goes down in the middle of processing. Recovery functionality has not been added at this time.

To start a worker on a server, make sure the server can connect to the central Redis server. Then simply run the
following command.

```R
library(rminions)
minionWorker(host = "Gru-svr")
```

This will connect to the central Redis server and wait for jobs to be pushed to the default `jobsQueue`. This will
block the running process so it is recommended that you background the process or create an Upstart job to begin the
worker. The recommended number of workers per server is the number of CPU cores or threads plus 2.

# Bundling and Pushing Jobs

The workers have been written to run any task as long as it is bundled into a function. The job that is passed to the
worker should be a list with the following keys: `Function`, `Parameters`, `ResultsQueue`, `ErrorQueue`, and optionally,
`Packages`. The `Function` key contains the function that the worker will execute. This function should contain all the
logic that is required for the job and it should accept one argument, denoted here as `params`, a list object. Any
arguments the function needs should be accessed as keys in the `params` object. `Function` can return anything that a
regular function will return. The returned value or object will be stored in the message queue identified by the
`ResultsQueue` key. The `Parameters` key should be a list containing any arguments that `Function` needs to be executed
with and will be passed in as `params`. `ErrorQueue` should be a message queue where any error-related information is
stored. Finally, the `Packages` key is optional but if supplied should contain a vector of one or more strings with the
names of packages to be loaded before executing `Function`.

For complex jobs that require calls to multiple custom functions, it is recommended you bundle them into a package and
have a controller function which contains the logic that would usually be placed in a script. This controller function
is what will be passed to the workers.

Since this package was developed to satisfy a need to replicate jobs numerous times, several helper functions have been
provided to assist in quickly pushing multiple jobs to a queue. These are the `*lplyQueueJobs` functions, where `*` is
`a`, `d`, and `l`. These functions accept an object to be iterated over, the function for the worker to execute, the
parameters it needs to run, and the response and error queue. These functions also accept a function used to build the
job message in the above list format. By default they call a default builder function whose only task is to accept the
inputs and return the formatted list. If you require calculations or data wrangling to arrive at the inputs to your
function, then you will need to write a custom job builder function and pass it in the `buildJobsList` parameter.
 
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

In this example, `buildMoonSimJobsList` generates distributional parameters and returns the job lists that
`alplyQueueJobs` will queue. The workers then pick up these jobs and execute `stealTheMoonSim` with the parameters
generated in `buildMoonSimJobsList`.

# TODO

These are things that need to be completed for v2.0.0.

1. Convert `minionWorker` to execute functions from packages rather than execute arbitrary function definitions.
2. The `rredis` package is deprecated. Convert to a newer package such as `redux`, which is recommended by the creator
of `rredis`.
3. Update documentation.
4. Figure out how to make redis serialization optional so it will be easier for non-R clients to send and receive
messages.
5. Add docker file and make that recommended deployment method in README, instead of the Upstart method.
6. Update changelog.