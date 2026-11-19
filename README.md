A simple bash script that pulls the METAR and TAF of a designated airport ICAO code, determines the current moon phase, and formats the data into the header of a plain text journal page. This is designed to run on a headless server that has a default printer setup as a target for lp.

I recommend using cron to schedule this as a daily job. Tested on MacOS and various flavors on Linux.

Make changes as shown in the first couple of lines in the script for your closest airport and to kindly let aviationweather.gov know who's pulling data from their APIs.

```
# Default configuration (Change to your preferred ICAO station ID)
AIRPORT="KJFK"
USER_AGENT="journal-printer/1.0 (+https://github.com/yourusername/yourrepo)"
```
