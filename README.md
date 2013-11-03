Uptime Tracker
==============

An uptime tracker for Linux systems, version 3.0

Copyright (c) 2012-2013 Robin McCorkell

Licensed under the MIT License - see LICENSE

This program tracks the uptime of a running Linux system, storing it in a file
on disk. This program can also be used to parse that file, giving a detailed
overview of the uptime of a system, along with the exact times of bootup and
shutdown.

Usage
-----

    Usage: uptime-tracker [options] command [<parameters>]

    Options:
      -n, --natural            default, output in full date format
      -r, --raw                output in UNIX timestamp
      -p, --percent            output downtime as percentage
          --file=[file]        store uptime data in [file]
          --time-start=[time]  only use entries newer than [time]
          --time-end=[time]    only use entries older than [time]

    Commands:
      update        update uptime file with latest information
      reset         clear downtime data and restart uptime counter
      auto [n]      run forever, updating automatically every [n] seconds
      start-time    print first recorded boot time
      end-time      print last recorded update time
      downtime      print downtime since first recorded boot
      uptime        print uptime since first recorded boot
      summary       print table of all information, in a human readable format
      raw <format>  print raw data, in one of the available formats
      reason <cmd>  manage reasons for shutdowns

    Raw formats:
      all-data      all available data for each session
      state         relative time spent in each state
    
	Reasons:
	  get <id>       get reason for session <id>
      set <id> <str> set reason for session <id> to <str>

Options
-------

### Output format ###

The output format of many of the commands can be set to natural
(human-readable dates/times), raw (UNIX seconds) or percentage. Some commands
only accept some of the available formats. The default is natural.

* 'start-time' will only output in the natural and raw formats
* 'end-time' will only output in the natural and raw formats
* 'downtime' will output in all formats
* 'uptime' will output in all formats
* 'summary' will only output in the natural and raw formats
* 'raw' is dependent on the format

### Time range ###

The time range for the output to show defaults to the first recorded time and
the latest update time, for the start and end respectively. However, this can
be set by the --time-start and --time-end options.

### Raw formats ###

The 'raw' command requires a raw format to be specified. Many of these formats
will only output in the raw output format, but some may implement others.

* 'all-data' will output all the data available, displaying the boot time, end
  time and fail status for each session in the UNIX seconds format. Each
  session is on its own line, and each line takes the format 'boottime,endtime'
  with a '*' appended if this session encountered a power failure.
* 'state' will output the relative time spent in the up or down state. Output
  starts with the initial state (the state for the first time), on one line.
  The next line contains the time spent in the initial state. The following
  line contains the time spent in the inverse state - up if the previous state
  was down, and down if the previous state was up. This pattern continues for
  each line. This format can be in the raw output format, where the relative
  times are the number of seconds in each state, or the percentage output
  format, where the relative times are a percentage of the time for the entire
  listing.

### Reasons ###

The 'reason' command can be used to specify reasons for shutdowns. Although
this has no effect on the output of the other commands, it provides a useful
means of 'tagging' a particular session with a message.

* 'get' will output the reason attached to a particular session, specified by
  the first parameter passed to it
* 'set' will set the reason for a session. The session ID is specified by the
  first parameter, and the second parameter specifies the string to be attached
