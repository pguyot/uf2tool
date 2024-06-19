uf2tool
=====

Erlang escript to work with .uf2 files, initially developed to flash
Raspberry Pi Pico microcontrollers with [AtomVM](https://atomvm.net/) virtual
machine and Erlang applications.

Build
-----

    $ rebar3 escriptize

Run
---

    $ _build/default/bin/uf2tool

Usage
-----

# uf2tool help

Display some help message

# uf2tool join

```
uf2tool join -o combined.uf2 first.uf2 second.uf2...
```

Join two or more UF2 binaries. There is no check that UF2 files do not overlap.

# uf2tool create

```
uf2tool create -o new.uf2 -s start_addr image.avm
```

Create a new UF2 file from a given binary file, for example an `.avm` generated
by [packbeam](https://github.com/atomvm/atomvm_packbeam).

The start address can be written in decimal or hexadecimal prefixed with `0x`
or `16#`.
