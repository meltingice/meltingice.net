---
---

$(document).ready ->
  $(".Clock").each ->
    new m.Clock $(@).find('canvas').get(0), $(@).data('service')