---
description: >-
  Each device Atsign can be used for multiple devices and so each device needs a
  unique name.
icon: memo-circle-info
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# How to name a device

### Device Name Format

The device name has the following constraints.

* May contain only the following characters:&#x20;
  * `a-z` (lowercase letters)
  * `0-9` (numbers)
  * `_` (underscore)
  * `-` (dash)
* Maximum of 36 characters.
* Must start with a letter.

### Examples

```
my_host
canary02
oci_mail_0001
dc_001_row_009_rack_0067_ru_014
fa4969ca-9714-42a7-8edd-8d15158ce641
```

### Nerdy Stuff

#### The regular expression (regex)

```
[a-z][a-z0-9_-]{0,35}
```

#### Fun fact!

Originally we only supported alphanumeric snakecase up to 15 characters, but we loosened the constraints to support uuid v4.
