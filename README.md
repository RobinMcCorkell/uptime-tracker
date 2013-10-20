Uptime Tracker
==============

An uptime tracker for Linux systems, version 2.8

Copyright (c) 2012-2013 Robin McCorkell

Licensed under the MIT License - see LICENSE

This program tracks the uptime of a running Linux system, storing it in a file
on disk. This program can also be used to parse that file, giving a detailed
overview of the uptime of a system, along with the exact times of bootup and
shutdown.

Usage
-----

    Usage: $0 [options] command

    Options:
      -n, --natural            output in full date format
      -r, --raw                default, output in UNIX timestamp
      -p, --percent            output downtime as percentage
          --file=[file]        store uptime data in [file]
          --time-start=[time]  only use entries newer than [time]
          --time-end=[time]    only use entries older than [time]

    Commands:
      update          update uptime file with latest information
      reset           clear downtime data and restart uptime counter
      auto [n]        run forever, updating automatically every [n] seconds
      start-time      return first recorded boot time
      end-time        return last recorded update time
      downtime        return downtime since first recorded boot
      uptime          return uptime since first recorded boot
      all-data        return array of boottime,shutdowntime separated by newline
      summary         return table of all information, in a human readable format
      state           print relative state changes (useful for graphing)

Options
-------

### Output format ###

The output format of many of the commands can be set to natural
(human-readable dates/times), raw (UNIX seconds) or percentage. Some commands
only accept some of the available formats. The default is raw, except for the
'summary' command, which uses the natural format.

* 'start-time' will only output in the natural and raw formats
* 'end-time' will only output in the natural and raw formats
* 'downtime' will output in all formats
* 'uptime' will output in all formats
* 'summary' will only output in the natural and raw formats

### Time range ###

The time range for the output to show defaults to the first recorded time and
the latest update time, for the start and end respectively. However, this can
be set by the --time-start and --time-end options.
