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
uf2tool create -o new.uf2 -f family_id -s start_addr image.avm
```

Create a new UF2 file from a given binary file, for example an `.avm` generated
by [packbeam](https://github.com/atomvm/atomvm_packbeam).

The start address can be written in decimal or hexadecimal prefixed with `0x`
or `16#`.

`family_id` is required for RP2350 (Pico2). By default, the family ID is rp2040.
Pico2 boot ROM doesn't understand this family ID but instead understands
`absolute`, `data`, `rp2350_arm_s`, `rp2350_riscv`, `rp2350_arm_ns`. Data is
suitable for Erlang code.

`family_id` can also be `universal` in which case the produced UF2 is the
catenation of the UF2 that would be produced with `rp2040` and the UF2 that
would be produced with `data`. Resulting UF2 can be loaded on both Pico and
Pico2.

API
---

In addition to `main/1`, `uf2tool` module exports the following functions:

- `uf2join/2`
- `uf2create/4`
- `binary_to_uf2/3`
