# zipkin-mux
Zipkin-mux is a read only proxy for multi-cluster [Zipkin](https://github.com/openzipkin/zipkin/) deployments.
It exposes the same UI and API as Zipkin and takes care of querying all Zipkin clusters and merge their responses.

> #### Disclaimer
> Right now, this is mostly a Proof Of Concept. The code works and is probably performant enough to be used in
> production, but it comes with very limited service discovery and test coverage. If people are interested in
> using it, please open Issues, PRs or talk to me on [gitter](https://gitter.im/openzipkin/zipkin) and we can
> make this production ready.

## Why would I need this?
If you're running a single Zipkin cluster with a single shared storage (most common case), you don't need this
and should just use Zipkin directly. There are however use cases where it's useful to run multiple Zipkin
clusters, each with its own separate storage.

For example, you might want to run a different Zipkin cluster per AWS Availability Zone. This is very useful if
you're ingesting a lot of Zipkin spans since AWS charges you for cross AZ traffic (but intra AZ traffic is free).
Your web server requests however will probably cross AZs, so you'd end up with half of the trace in one
cluster and half in another.

That means that the Zipkin UI must query all the clusters and merge all the partial traces together. This will
incur in network charges, but given that Zipkin traffic is write heavy those costs are minimal.

## Architecture
First of all, you should configure you DNS such that queries to zipkin.yourcompany.com or whatever url you want
to use point to zipkin-mux.

#### UI
It'd be hard to modify the Zipkin UI to use a different url / domain for API queries. You'd need to make sure
browsers won't block your cross-domain requests and you'd need to special-case the javascript code to support
a different API domain.

It's much easier to simply have zipkin-mux serve the UI, that way you'll be able to use stock Zipkin without
having to make any change to its code. Zipkin's UI is a simple collection of static HTML and a bunch of JS and
CSS files. There'd be no point in shipping that with zipkin-mux when we can just get it from any of the Zipkin
servers.

If you look at the [nginx.conf](https://github.com/drolando/zipkin-mux/blob/master/nginx.conf#L34) file, you'll
see that requests for `/` or `/zipkin/*` are simply proxied to one of the Zipkin servers. It doesn't really
matter which one you choose as they'll hopefully all be of the same version.

                                                                   ┌──────────────────────────────────────┐
                                                                   │              uswest1a                │
                                                                   │   ┌────────┐          ┌─────────┐    │
                                                      GET /zipkin/ │   │        │          │         │    │
                                ┌──────────┐             ┌─────────┼──▶│ Zipkin │◁────────▷│Cassandra│    │
                                │          │             │         │   │        │          │         │    │
                                │          │             │         │   └────────┘          └─────────┘    │
    ┌────────┐                  │          │             │         │                                      │
    │        │  GET /zipkin/    │          │             │         └──────────────────────────────────────┘
    │  User  │━━━━━━━━━━━━━━━━━▶│zipkin-mux│─────────────┘                                                 
    │        │                  │          │                       ┌──────────────────────────────────────┐
    └────────┘                  │          │                       │              uswest1b                │
                                │          │                       │   ┌────────┐           ┌─────────┐   │
                                │          │                       │   │        │           │         │   │
                                └──────────┘                       │   │ Zipkin │◁─────────▷│Cassandra│   │
                                                                   │   │        │           │         │   │
                                                                   │   └────────┘           └─────────┘   │
                                                                   │                                      │
                                                                   └──────────────────────────────────────┘
                                                                                                           
In case of API requests though, we need to add some extra logic. All api calls start with `/zipkin/api/`, so
it's very easy to intercept them. When we receive one of those we need to iterate over all the different
clusters, pick one server from each and send the same request to it.

All read API endpoints return a JSON list of objects, which makes it super easy to merge the responses. We
only need to json decode them, append everything to the same result list, re-encode that list and send it
back as response.
                                                                                                           
                                                                   ┌──────────────────────────────────────┐
                                                                   │              uswest1a                │
                                                         GET       │   ┌────────┐          ┌─────────┐    │
                                                  /api/v2/trace/foo│   │        │          │         │    │
                                ┌──────────┐             ┌─────────┼──▶│ Zipkin │◁────────▷│Cassandra│    │
                                │          │             │         │   │        │          │         │    │
                                │          │             │         │   └────────┘          └─────────┘    │
    ┌────────┐       GET        │          │             │         │                                      │
    │        │/api/v2/trace/foo │          │             │         └──────────────────────────────────────┘
    │  User  │━━━━━━━━━━━━━━━━━▶│zipkin-mux│─────────────┤                                                 
    │        │                  │          │             │         ┌──────────────────────────────────────┐
    └────────┘                  │          │             │         │              uswest1b                │
                                │          │             │         │   ┌────────┐           ┌─────────┐   │
                                │          │             │         │   │        │           │         │   │
                                └──────────┘             └─────────┼──▶│ Zipkin │◁─────────▷│Cassandra│   │
                                                         GET       │   │        │           │         │   │
                                                  /api/v2/trace/foo│   └────────┘           └─────────┘   │
                                                                   │                                      │
                                                                   └──────────────────────────────────────┘

## How to run it locally
Running `make run` will start a local instance of zipkin-mux, together with 2 zipkin servers and related
cassandra instance. Everything runs in `docker`, so you'll need to install it first.

The UI can be accessed at `localhost:9411`, however by default there will be no traces in the storage. To
generate one, run `make gen-trace`. This will create a single trace with 4 spans and save 2 of those in each
zipkin instance to simulate different clusters.

You'll then be able to search for the trace in the UI and visualize it.

## Why openresty and not python, java, ruby, etc?
This service code is very simple and not CPU intensive. Most of its tasks are to proxy requests around, which
nginx is great at. Also, nginx & openresty use an async event based engine that allows it to process many
requests in parallel with minimal overhead. This means you could run zipkin-mux in production with a fraction
of the memory and cpu requirements of a similar java service.
