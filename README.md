ICE EVM Board
=============

The ICE (In-Circuit Emulation) Evaluation Module is a debug board built for the
M3 ecosystem. In addition to acting as an M3 EVM, the ICE board can act as an
MBus debugger. ICE can act as a passive monitor, member node, or bus master as
desired.

ICE uses a [custom serial protocol][protocol] to communicate with a host PC.
There is a [Python library][py-ice] that provides a reasonably high-level API
to ICE and MBus.

This repository hosts the hardware and firmeware for ICE.

For more information, please visit http://mbus.io/ice.html

[protocol]: http://mbus.io/static/ICE-Protocol.pdf
[py-ice]: https://github.com/lab11/M-ulator/blob/master/platforms/m3/programming/ice.py

