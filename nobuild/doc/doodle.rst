==================
Doodle Development
==================

Introduction
============

Objectives
----------

Build Tool
----------

Directory Organisation
----------------------

Crucial Design Aspects
======================

Tool Stack
----------

Interaction, event handling, etc.

Undo Framework
--------------

Drawing Abstraction
-------------------

Detailed Component Descriptions
===============================

CUT !!!

Scope
=====

Overview
========

Definitions
-----------

Blocklet

  Variable length block of data produced by breaking blobs on boundaries
  such that identical blocklets are likely to occur in other blobs.
  Internal to blockpool.

Blob

  Arbitrary user data blocks stored/retrieved in blockpool.

Tag
  A small identifier that refers to a blob within a blockpool.

Hash
  A small identifier that refers to a blocklet within a blockpool.
  Internal to blockpool.

BFST-lib
  A shared-library (and associated header files) for invoking
  BFST functions from another program.

BFST-CLI
  The blocklets filestore executable.

BFST-API
  A set of functions provided by BFST-lib for directly
  accessing a blockpool or issuing commands to a BFST server.

Blockpool
  A blockpool on disk.

Purpose
--------

BFST is a store/retrieve technology that increases effective data capacity by
eliminating redundant data. BFST presents a simple external API:

- blob -> tag: Store a blob (arbitrary block of data) in the blockpool and
  receive a tag (small unique identifier) associated with the blob.

- tag -> blob: Retrieve a blob from the blockpool by providing the tag
  associated with the blob.

Also supported: replaction between blockpools.

Higher level services can be built on top of blockpool, for example, a
DXi presents a file-server that uses BFST as a deduplication backend.

Operational Modes
-----------------

Blockpool operations can be performed via:

API calls:
  Calling functions expored by libbfst.so.
  (Local and remote operations.)

CLI execution:
  Executing blockpool with chosen arguments.
  (Local, remote and server launching.)

The blockpool executable can be launched in the following modes:

Local
  Perform an operation on a local blockpool.
  (Note deployed in this manner)

Client / Remote

Server

A Blockpool server can be conversed with in two ways:

- CLI mode

- API mode

Implementation
--------------

Repository Layout
-----------------

Simplified layout::

  bfst
  |
  +--lib_rocksoft_c
  |
  +--libfilter         Stream filtering library, eg find tar boundary.
  |
  +--blockpool
  |  
  +--perl_mod          ADLQuantum perl modules.
  |
  +--test

Supported Platforms
-------------------

Building
--------

Linux
`````

Running
-------

Testing
-------

- self tests (./blockpool/cli/blockpool selftest default)

- perl test harness ./test/scripts/test.sh

Detailed Description
====================

Component: lib_rocksoft_c
-------------------------

Layout::

  lib_rocksoft_c
  |
  +--low
  |
  +--ADLQuantum
  |
  +--test           Self tests (unit tests)
  |
  +--external       3rd-party software
  
Component: libfilter
--------------------

Component: blockpool
--------------------

Layout::

  blockpool
  |
  +--memory_budgets
  |
  +--api
  |
  +--cli
  |
  +--lib
  |  |
  |  +--test        Self tests (unit tests)
  |  |
  |  +--ADLQuantum  More perl modules
  |
  +--scripts
  |
  +--sdk
  |
  +--docs



Important:

- In a DXi, blockpool runs as in server mode.

- BPW is a client (one of many) it maintains a preconfigured
  number of connections as a pool. These are used as required.

- shared memory segment runs from end-point (nfs/cifs/vtl/ost),
  thru BPW and to bfst server.

- pcache is a portion of the shared segment that is used to communicated
  between endpoints and BPW. BFST doesn't see pcache.

- BPW links the BFST shared library.

- When a new blob is stored in BFST, it is converted into blocklets,
  if the blocklet matches then its ref-count is incremented, otherwise
  a new blocklet is added. At the end of the conversion, the list of
  hashes is hashed to form the blob tag.
  If it turns out a blob with that tag already exists then the ref-count
  of that tag is incremented, but the blocklets' ref-counts are NOT
  decremented (to save cost). Somehow (I can't think how) everything
  works out ok when the blobs are unreferenced.

- Note, when replication is being used a blob's ref-count can be incremented
  without incrementing the ref-counts of the corresponding blocklets.
  How in the hell is this discrepancy reconciled without leaking blocklets
  or deleting blocklets in use.

Appendix
========

Misc
----

.. uml:: images/class-hierarchy

  package "BPW" #ffffff {
      class File
      class TagRef
  }

  package "BFST" #ffffff {
      class Blob {
          byte[64] tag
          int      ref-count
      }

      class HashRef

      class Blocklet {
          byte[64] hash
          int      ref-count
          Flags    flags
          byte[]   data
      }
  }

  File    "1"    *-  "1..*" TagRef
  TagRef  "1..*" *-- "1"    Blob

  Blob    "1"    *-  "1..*" HashRef
  HashRef "1..*" *-  "1"    Blocklet

  hide methods

- store: blob gets converted into blocklets, matched blocklets have
  ref-count incremented, new blocklets added. At the end we calculate
  the tag from the hash of hashes. Then if the tag matches an existing
  blob we increment the blob's ref-count AND the blob's blocklet-ref-count.

- replicate: we have the tag of the blob, if there is a match then increment
  the blob's ref-count but NOT the bloc's blocklet-ref-count.

Documentation Resources
-----------------------

- make USE_PLANTUML=true doc ; ${BROWSER} index.html

- ${BFST_ROOT}/blockpool/docs, ${BFST_ROOT}/libfilter/docs,
  ${BFST_ROOT}/blockpool/api/docs, ${BFST_ROOT}/blockpool/cli/docs

- Wiki links

  - Misc

    - http://wiki.adl.quantum.com/index.php/Tips_and_Tricks

  - Building on Linux:

    - http://wiki.adl.quantum.com/index.php/Compiling_Blockpool_On_Linux

    - http://wiki.adl.quantum.com/index.php/BuildInfrastructure

  - `Document repository
    <http://wiki.adl.quantum.com/index.php/Document_Repository>`_

  - `C Coding Standard <http://inside.adl.quantum.com/nlee/cstan/>`_
