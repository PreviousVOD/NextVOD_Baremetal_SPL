# Secondary Bootloader (SPL) for baremetal NextVOD box

As the EMI SPI interface only accepts 32 bit accesses,
a secondary bootloader is required for code memory (for now).

This bootloader will:
* Initialize LMI(DDR2) memory
* Configure caches
* Find the text size from a descriptor(see below)
* Load and execute the application code from LMI.

## Application descriptor

| Offset | Content |
|-|-|
| 0x00 | end address of loadable sections |
| 0x04 | entry point |

## Project status
TODO

## Partition scheme
> Currently 32kB Flash is planned for SPL.