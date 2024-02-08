# Blammo Design

We have a couple of high level concepts here

- the HTTP server providing the REST API
- the capability to gather logs

The HTTP server is a typical HTTP server, no unusual requirements here. We have to expose a REST API, reject invalid requests, accept valid requests, provide responses.

The capability to gather log lines is a little more interesting. We could largely ignore this concept and simply do calls to the filesystem from every HTTP request. We could even shell out to command line tools like `tail` and `grep` but it might be more interesting to expand this concept.

Expanding on the capability to gather log lines we could cache recently requested log lines, actively maintain caches of all recently written log files, aggregate observations, etc.

As a starting point I think we don't need to create an entirely separate client process that handles log file access. But we can make it a named and structured concept in the REST server. Taking that approach we should be careful both not to leak REST API concepts into the log reader and not to leak log file reading concepts into the REST API.

If we lean more into unblocking requests than we can get into some interesting architecture such as introducing a durable log to hold the actual log file contents. Populating the durable log as log files are written and only serving HTTP responses from the durable log data.

## Blammo Domain Concepts

Blammo currently has these three major domains

- HTTP API (routing, controllers, etc)
- Log Consumer: handles requesting a task which calls Blammo.File and presenting lines or an error value to the HTTP API
- Blammo.File: provides functions that accept a filepath and filtering arguments and return a list of lines fulfilling the request

## High Level Design

![Blammo High Level Design](./images/design.png)

## Security

Of utmost concern is that we are allowing users to specify files on the filesystem. If we aren't careful we could inadvertently expose system files. Of course Blammo is careful and there are automated tests around that edge.

## Choices to Consider

### Reading lines from the end of a file

Blammo has two different modes of reading from the end of the file.

- In filter-first Blammo steps backwards through the file in large chunks to minimize IO blocking. We take this approach because it's entirely possible we may need to filter the entire file to find matching lines.
- In tail-first Blammo reads from the end of the file with an ever-increasing chunk size. We take this approach because we know that the data we need is at the end of the file, we only need to read enough data to get the requested number of lines.

In either approach when Blammo splits each chunk of the file by newlines then discards the first line unless we're at the start of the file.

After reading a chunk then we evaluate…

- If we've reached the beginning of the file: return whatever lines we have gotten.
- If our count matches our requested limit: we're done!
- If our count is less than our limit…
  - filter-first: increase the chunk size (up to a maximum) and read the next chunk
  - tail-first: increase the chunk size and read from the end of the file again

These approaches are reasonably performant but this is absolutely the area of the application to focus on for performance improvements.

It could also well be that any effort on this aspect of the domain is better spent writing a lower level utility for handling file reads, e.g. writing a NIF in Rust.

### Intelligent chunk sizing in the tail-first path

Currently the chunk size we start with is fixed at `65536`. We could introduce a process into the application stack that is asynchronously called with the maximum chunk size needed to satisfy each request. That process could maintain statistical aggregates and provide an optimal chunk size to subsequent requests. That would allow this application to dynamically improve its performance if it finds that it's doing small reads or big reads.

For example if we find that the chunk size almost never needs to increase then it could start providing `32768` or some other smaller starting point. If we find that the chunk size almost always needs to increase then it could start providing the statistical mode of the needed chunk sizes.

We could also assume log lines are a generally consistent length and see how many log lines are in a given chunk; then use that assumption to more intelligently increase the chunk size.

### Filter and then get lines OR Get lines and then filter

Currently Blammo provides functions for either approach. If we have a product decision on how we should tail/filter log files then we may be able to delete a path of code.

If we actually do want to provide both approaches then there is an opportunity to refactor the code paths in `Blammo.LogConsumer` which are largely duplicated at present.

### User selection of files

Currently Blammo allows the user to specify any arbitrary file and, if found in the log path, it will be returned.

An alternative approach would be to have a well known list of allowed log files the user must select. Or possibly to only allow selecting \*.log files.

### Web Interface

Currently the web interface does not get to create or even have access to the spawned Task that gathers log data. It would be an improvement to change the live view to have the task available. Then we could grey out the lines or put up a spinner while the work is happening in the background and populate the contents when the task is complete. Right now our live view simply waits for data which is fine enough when the results are fast but for slow results more user feedback would be nice.

## Performance

Currently Blammo maintains stable memory usage, allows a high number of concurrent requests, and is performant up to reasonable line counts.

e.g.

### filter first

```
hey http://localhost:4000/api/logs/filter-first\?filename\=sample.1GB.log\&lines\=1000\&filter\=xyzzy

Summary:
  Total:	0.3330 secs
  Slowest:	0.1454 secs
  Fastest:	0.0233 secs
  Average:	0.0787 secs
  Requests/sec:	600.6846


Response time histogram:
  0.023 [1]   |■
  0.036 [6]   |■■■■
  0.048 [17]  |■■■■■■■■■■■■
  0.060 [36]  |■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.072 [55]  |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.084 [21]  |■■■■■■■■■■■■■■■
  0.097 [19]  |■■■■■■■■■■■■■■
  0.109 [3]   |■■
  0.121 [4]   |■■■
  0.133 [11]  |■■■■■■■■
  0.145 [27]  |■■■■■■■■■■■■■■■■■■■■


Latency distribution:
  10% in 0.0440 secs
  25% in 0.0578 secs
  50% in 0.0657 secs
  75% in 0.0947 secs
  90% in 0.1363 secs
  95% in 0.1433 secs
  99% in 0.1451 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0008 secs, 0.0233 secs, 0.1454 secs
  DNS-lookup:	0.0004 secs, 0.0000 secs, 0.0022 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0015 secs
  resp wait:	0.0771 secs, 0.0229 secs, 0.1417 secs
  resp read:	0.0008 secs, 0.0002 secs, 0.0095 secs

Status code distribution:
  [200]	200 responses
```

### tail first

```
hey http://localhost:4000/api/logs/tail-first\?filename\=sample.1GB.log\&lines\=1000\&filter\=xyzzy

Summary:
  Total:    0.0948 secs
  Slowest:  0.0346 secs
  Fastest:  0.0119 secs
  Average:  0.0222 secs
  Requests/sec: 2108.7528


Response time histogram:
  0.012 [1]   |■
  0.014 [11]  |■■■■■■■■■■
  0.016 [15]  |■■■■■■■■■■■■■■
  0.019 [27]  |■■■■■■■■■■■■■■■■■■■■■■■■■
  0.021 [43]  |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.023 [28]  |■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.026 [22]  |■■■■■■■■■■■■■■■■■■■■
  0.028 [13]  |■■■■■■■■■■■■
  0.030 [9]   |■■■■■■■■
  0.032 [19]  |■■■■■■■■■■■■■■■■■■
  0.035 [12]  |■■■■■■■■■■■


Latency distribution:
  10% in 0.0156 secs
  25% in 0.0186 secs
  50% in 0.0213 secs
  75% in 0.0263 secs
  90% in 0.0307 secs
  95% in 0.0326 secs
  99% in 0.0332 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0009 secs, 0.0119 secs, 0.0346 secs
  DNS-lookup:	0.0005 secs, 0.0000 secs, 0.0021 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0004 secs
  resp wait:	0.0211 secs, 0.0090 secs, 0.0293 secs
  resp read:	0.0002 secs, 0.0000 secs, 0.0015 secs

Status code distribution:
  [200]	200 responses
```
