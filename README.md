# GeoIP

This service is based on the original [Apilayer's Freegeoip project](https://github.com/apilayer/freegeoip), with a little modifications.

## GeoIP

GeoIP service primary function is to do geolocation based on IP. It could help detect the city, the country, and so on and so forth.

## Technical overview

There are 3 separate, inter-related parts of VGEOIP:

- `apiserver` package (located at `freegreoip/apiserver`)
- `main` package (located at `freegeoip/cmd/freegeoip`)
- `freegeoip` package (located at the root folder)

The `main` package is the point of entry. This is definitely the package that gets compiled. This package however, is just a _gate_ into `apiserver`, so the actual workload is basically not in the `main` package but in `apiserver.Run()`.

Things that `apiserver` package does:

| Description | File |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| - Read configuration from env. var.<br/>- Setup the configuration object.<br/>- Some of interesting envvar:newrelic config, where to log, DB update interval | config.go |
| - Record database events to prometheus.<br/>- Record country code of the clients to prometheus - Record IP versions counter to prometheus.<br/>- Record the number of active client per protocol to prometheus | metrics.go |
| - Essentially running the server (using TLS/not) | main.go |
| - Return data in CSV/JSON/XML format upon request.<br/>- Perform IP lookup.<br/>- Downloading the lookup database.<br/>- Performing rate limiting (if configured). | api.go |

The core component of the `apiserver` package is the `NewConfig` and `NewHandler` functions that both create a `Config` and `apiHandler` struct respectively. `apiHandler` is a struct that consist the following structure:

```go
type apiHandler struct {
  db    *freegeoip.DB
  conf  *Config
  cors  *cors.Cors
  nrapp newrelic.Application
}
```

However, `NewHandler` does not just create `apiHandler` struct, it actually also create the multiplexer from which all requests come in contact with. So, every single web request is handled by this multiplexer.

However, before it can serve any request, `NewHandler` turns out will also attempt to download a database using the `openDB` function of the same package (`apiserver`).  When the system unable to setup the handler (for a host of reasons, one of which being unable to download the database), the system will fatally exit.

`openDB` basically will download a databse if it doesn't have a copy yet in the local filesystem. And, if we have the license and user ID, it will setup a special configuration that will help us later on to download the paid version of the database.

`openDB` eventually is calling `OpenURL` function of the `freegeoip` package (only associated with `db.go`). This package contains routines that help with:

- Downloading the database
- Opening the database, and setting up the reader/data-access object
- Watching the file when it's created/modified and notify it through appropriate channel back up
- Automatically update the database upon a due time/`backoff` period (default: 1 day)
- Performing `Lookup` of an IP

Once `OpenURL` is called, an `autoUpdate` function will kick in automatically in the background using a goroutine (similar to a Ruby's thread but lightweight). It will check if a newer database exist by checking the `X-Database-MD5` and the file's size.

As we might already guess, there are two kinds of database: the paid version and the free version. If we run the service without the paid license, it will never send a request to download the paid version of the database.
