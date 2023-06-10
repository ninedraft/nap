# nap

`sleep` alternative that supports sub-second durations and prints time remaining periodically.
Written in zig to learn the language.

## Usage

```
nap [-h] <duration>


 -h, --help      print this help message and exit
 <duration>      duration to sleep for, in the format of 1h2m3s4ms5us6ns

 examples:
   nap 1h2m3s4ms5us6ns
   nap -h
```