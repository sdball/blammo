# Blammo

Let's get log contents via REST!

"It's LOG from Blammo!"

![Blammo Logo](./images/logo.png)

## Goal

Provide log file contents via REST

- Lines from the log file will be returned newest–oldest
  - Assume log files will have the newest lines at the end of the file
- Provide contents via REST
  - arguments
    - filename
    - (optional) N lines
    - (optional) text filtering
- Be performant for files >1GB in size

## Stretch

- A basic UI (beyond a curl text API)
- A primary server that requests logs from secondary servers
  - protocol between primary–secondary does not have to be REST

## Running Blammo

- Have Elixir installed: I recommend using [mise](https://mise.jdx.dev/)

```
mise plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
mise plugin install elixir https://github.com/glossia/mise-elixir.git
mise install elixir
```

- clone this repo
- cd into the repo directory
- Run `mix setup` to install and setup dependencies
- Run `mix gen.sample_logs --log-size 10MB` to generate a small sample log
- Run `mix phx.server` to run the HTTP server

With the server running you can query the API for log lines! (The development server automatically reads from the sample_logs directory)

```
# last 12 lines of the log file
curl http://localhost:4000/api/logs\?filename\=sample.10MB.log\&lines\=12

# last 12 instances of xyzzy
curl http://localhost:4000/api/logs\?filename\=sample.10MB.log\&lines\=12\&filter=xyzzy
```

It's log log log!

## Further Reading

- [Design](./DESIGN.md)
