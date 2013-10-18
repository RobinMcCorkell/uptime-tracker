Uptime Tracker
==============

An uptime tracker for Linux systems
Version 2.7

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
