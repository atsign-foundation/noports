# Streaming Between Dart and C

Date: 04/04/2025

## Overview

The main purpose of being able to stream between C and Dart is so that we can
embed C srv into NoPorts Desktop and possibly npt/sshnp.

C srv already has a standalone ring buffer implementation, so it seems that
exposing the ring buffer as a control_io in C may be the simplest path forward.
With it exposed, we can wrap it in Dart ffi, and wrap that into a Dart stream.

Any further difficulties or considerations will be documented as they appear.
