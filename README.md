uf2tool
=====

Erlang escript to work with .uf2 files, initially developed to flash
Raspberry Pi Pico microcontrollers with [AtomVM](https://atomvm.org/) virtual
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
uf2tool create -o new.uf2 -f family_id -s start_addr image.avm
```

Create a new UF2 file from a given binary file, for example an `.avm` generated
by [packbeam](https://github.com/atomvm/atomvm_packbeam).

The start address can be written in decimal or hexadecimal prefixed with `0x`
or `16#`.

## Family ID and "universal"

By default, uf2tool creates a binary for the RP2040, with family ID `rp2040`.
The RP2040 and the RP2350 boot loaders will happily ignore any chunk that have
a family ID they do not support. RP2040 only understands family id `rp2040`,
while RP2350 boot ROM understands `absolute`, `data`, `rp2350_arm_s`,
`rp2350_riscv`, `rp2350_arm_ns`. These family IDs have been designed to load
code for a particular architecture. `data` is suitable for Erlang code on
RP2350 as Erlang code works with AtomVM whether it was compiled for RISC V or
ARM.

`universal` is a special `family_id` that can be used to target both RP2040 and
RP2350. The produced UF2 is the concatenation of the UF2 that would
be produced with `rp2040` and the UF2 that would be produced with `data`.
Because each boot loader will happily ignore chunks with a family ID that they
do not support, using `universal` creates an UF2 twice the size on desktops,
but that does not use any extra flash space on the MCUs.

API
---

In addition to `main/1`, `uf2tool` module exports the following functions:

- `uf2join/2`
- `uf2create/4`
- `binary_to_uf2/3`
